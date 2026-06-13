// Clubera Cloud Functions — push notifications via FCM.
// Triggered by Firestore document writes; sends notifications to users.

const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

// Heavier runtime config for functions that may fan-out to many docs.
const HEAVY = { memory: "512MiB", timeoutSeconds: 300 };

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// Write an in-app notification doc for a user.
async function writeNotification(userId, title, body, emoji, data) {
  try {
    await db.collection("notifications").add({
      userId,
      title,
      body,
      emoji,
      data: data || {},
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.error("writeNotification failed:", e);
  }
}

// Helper: send to a topic (anyone subscribed). Also writes in-app docs to
// followers of a club, if topic looks like "club_XXX".
async function sendTopic(topic, title, body, data = {}, emoji = "🔔") {
  try {
    await messaging.send({
      topic,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
  } catch (e) {
    console.error(`sendTopic(${topic}) failed:`, e);
  }
  // Fan-out in-app notifications for club followers (chunked for batch limit)
  if (topic.startsWith("club_")) {
    const clubId = topic.substring("club_".length);
    try {
      const followers = await db
        .collection("users")
        .where("followedClubs", "array-contains", clubId)
        .get();
      await chunkedNotificationFanOut(followers.docs.map((d) => d.id), title, body, emoji, data);
    } catch (e) {
      console.error("fan-out followers failed:", e);
    }
  }
}

// Firestore batch limit is 500 ops; we keep a safety margin.
const BATCH_CHUNK = 450;

async function chunkedNotificationFanOut(userIds, title, body, emoji, data) {
  for (let i = 0; i < userIds.length; i += BATCH_CHUNK) {
    const slice = userIds.slice(i, i + BATCH_CHUNK);
    const batch = db.batch();
    for (const uid of slice) {
      const ref = db.collection("notifications").doc();
      batch.set(ref, {
        userId: uid,
        title,
        body,
        emoji,
        data: data || {},
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

// Helper: send to a single user (via stored fcmToken). Also writes in-app doc.
async function sendUser(uid, title, body, data = {}, emoji = "🔔") {
  await writeNotification(uid, title, body, emoji, data);
  try {
    const snap = await db.collection("users").doc(uid).get();
    const token = snap.data()?.fcmToken;
    if (!token) return;
    await messaging.send({
      token,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
  } catch (e) {
    console.error(`sendUser(${uid}) failed:`, e);
  }
}

// ─── FAN STATS ───────────────────────────────────────────────────────────────
// Per-(user, club) engagement record. Document id = `${userId}_${clubId}`.
const FAN_PTS_VOTE = 5;
const FAN_PTS_FOLLOW = 2;
const FAN_PTS_DONATION_PER_EURO = 1;

// Atomic, race-safe bump using set({merge:true}) + FieldValue.increment.
// Safe to invoke in parallel for the same (userId, clubId) — Firestore serializes.
async function bumpFanStats(userId, clubId, opts = {}) {
  if (!userId || !clubId) return;
  const id = `${userId}_${clubId}`;
  const ref = db.collection("fan_stats").doc(id);

  const update = {
    userId,
    clubId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (opts.score) update.clubScore = admin.firestore.FieldValue.increment(opts.score);
  if (opts.predictionsCorrect) update.predictionsCorrect = admin.firestore.FieldValue.increment(opts.predictionsCorrect);
  if (opts.predictionsExact) update.predictionsExact = admin.firestore.FieldValue.increment(opts.predictionsExact);
  if (opts.donations) update.donations = admin.firestore.FieldValue.increment(opts.donations);
  if (opts.votes) update.votes = admin.firestore.FieldValue.increment(opts.votes);
  if (opts.isFollower !== undefined) update.isFollower = opts.isFollower;

  // On first write we need to seed denormalized user/club metadata.
  const snap = await ref.get();
  if (!snap.exists) {
    const [userSnap, clubSnap] = await Promise.all([
      db.collection("users").doc(userId).get(),
      db.collection("clubs").doc(clubId).get(),
    ]);
    if (!userSnap.exists || !clubSnap.exists) return;
    const u = userSnap.data() || {};
    const c = clubSnap.data() || {};
    update.userName = u.name || "";
    update.userPhotoUrl = u.photoUrl || "";
    update.clubName = c.name || "";
    const isFollower =
      opts.isFollower !== undefined
        ? opts.isFollower
        : Array.isArray(u.followedClubs) && u.followedClubs.includes(clubId);
    update.isFollower = isFollower;
    if (isFollower) update.followedAt = admin.firestore.FieldValue.serverTimestamp();
  } else if (opts.isFollower && !snap.data().followedAt) {
    update.followedAt = admin.firestore.FieldValue.serverTimestamp();
  }

  await ref.set(update, { merge: true });
}

// Club rename → propagate clubName across denormalized fan_stats docs.
exports.onClubUpdated = onDocumentUpdated({ document: "clubs/{clubId}", ...HEAVY }, async (event) => {
  const before = event.data?.before.data() || {};
  const after = event.data?.after.data() || {};
  if ((before.name || "") === (after.name || "")) return;
  try {
    const fansSnap = await db
      .collection("fan_stats")
      .where("clubId", "==", event.params.clubId)
      .get();
    for (let i = 0; i < fansSnap.docs.length; i += BATCH_CHUNK) {
      const batch = db.batch();
      fansSnap.docs
        .slice(i, i + BATCH_CHUNK)
        .forEach((d) => batch.update(d.ref, { clubName: after.name || "" }));
      await batch.commit();
    }
  } catch (e) {
    console.error("club rename propagation failed:", e);
  }
});

// Donation → bump fan_stats for that club.
exports.onDonationCreated = onDocumentCreated("donations/{donationId}", async (event) => {
  const d = event.data?.data();
  if (!d || !d.userId || !d.clubId) return;
  const amount = (d.amount || 0);
  await bumpFanStats(d.userId, d.clubId, {
    donations: amount,
    score: Math.round(amount * FAN_PTS_DONATION_PER_EURO),
  });
});

// Vote → bump fan_stats for that club.
exports.onVoteCreated = onDocumentCreated("clubs/{clubId}/votes/{voterId}", async (event) => {
  const { clubId, voterId } = event.params;
  await bumpFanStats(voterId, clubId, { votes: 1, score: FAN_PTS_VOTE });
});

// Follow toggle → mark isFollower + bonus on first follow.
// Profile updates → propagate userName/userPhotoUrl across the user's fan_stats.
exports.onUserUpdated = onDocumentUpdated({ document: "users/{userId}", ...HEAVY }, async (event) => {
  const before = event.data?.before.data() || {};
  const after = event.data?.after.data() || {};
  const userId = event.params.userId;

  // Follow / unfollow diff
  const beforeList = Array.isArray(before.followedClubs) ? before.followedClubs : [];
  const afterList = Array.isArray(after.followedClubs) ? after.followedClubs : [];
  const added = afterList.filter((c) => !beforeList.includes(c));
  const removed = beforeList.filter((c) => !afterList.includes(c));
  await Promise.all([
    ...added.map((clubId) =>
      bumpFanStats(userId, clubId, { isFollower: true, score: FAN_PTS_FOLLOW })
    ),
    ...removed.map((clubId) =>
      bumpFanStats(userId, clubId, { isFollower: false })
    ),
  ]);

  // Profile name / photo propagation across denormalized fan_stats docs.
  const nameChanged = (before.name || "") !== (after.name || "");
  const photoChanged = (before.photoUrl || "") !== (after.photoUrl || "");
  if (nameChanged || photoChanged) {
    try {
      const fansSnap = await db
        .collection("fan_stats")
        .where("userId", "==", userId)
        .get();
      const update = {};
      if (nameChanged) update.userName = after.name || "";
      if (photoChanged) update.userPhotoUrl = after.photoUrl || "";
      for (let i = 0; i < fansSnap.docs.length; i += BATCH_CHUNK) {
        const batch = db.batch();
        fansSnap.docs.slice(i, i + BATCH_CHUNK).forEach((d) => batch.update(d.ref, update));
        await batch.commit();
      }
    } catch (e) {
      console.error("user profile propagation failed:", e);
    }
  }
});

// ─── NEW MATCH ───────────────────────────────────────────────────────────────
exports.onMatchCreated = onDocumentCreated("matches/{matchId}", async (event) => {
  const m = event.data?.data();
  if (!m) return;
  const title = "⚽ Νέο Ματς";
  const body = `${m.homeClubName || "Ομάδα"} vs ${m.awayClubName || "Ομάδα"}`;
  // Notify followers of either club
  if (m.homeClubId) await sendTopic(`club_${m.homeClubId}`, title, body, { matchId: event.params.matchId });
  if (m.awayClubId) await sendTopic(`club_${m.awayClubId}`, title, body, { matchId: event.params.matchId });
});

// Predict scoring (must match prediction_model.dart)
const PREDICT_EXACT_PTS = 10;
const PREDICT_OUTCOME_PTS = 5;

function pickFromScore(h, a) {
  return h > a ? "1" : h < a ? "2" : "X";
}

// Resolve all coupon_picks + score_predictions for a finished match.
// Awards points, marks docs as resolved, sends per-user notifications.
async function resolvePredictionsForMatch(matchId, homeScore, awayScore, homeName, awayName, homeClubId, awayClubId) {
  const outcome = pickFromScore(homeScore, awayScore);

  async function handleCoupon(doc) {
    const d = doc.data();
    if (d.resolved === true) return;
    const exactH = d.predictedHomeScore;
    const exactA = d.predictedAwayScore;
    let pts = 0;
    if (exactH != null && exactA != null) {
      if (exactH === homeScore && exactA === awayScore) {
        pts = PREDICT_EXACT_PTS;
      } else if (d.pick === outcome) {
        pts = PREDICT_OUTCOME_PTS;
      }
    } else if (d.pick === outcome) {
      pts = PREDICT_OUTCOME_PTS;
    }
    try {
      // Atomic transaction: mark resolved AND award points together.
      // Prevents both double-award (concurrent invocations) and point-loss
      // (crash after resolved:true but before points increment).
      let awarded = false;
      await db.runTransaction(async (tx) => {
        const fresh = await tx.get(doc.ref);
        if (fresh.data()?.resolved === true) return;
        tx.update(doc.ref, {
          resolved: true,
          pointsEarned: pts,
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        if (pts > 0 && d.userId) {
          tx.update(db.collection("users").doc(d.userId), {
            points: admin.firestore.FieldValue.increment(pts),
          });
        }
        awarded = pts > 0 && !!d.userId;
      });
      // Non-critical side effects (notification + fan stats) outside transaction.
      if (awarded) {
        const exact = pts === PREDICT_EXACT_PTS;
        const bump = { score: pts, predictionsCorrect: 1, predictionsExact: exact ? 1 : 0 };
        await Promise.all([
          sendUser(
            d.userId,
            "🎯 Κέρδισες πόντους!",
            `+${pts} πόντοι από το coupon: ${homeName} ${homeScore}-${awayScore} ${awayName}`,
            { matchId },
            "🎯"
          ),
          homeClubId ? bumpFanStats(d.userId, homeClubId, bump) : null,
          awayClubId ? bumpFanStats(d.userId, awayClubId, bump) : null,
        ].filter(Boolean));
      }
    } catch (e) {
      console.error("resolve coupon failed:", e);
    }
  }

  async function handleScorePrediction(doc) {
    const d = doc.data();
    if (d.pointsEarned != null) return;
    const pH = d.homeScore ?? 0;
    const pA = d.awayScore ?? 0;
    let pts = 0;
    if (pH === homeScore && pA === awayScore) {
      pts = PREDICT_EXACT_PTS;
    } else if (pickFromScore(pH, pA) === outcome) {
      pts = PREDICT_OUTCOME_PTS;
    }
    try {
      // Atomic transaction: mark pointsEarned AND award points together.
      // Prevents both double-award (concurrent invocations) and point-loss
      // (crash after pointsEarned write but before points increment).
      let awarded = false;
      await db.runTransaction(async (tx) => {
        const fresh = await tx.get(doc.ref);
        if (fresh.data()?.pointsEarned != null) return;
        tx.update(doc.ref, {
          pointsEarned: pts,
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        if (pts > 0 && d.userId) {
          tx.update(db.collection("users").doc(d.userId), {
            points: admin.firestore.FieldValue.increment(pts),
          });
        }
        awarded = pts > 0 && !!d.userId;
      });
      // Non-critical side effects outside transaction.
      if (awarded) {
        const exact = pts === PREDICT_EXACT_PTS;
        const bump = { score: pts, predictionsCorrect: 1, predictionsExact: exact ? 1 : 0 };
        await Promise.all([
          sendUser(
            d.userId,
            "🎯 Κέρδισες πόντους!",
            `+${pts} πόντοι από πρόβλεψη: ${homeName} ${homeScore}-${awayScore} ${awayName}`,
            { matchId },
            "🎯"
          ),
          homeClubId ? bumpFanStats(d.userId, homeClubId, bump) : null,
          awayClubId ? bumpFanStats(d.userId, awayClubId, bump) : null,
        ].filter(Boolean));
      }
    } catch (e) {
      console.error("resolve score prediction failed:", e);
    }
  }

  const [couponSnap, scoreSnap] = await Promise.all([
    db.collection("coupon_picks").where("matchId", "==", matchId).get(),
    db.collection("score_predictions").where("matchId", "==", matchId).get(),
  ]);
  // Process in chunks of 25 to avoid overwhelming Firestore connection pool.
  await runInChunks(couponSnap.docs, 25, handleCoupon);
  await runInChunks(scoreSnap.docs, 25, handleScorePrediction);
}

async function runInChunks(items, size, fn) {
  for (let i = 0; i < items.length; i += size) {
    await Promise.all(items.slice(i, i + size).map(fn));
  }
}

// ─── MATCH SCORE / STATUS UPDATE ─────────────────────────────────────────────
exports.onMatchUpdated = onDocumentUpdated({ document: "matches/{matchId}", ...HEAVY }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  const matchId = event.params.matchId;
  const scoreChanged =
    before.homeScore !== after.homeScore || before.awayScore !== after.awayScore;
  const statusChanged = before.status !== after.status;

  if (scoreChanged && (after.status === "live" || after.status === "halftime")) {
    const title = "⚽ GOAL!";
    const body = `${after.homeClubName} ${after.homeScore} - ${after.awayScore} ${after.awayClubName}`;
    if (after.homeClubId) await sendTopic(`club_${after.homeClubId}`, title, body, { matchId });
    if (after.awayClubId) await sendTopic(`club_${after.awayClubId}`, title, body, { matchId });
  } else if (statusChanged && after.status === "finished") {
    const title = "🏁 Τελικό";
    const body = `${after.homeClubName} ${after.homeScore} - ${after.awayScore} ${after.awayClubName}`;
    if (after.homeClubId) await sendTopic(`club_${after.homeClubId}`, title, body, { matchId });
    if (after.awayClubId) await sendTopic(`club_${after.awayClubId}`, title, body, { matchId });
    // Skip resolution if scores were not recorded (data integrity guard)
    if (after.homeScore == null || after.awayScore == null) return;
    // Resolve predictions and award points
    await resolvePredictionsForMatch(
      matchId,
      after.homeScore || 0,
      after.awayScore || 0,
      after.homeClubName || "",
      after.awayClubName || "",
      after.homeClubId || "",
      after.awayClubId || ""
    );
  } else if (statusChanged && after.status === "live") {
    const title = "🔴 LIVE";
    const body = `Ξεκίνησε ο αγώνας ${after.homeClubName} vs ${after.awayClubName}`;
    if (after.homeClubId) await sendTopic(`club_${after.homeClubId}`, title, body, { matchId });
    if (after.awayClubId) await sendTopic(`club_${after.awayClubId}`, title, body, { matchId });
  }
});

// ─── NEW GAME (mini game) ────────────────────────────────────────────────────
exports.onGameCreated = onDocumentCreated("games/{gameId}", async (event) => {
  const g = event.data?.data();
  if (!g || g.isActive === false) return;
  await sendTopic(
    "global",
    "🎮 Νέο Παιχνίδι",
    `${g.title} — κέρδισε έως ${g.maxPoints} πόντους!`,
    { gameId: event.params.gameId }
  );
});

// ─── NEW REWARD ──────────────────────────────────────────────────────────────
exports.onRewardCreated = onDocumentCreated("rewards/{rewardId}", async (event) => {
  const r = event.data?.data();
  if (!r) return;
  const target = r.clubId ? `club_${r.clubId}` : "global";
  await sendTopic(
    target,
    "🎁 Νέα Ανταμοιβή",
    `${r.title} — ${r.pointsCost} πόντοι`,
    { rewardId: event.params.rewardId }
  );
});

// ─── NEW NEWS ARTICLE ────────────────────────────────────────────────────────
exports.onNewsCreated = onDocumentCreated("news/{newsId}", async (event) => {
  const n = event.data?.data();
  if (!n) return;
  await sendTopic(
    "global",
    `📰 ${n.title || "Νέο άρθρο"}`,
    n.excerpt || n.summary || "Διάβασε τις τελευταίες ειδήσεις",
    { newsId: event.params.newsId }
  );
});

// ─── NEW PLAYER IN CLUB ──────────────────────────────────────────────────────
exports.onPlayerCreated = onDocumentCreated("clubs/{clubId}/players/{playerId}", async (event) => {
  const p = event.data?.data();
  if (!p) return;
  const clubSnap = await db.collection("clubs").doc(event.params.clubId).get();
  const clubName = clubSnap.data()?.name || "Η ομάδα";
  await sendTopic(
    `club_${event.params.clubId}`,
    "👕 Νέος Παίκτης",
    `${clubName}: ${p.name} (${p.position || "—"})`,
    { clubId: event.params.clubId }
  );
});

// ─── NEW TRANSFER ────────────────────────────────────────────────────────────
exports.onTransferCreated = onDocumentCreated("clubs/{clubId}/transfers/{transferId}", async (event) => {
  const t = event.data?.data();
  if (!t) return;
  const clubSnap = await db.collection("clubs").doc(event.params.clubId).get();
  const clubName = clubSnap.data()?.name || "Η ομάδα";
  const verb = t.type === "in" ? "Νέα Μεταγραφή ➜" : "Αποχώρηση ➜";
  await sendTopic(
    `club_${event.params.clubId}`,
    `🔄 ${verb}`,
    `${clubName}: ${t.playerName}`,
    { clubId: event.params.clubId }
  );
});

// ─── CLUB REQUEST APPROVED ───────────────────────────────────────────────────
exports.onClubRequestUpdated = onDocumentUpdated("club_requests/{reqId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (before.status !== after.status && after.status === "approved" && after.userId) {
    await sendUser(
      after.userId,
      "✅ Η αίτηση εγκρίθηκε!",
      `Η ομάδα "${after.clubName}" δημιουργήθηκε. Καλώς ήρθες!`,
      { clubId: after.clubId || "" }
    );
  }
  if (before.status !== after.status && after.status === "rejected" && after.userId) {
    await sendUser(
      after.userId,
      "❌ Η αίτηση απορρίφθηκε",
      "Δες την εφαρμογή για περισσότερες πληροφορίες.",
      {}
    );
  }
});

// ─── GAME PLAY (notify user of points won) ───────────────────────────────────
exports.onGamePlay = onDocumentCreated("game_plays/{playId}", async (event) => {
  const p = event.data?.data();
  if (!p || !p.userId) return;
  await sendUser(
    p.userId,
    "🎉 Κέρδισες πόντους!",
    `+${p.pointsWon} πόντοι από ${p.gameTitle}`,
    { gameId: p.gameId || "" }
  );
});

// ─── MONTHLY TOP FANS BONUS ─────────────────────────────────────────────────
// 1st of each month at 09:00 Athens: top 3 fans per club get bonus points
// (+50, +30, +20) and a notification.
exports.monthlyTopFansBonus = onSchedule(
  { schedule: "0 9 1 * *", timeZone: "Europe/Athens", ...HEAVY },
  async () => {
    const bonuses = [50, 30, 20];
    // Idempotency key: YYYY-MM — prevents double-award on retry/re-run
    const now = new Date();
    const monthKey = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
    const clubsSnap = await db.collection("clubs").get();

    async function processClub(clubDoc) {
      const clubId = clubDoc.id;
      const clubName = clubDoc.data().name || "";
      const fansSnap = await db
        .collection("fan_stats")
        .where("clubId", "==", clubId)
        .orderBy("clubScore", "desc")
        .limit(3)
        .get();
      await Promise.all(fansSnap.docs.map(async (fanDoc, i) => {
        const fan = fanDoc.data();
        const bonus = bonuses[i];
        if (!fan.userId || !bonus) return;
        const rank = i + 1; // 1-based
        // Skip if already awarded this month
        if (fan.bonusAwardedMonth === monthKey) return;
        try {
          const badgeCode = rank === 1 ? "topFan1" : "topFan3";
          await Promise.all([
            fanDoc.ref.update({
              clubScore: admin.firestore.FieldValue.increment(bonus),
              bonusAwardedMonth: monthKey,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }),
            db.collection("users").doc(fan.userId).update({
              points: admin.firestore.FieldValue.increment(bonus),
            }),
            sendUser(
              fan.userId,
              "🏆 Top Fan Bonus!",
              `Είσαι #${rank} fan του ${clubName} αυτόν τον μήνα! +${bonus} πόντοι`,
              { clubId },
              "🏆"
            ),
            awardBadge(fan.userId, badgeCode, clubId, clubName),
          ]);
        } catch (e) {
          console.error(`monthly bonus failed for ${fan.userId}:`, e);
        }
      }));
    }

    await runInChunks(clubsSnap.docs, 10, processClub);
  }
);

// ─── MATCH REMINDERS (every 5 min) ──────────────────────────────────────────
// Finds matches starting in the next 55-65 min, sends reminder to club followers.
exports.matchReminder = onSchedule(
  { schedule: "*/5 * * * *", timeZone: "Europe/Athens" },
  async () => {
    const now = Date.now();
    const windowStart = admin.firestore.Timestamp.fromMillis(now + 55 * 60 * 1000);
    const windowEnd   = admin.firestore.Timestamp.fromMillis(now + 65 * 60 * 1000);

    const snap = await db.collection("matches")
      .where("status", "==", "upcoming")
      .where("scheduledAt", ">=", windowStart)
      .where("scheduledAt", "<=", windowEnd)
      .get();

    for (const doc of snap.docs) {
      const m = doc.data();
      if (m.reminderSent === true) continue;
      try {
        await doc.ref.update({ reminderSent: true });
        const title = "⏰ Σε 1 ώρα ξεκινά ο αγώνας!";
        const body  = `${m.homeClubName || "?"} vs ${m.awayClubName || "?"}`;
        if (m.homeClubId) await sendTopic(`club_${m.homeClubId}`, title, body, { matchId: doc.id }, "⏰");
        if (m.awayClubId) await sendTopic(`club_${m.awayClubId}`, title, body, { matchId: doc.id }, "⏰");
      } catch (e) {
        console.error("matchReminder failed for", doc.id, e);
      }
    }
  }
);

// ─── BADGES ──────────────────────────────────────────────────────────────────
// user_badges/{userId}_{badgeCode}  (global badges)
// user_badges/{userId}_{badgeCode}_{clubId}  (club-specific badges)

const BADGE_META = {
  firstPrediction: { emoji: "🎯", name: "Πρώτη Πρόβλεψη" },
  exactScore:      { emoji: "💎", name: "Exact Score" },
  predictions10:   { emoji: "🔮", name: "10 Σωστές" },
  predictions50:   { emoji: "🧠", name: "Αναλυτής" },
  firstDonation:   { emoji: "❤️", name: "Υποστηρικτής" },
  donor50:         { emoji: "💪", name: "Μεγάλος Χορηγός" },
  firstMvpVote:    { emoji: "⭐", name: "Κριτής MVP" },
  topFan3:         { emoji: "🏅", name: "Top 3 Fan" },
  topFan1:         { emoji: "🏆", name: "#1 Fan" },
  silverTier:      { emoji: "🥈", name: "Silver Fan" },
  goldTier:        { emoji: "🥇", name: "Gold Fan" },
  platinumTier:    { emoji: "💎", name: "Platinum Fan" },
};

// Atomically awards a badge if not already awarded. Returns true if newly awarded.
async function awardBadge(userId, badgeCode, clubId = null, clubName = null) {
  const meta = BADGE_META[badgeCode];
  if (!meta) return false;
  const suffix = clubId ? `${badgeCode}_${clubId}` : badgeCode;
  const docId  = `${userId}_${suffix}`;
  const ref = db.collection("user_badges").doc(docId);
  const snap = await ref.get();
  if (snap.exists) return false;
  try {
    await Promise.all([
      ref.set({
        userId,
        badgeCode,
        clubId: clubId || null,
        clubName: clubName || null,
        awardedAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
      sendUser(
        userId,
        `${meta.emoji} Νέο Badge: ${meta.name}!`,
        clubName
          ? `Κέρδισες το badge στην ομάδα ${clubName}`
          : "Κέρδισες ένα νέο badge!",
        { badgeCode },
        meta.emoji
      ),
    ]);
    return true;
  } catch (e) {
    console.error(`awardBadge(${userId}, ${badgeCode}) failed:`, e);
    return false;
  }
}

// Trigger: first score prediction → firstPrediction badge
exports.onScorePredictionCreated = onDocumentCreated(
  "score_predictions/{predId}",
  async (event) => {
    const p = event.data?.data();
    if (!p?.userId) return;
    await awardBadge(p.userId, "firstPrediction");
  }
);

// Trigger: first MVP vote → firstMvpVote badge
exports.onMvpVoteCreated = onDocumentCreated(
  "matches/{matchId}/mvp_votes/{voterId}",
  async (event) => {
    const voterId = event.params.voterId;
    if (!voterId) return;
    await awardBadge(voterId, "firstMvpVote");
  }
);

// Trigger: first donation → firstDonation badge
exports.onDonationBadge = onDocumentCreated(
  "donations/{donId}",
  async (event) => {
    const d = event.data?.data();
    if (!d?.userId) return;
    await awardBadge(d.userId, "firstDonation");
  }
);

// Trigger: fan_stats written → tier badges, prediction count badges, donor50
exports.onFanStatsWritten = onDocumentWritten(
  "fan_stats/{statId}",
  async (event) => {
    const after = event.data?.after?.data();
    if (!after?.userId) return;
    const { userId, clubId, clubName, clubScore, predictionsCorrect, predictionsExact, donations } = after;

    const checks = [];

    // Tier badges (club-specific, keyed by clubId)
    if (clubScore >= 500) checks.push(awardBadge(userId, "platinumTier", clubId, clubName));
    else if (clubScore >= 200) checks.push(awardBadge(userId, "goldTier", clubId, clubName));
    else if (clubScore >= 50)  checks.push(awardBadge(userId, "silverTier", clubId, clubName));

    // Prediction count badges (global across all clubs)
    if (predictionsCorrect >= 50) checks.push(awardBadge(userId, "predictions50"));
    else if (predictionsCorrect >= 10) checks.push(awardBadge(userId, "predictions10"));

    // Exact score badge (global)
    if (predictionsExact >= 1) checks.push(awardBadge(userId, "exactScore"));

    // Donation badge (global)
    if (donations >= 50) checks.push(awardBadge(userId, "donor50"));

    await Promise.all(checks);
  }
);

// ─── PLAYER CAREER STATS ──────────────────────────────────────────────────────
// When a match transitions to 'finished', aggregate events into player stat counters.
exports.onMatchFinished = onDocumentUpdated(
  { document: "matches/{matchId}", ...HEAVY },
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();
    if (before.status === "finished" || after.status !== "finished") return;

    const matchId = event.params.matchId;
    const matchRef = db.collection("matches").doc(matchId);

    // Idempotency guard: check BEFORE starting work, set AFTER completing it.
    // Setting early (before the loop) would permanently drop stats if the
    // function crashes mid-loop with no retry possible.
    const guardSnap = await matchRef.get();
    if (!guardSnap.exists || guardSnap.data()?.statsProcessed) return;

    // Fetch all events for this match
    const eventsSnap = await db
      .collection("matches").doc(matchId).collection("events").get();

    // Accumulate event-based stats by clubId+playerName
    const statsMap = {};
    for (const doc of eventsSnap.docs) {
      const e = doc.data();
      if (!e.clubId || !e.playerName) continue;
      const key = `${e.clubId}::${e.playerName}`;
      if (!statsMap[key]) {
        statsMap[key] = { clubId: e.clubId, playerName: e.playerName, goals: 0, yellowCards: 0, redCards: 0 };
      }
      if (e.type === "goal")         statsMap[key].goals++;
      if (e.type === "yellow_card")  statsMap[key].yellowCards++;
      if (e.type === "red_card")     statsMap[key].redCards++;
    }

    // Collect appearance entries from both lineups
    const appearanceKeys = new Set();
    const appearances = [];
    function addAppearance(clubId, playerName) {
      if (!clubId || !playerName) return;
      const key = `${clubId}::${playerName}`;
      if (!appearanceKeys.has(key)) {
        appearanceKeys.add(key);
        appearances.push({ clubId, playerName });
      }
    }
    for (const p of (after.homeLineup || [])) addAppearance(after.homeClubId, p.name);
    for (const p of (after.awayLineup || [])) addAppearance(after.awayClubId, p.name);

    // Helper: find player doc by name within a club and apply increments
    const inc = admin.firestore.FieldValue.increment;
    async function updatePlayerStats(clubId, playerName, delta) {
      const snap = await db
        .collection("clubs").doc(clubId)
        .collection("players")
        .where("name", "==", playerName)
        .limit(1)
        .get();
      if (snap.empty) return;
      const updates = {};
      if (delta.goals)        updates.goals = inc(delta.goals);
      if (delta.yellowCards)  updates.yellowCards = inc(delta.yellowCards);
      if (delta.redCards)     updates.redCards = inc(delta.redCards);
      if (delta.appearances)  updates.appearances = inc(1);
      if (Object.keys(updates).length === 0) return;
      await snap.docs[0].ref.update(updates);
    }

    // Merge event stats + appearances into a single update per player
    for (const a of appearances) {
      const key = `${a.clubId}::${a.playerName}`;
      if (!statsMap[key]) statsMap[key] = { clubId: a.clubId, playerName: a.playerName, goals: 0, yellowCards: 0, redCards: 0 };
      statsMap[key].appearances = true;
    }

    const entries = Object.values(statsMap);
    await runInChunks(entries, 10, async (s) => {
      try {
        await updatePlayerStats(s.clubId, s.playerName, s);
      } catch (e) {
        console.error(`onMatchFinished: updatePlayerStats failed for ${s.playerName}:`, e);
      }
    });

    // Mark stats done AFTER all writes succeed so a crash mid-loop
    // allows a clean retry rather than silently dropping remaining players.
    await matchRef.update({ statsProcessed: true });

    // ── Auto-update club standings ────────────────────────────────────────────
    const homeScore = after.homeScore ?? 0;
    const awayScore = after.awayScore ?? 0;
    const homeId = after.homeClubId;
    const awayId = after.awayClubId;
    if (!homeId || !awayId) return;

    const incF = admin.firestore.FieldValue.increment;
    let homeUpdate, awayUpdate;
    if (homeScore > awayScore) {
      homeUpdate = { wins: incF(1), played: incF(1), goalsFor: incF(homeScore), goalsAgainst: incF(awayScore) };
      awayUpdate  = { losses: incF(1), played: incF(1), goalsFor: incF(awayScore), goalsAgainst: incF(homeScore) };
    } else if (homeScore < awayScore) {
      homeUpdate = { losses: incF(1), played: incF(1), goalsFor: incF(homeScore), goalsAgainst: incF(awayScore) };
      awayUpdate  = { wins: incF(1), played: incF(1), goalsFor: incF(awayScore), goalsAgainst: incF(homeScore) };
    } else {
      homeUpdate = { draws: incF(1), played: incF(1), goalsFor: incF(homeScore), goalsAgainst: incF(awayScore) };
      awayUpdate  = { draws: incF(1), played: incF(1), goalsFor: incF(awayScore), goalsAgainst: incF(homeScore) };
    }
    // Use a transaction to guarantee idempotency: if retried or the match is
    // re-finished, we do not double-count.
    await db.runTransaction(async (tx) => {
      const matchSnap = await tx.get(matchRef);
      if (!matchSnap.exists) return; // match was deleted after trigger fired
      if (matchSnap.data()?.standingsProcessed) return;
      tx.update(matchRef, { standingsProcessed: true });
      tx.update(db.collection("clubs").doc(homeId), homeUpdate);
      tx.update(db.collection("clubs").doc(awayId), awayUpdate);
    });
  }
);
