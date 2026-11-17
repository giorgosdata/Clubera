'use strict';

// Awards coupon points for ΕΠΣ matches. The Cloud Function that resolves
// coupon_picks only reacts to the `matches` collection, so for ΕΠΣ matches
// (matchId "eps_...") this sync does the same job, with the same rules as
// functions/index.js:
//   exact score predicted and correct  -> 10 points
//   otherwise correct 1/X/2            ->  5 points
// Picks made at or after kick-off get 0 points.

const PREDICT_EXACT_PTS = 10;
const PREDICT_OUTCOME_PTS = 5;

function outcomeOf(h, a) {
  return h > a ? '1' : h < a ? '2' : 'X';
}

function toDate(v) {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof v.toDate === 'function') return v.toDate();
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

// pick: coupon_picks document data; match: { homeScore, awayScore, scheduledAt }
function pointsFor(pick, match) {
  const kickoff = toDate(match.scheduledAt);
  const created = toDate(pick.createdAt);
  if (kickoff && created && created >= kickoff) return { points: 0, late: true };
  const outcome = outcomeOf(match.homeScore, match.awayScore);
  const eh = pick.predictedHomeScore;
  const ea = pick.predictedAwayScore;
  if (eh != null && ea != null && eh === match.homeScore && ea === match.awayScore) {
    return { points: PREDICT_EXACT_PTS, late: false };
  }
  return { points: pick.pick === outcome ? PREDICT_OUTCOME_PTS : 0, late: false };
}

const RESOLVE_WINDOW_DAYS = 21;

// Finished matches worth checking: played in the last few weeks.
function matchesToResolve(competitions, now = new Date()) {
  const from = new Date(now.getTime() - RESOLVE_WINDOW_DAYS * 86400000);
  const out = [];
  for (const { doc } of competitions) {
    for (const m of doc.matches) {
      if (m.status !== 'finished' || m.homeScore == null || m.awayScore == null || !m.id) continue;
      const when = toDate(m.scheduledAt);
      if (when && when < from) continue;
      out.push(m);
    }
  }
  return out;
}

async function bumpFanStats(admin, db, userId, clubId, opts) {
  if (!userId || !clubId) return;
  const FieldValue = admin.firestore.FieldValue;
  const ref = db.collection('fan_stats').doc(`${userId}_${clubId}`);
  const update = { userId, clubId, updatedAt: FieldValue.serverTimestamp() };
  if (opts.score) update.clubScore = FieldValue.increment(opts.score);
  if (opts.predictionsCorrect) update.predictionsCorrect = FieldValue.increment(opts.predictionsCorrect);
  if (opts.predictionsExact) update.predictionsExact = FieldValue.increment(opts.predictionsExact);
  const snap = await ref.get();
  if (!snap.exists) {
    const [userSnap, clubSnap] = await Promise.all([
      db.collection('users').doc(userId).get(),
      db.collection('clubs').doc(clubId).get(),
    ]);
    if (!userSnap.exists || !clubSnap.exists) return;
    const u = userSnap.data() || {};
    const c = clubSnap.data() || {};
    update.userName = u.name || '';
    update.userPhotoUrl = u.photoUrl || '';
    update.clubName = c.name || '';
    const isFollower = Array.isArray(u.followedClubs) && u.followedClubs.includes(clubId);
    update.isFollower = isFollower;
    if (isFollower) update.followedAt = FieldValue.serverTimestamp();
  }
  await ref.set(update, { merge: true });
}

async function notify(admin, db, userId, title, body, data) {
  try {
    await db.collection('notifications').add({
      userId,
      title,
      body,
      emoji: '🎯',
      data,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const token = (await db.collection('users').doc(userId).get()).get('fcmToken');
    if (token) {
      await admin.messaging().send({
        token,
        notification: { title, body },
        data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      });
    }
  } catch (e) {
    console.error(`notify(${userId}) failed: ${e.message}`);
  }
}

// Returns { picks, points } resolved in this run.
async function resolveCouponPicks(admin, db, matches) {
  const byId = new Map(matches.map((m) => [m.id, m]));
  const ids = [...byId.keys()];
  let resolved = 0;
  let awardedPoints = 0;
  for (let i = 0; i < ids.length; i += 30) {
    const chunk = ids.slice(i, i + 30);
    const snap = await db.collection('coupon_picks').where('matchId', 'in', chunk).get();
    for (const doc of snap.docs) {
      const pick = doc.data();
      if (pick.resolved === true) continue;
      const m = byId.get(pick.matchId);
      const { points, late } = pointsFor(pick, m);
      let awarded = false;
      let didResolve = false;
      await db.runTransaction(async (tx) => {
        awarded = false;
        didResolve = false;
        const fresh = await tx.get(doc.ref);
        if (fresh.get('resolved') === true) return;
        tx.update(doc.ref, {
          resolved: true,
          pointsEarned: points,
          ...(late ? { late: true } : {}),
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        if (points > 0 && pick.userId) {
          tx.update(db.collection('users').doc(pick.userId), {
            points: admin.firestore.FieldValue.increment(points),
            seasonScore: admin.firestore.FieldValue.increment(points),
          });
        }
        awarded = points > 0 && !!pick.userId;
        didResolve = true;
      });
      if (didResolve) resolved++;
      if (awarded) {
        awardedPoints += points;
        const exact = points === PREDICT_EXACT_PTS;
        const bump = { score: points, predictionsCorrect: 1, predictionsExact: exact ? 1 : 0 };
        await Promise.all([
          notify(admin, db, pick.userId, '🎯 Κέρδισες πόντους!',
            `+${points} πόντοι από το κουπόνι: ${m.homeTeam} ${m.homeScore}-${m.awayScore} ${m.awayTeam}`,
            { matchId: m.id }),
          bumpFanStats(admin, db, pick.userId, m.homeClubId, bump),
          bumpFanStats(admin, db, pick.userId, m.awayClubId, bump),
        ]);
      }
    }
  }
  return { picks: resolved, points: awardedPoints };
}

module.exports = {
  pointsFor,
  outcomeOf,
  matchesToResolve,
  resolveCouponPicks,
  PREDICT_EXACT_PTS,
  PREDICT_OUTCOME_PTS,
};
