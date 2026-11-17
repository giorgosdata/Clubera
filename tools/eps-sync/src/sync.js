'use strict';

// Reads every ΕΠΣ in sources.json and stores championships, matches and
// standings in Firestore. Runs on GitHub Actions (.github/workflows/eps-sync.yml).
//
// Env:
//   FIREBASE_SERVICE_ACCOUNT  service-account JSON. Missing -> dry run (no writes).
//   EPS_DRY_RUN=1             force a dry run.
//   EPS_ONLY=eps_achaias      only these assocIds (comma separated).
//   EPS_LIMIT=3               only the first N competitions per ΕΠΣ (testing).
//   GITHUB_STEP_SUMMARY       if set, a summary table is appended there.

const fs = require('fs');
const path = require('path');
const { parseCompetitionLinks, parseMatches, parseStandings, parseScorers } = require('./mascotnet');
const { buildCompetition, competitionIndexEntry, competitionMeta } = require('./build');
const { isAllowed } = require('./robots');
const { teamKey, slug, hashOf } = require('./util');

const USER_AGENT = 'CluberaBot/1.0 (+https://www.clubera-global.com; info@clubera-global.com)';
const DELAY_MS = 1500;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function fetchText(url, attempt = 1) {
  try {
    const res = await fetch(url, {
      headers: { 'User-Agent': USER_AGENT, 'Accept-Language': 'el-GR,el;q=0.9' },
      signal: AbortSignal.timeout(30000),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.text();
  } catch (e) {
    if (attempt >= 3) throw new Error(`${url}: ${e.message}`);
    await sleep(5000 * attempt);
    return fetchText(url, attempt + 1);
  }
}

function initFirestore() {
  const json = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!json || process.env.EPS_DRY_RUN === '1') return null;
  const admin = require('firebase-admin');
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(json)) });
  return admin.firestore();
}

// teamKey -> clubId, from Clubera clubs of this ΕΠΣ plus saved links.
async function loadClubLinks(db, assocId) {
  const byKey = new Map();
  const manual = new Map();
  if (!db) return { byKey, manual };
  const clubs = await db.collection('clubs').where('assocId', '==', assocId).get();
  const seen = new Map();
  clubs.forEach((d) => {
    const k = teamKey(d.get('name'));
    if (!k) return;
    // Two Clubera clubs with the same name: ambiguous, don't auto-link.
    seen.set(k, seen.has(k) ? null : d.id);
  });
  for (const [k, id] of seen) if (id) byKey.set(k, id);
  const links = await db.collection('eps_teams').where('assocId', '==', assocId).get();
  links.forEach((d) => {
    const clubId = d.get('clubId');
    if (d.get('linkSource') === 'manual') {
      manual.set(d.get('teamKey'), clubId || null);
      if (clubId) byKey.set(d.get('teamKey'), clubId);
      else byKey.delete(d.get('teamKey')); // admin said: no Clubera club
    }
  });
  return { byKey, manual };
}

async function syncSource(db, source, summary) {
  const base = source.baseUrl.replace(/\/$/, '');
  const robots = await fetchText(`${base}/robots.txt`).catch(() => '');
  for (const p of ['/table.asp', '/table_analytika.asp']) {
    if (!isAllowed(robots, USER_AGENT, p)) {
      summary.push({ source: source.name, competition: '—', note: `robots.txt δεν επιτρέπει ${p}` });
      return { competitions: 0, matches: 0 };
    }
  }

  const home = await fetchText(`${base}/`);
  let names = parseCompetitionLinks(home);
  if (process.env.EPS_LIMIT) names = names.slice(0, parseInt(process.env.EPS_LIMIT, 10));

  const { byKey, manual } = await loadClubLinks(db, source.assocId);
  const allTeams = new Map(); // teamKey -> { name, competitionIds:Set }
  const index = []; // light list for eps_associations/{assocId}
  let totalMatches = 0;
  let written = 0;

  for (const name of names) {
    const q = encodeURIComponent(name);
    await sleep(DELAY_MS);
    const standingsHtml = await fetchText(`${base}/table.asp?diorganosi=${q}`);
    await sleep(DELAY_MS);
    const matchesHtml = await fetchText(`${base}/table_analytika.asp?diorganosi=${q}`);
    const matches = parseMatches(matchesHtml);
    const standings = parseStandings(standingsHtml);
    totalMatches += matches.length;

    // Scorers only for senior championships: the ΕΠΣ does not publish youth
    // scorers, and we don't show minors' names.
    let scorers = [];
    if (competitionMeta(name).level === 'senior' && isAllowed(robots, USER_AGENT, '/table_scorers.asp')) {
      await sleep(DELAY_MS);
      scorers = parseScorers(await fetchText(`${base}/table_scorers.asp?diorganosi=${q}`));
    }

    const { id, doc, teams } = buildCompetition({ source, name, matches, standings, scorers, clubsByKey: byKey });
    index.push(competitionIndexEntry(id, doc));
    teams.forEach((t) => {
      const k = teamKey(t);
      if (!allTeams.has(k)) allTeams.set(k, { name: t, competitionIds: new Set() });
      allTeams.get(k).competitionIds.add(id);
    });

    let state = 'δοκιμή';
    if (db) {
      const ref = db.collection('eps_competitions').doc(id);
      const existing = await ref.get();
      if (existing.exists && existing.get('hash') === doc.hash) {
        state = 'χωρίς αλλαγές';
      } else {
        await ref.set({ ...doc, updatedAt: new Date() });
        state = existing.exists ? 'ενημερώθηκε' : 'νέο';
        written++;
      }
    }
    const finished = matches.filter((m) => m.status === 'finished').length;
    summary.push({
      source: source.name,
      competition: name,
      note: `${matches.length} αγώνες (${finished} με σκορ), ${standings.length} ομάδες, ${scorers.length} σκόρερ, ${doc.clubIds.length} συνδεδεμένοι σύλλογοι — ${state}`,
    });
  }

  if (db && index.length) {
    // Small document the app reads to list an ΕΠΣ's championships quickly.
    const ref = db.collection('eps_associations').doc(source.assocId);
    const data = { assocId: source.assocId, name: source.name, sourceUrl: source.baseUrl, competitions: index };
    const hash = hashOf(data);
    const existing = await ref.get();
    if (!existing.exists || existing.get('hash') !== hash) {
      await ref.set({ ...data, hash, updatedAt: new Date() });
    }
  }

  if (db) {
    let batch = db.batch();
    let n = 0;
    for (const [k, t] of allTeams) {
      const ref = db.collection('eps_teams').doc(`${source.assocId}__${slug(k)}`);
      const data = {
        assocId: source.assocId,
        teamKey: k,
        name: t.name,
        competitionIds: [...t.competitionIds].sort(),
        updatedAt: new Date(),
      };
      if (!manual.has(k)) {
        data.clubId = byKey.get(k) || null;
        data.linkSource = byKey.has(k) ? 'auto' : null;
      }
      batch.set(ref, data, { merge: true });
      if (++n % 400 === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }
    await batch.commit();
  }

  const linked = [...allTeams.keys()].filter((k) => byKey.has(k)).length;
  summary.push({
    source: source.name,
    competition: 'Σύνολο',
    note: `${names.length} διοργανώσεις, ${totalMatches} αγώνες, ${allTeams.size} ομάδες (${linked} συνδεδεμένες με Clubera), ${written} έγγραφα γράφτηκαν`,
  });
  return { competitions: names.length, matches: totalMatches };
}

function writeSummary(summary, dryRun) {
  const lines = [
    `## Συγχρονισμός ΕΠΣ ${dryRun ? '(δοκιμή, χωρίς εγγραφή στη βάση)' : ''}`,
    '',
    '| ΕΠΣ | Διοργάνωση | Αποτέλεσμα |',
    '|---|---|---|',
    ...summary.map((s) => `| ${s.source} | ${s.competition} | ${s.note} |`),
    '',
  ];
  const text = lines.join('\n');
  console.log(text);
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, text);
}

async function main() {
  const sources = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'sources.json'), 'utf8'));
  const only = (process.env.EPS_ONLY || '').split(',').map((s) => s.trim()).filter(Boolean);
  const db = initFirestore();
  const summary = [];
  let failures = 0;
  let totalMatches = 0;

  for (const source of sources) {
    if (only.length && !only.includes(source.assocId)) continue;
    if (source.platform !== 'mascotnet') {
      summary.push({ source: source.name, competition: '—', note: `άγνωστη πλατφόρμα ${source.platform}` });
      continue;
    }
    try {
      const r = await syncSource(db, source, summary);
      totalMatches += r.matches;
    } catch (e) {
      failures++;
      summary.push({ source: source.name, competition: '—', note: `ΣΦΑΛΜΑ: ${e.message}` });
    }
  }

  writeSummary(summary, !db);
  if (failures || totalMatches === 0) {
    console.error(failures ? `${failures} ΕΠΣ απέτυχαν` : 'Δεν βρέθηκε κανένας αγώνας — μήπως άλλαξε το site;');
    process.exit(1);
  }
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}

module.exports = { main };
