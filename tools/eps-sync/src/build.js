'use strict';

// Turns parsed pages into the Firestore documents written by sync.js.
//
// eps_competitions/{assocId}__{slug}
//   One document per championship/group: standings + every match of the season.
//   `teamKeys` / `clubIds` allow "array-contains" queries from the app
//   (e.g. all competitions of a club).
//
// eps_teams/{assocId}__{teamKeySlug}
//   Every team seen on the ΕΠΣ site and the Clubera club it belongs to
//   (clubId). linkSource: 'auto' (name matched) or 'manual' (set by an admin;
//   never overwritten by the sync).

const { teamKey, slug, seasonFor, hashOf } = require('./util');

function competitionMeta(name) {
  const youth = name.match(/^Κ\s*(\d{1,2})\b/i);
  return {
    level: youth ? 'youth' : 'senior',
    ageGroup: youth ? `K${youth[1]}` : null,
    gender: /ΚΟΡΑΣΙΔ|ΓΥΝΑΙΚ/i.test(name) ? 'women' : 'men',
  };
}

// clubsByKey: Map teamKey -> clubId (from Clubera clubs + existing links).
function buildCompetition({ source, name, matches, standings, scorers = [], clubsByKey }) {
  const id = `${source.assocId}__${slug(name)}`;
  const linkOf = (team) => clubsByKey.get(teamKey(team)) || null;

  const firstDate = matches.map((m) => m.date).filter(Boolean).sort((a, b) => a - b)[0];
  const season = firstDate ? seasonFor(firstDate) : null;

  let legacyCompetitionId = null;
  for (const [pattern, legacyId] of Object.entries(source.legacyCompetitions || {})) {
    if (new RegExp(pattern, 'i').test(name)) {
      legacyCompetitionId = legacyId;
      break;
    }
  }

  const outMatches = matches.map((m) => ({
    id: m.gameNumber ? `${source.assocId}_${m.gameNumber}` : null,
    gameNumber: m.gameNumber,
    round: m.round,
    homeTeam: m.home,
    awayTeam: m.away,
    homeClubId: linkOf(m.home),
    awayClubId: linkOf(m.away),
    homeScore: m.homeScore,
    awayScore: m.awayScore,
    status: m.status,
    note: m.scoreText,
    scheduledAt: m.date ? m.date.toISOString() : null,
    hasTime: m.hasTime,
    venue: m.venue,
  }));

  const outStandings = standings.map((r) => ({ ...r, clubId: linkOf(r.team) }));
  const outScorers = scorers
    .map((r) => ({ ...r, clubId: linkOf(r.team) }))
    .sort((a, b) => b.goals - a.goals);

  const teams = new Set();
  matches.forEach((m) => { teams.add(m.home); teams.add(m.away); });
  standings.forEach((r) => teams.add(r.team));
  const teamKeys = [...new Set([...teams].map(teamKey))].sort();
  const clubIds = [...new Set(teamKeys.map((k) => clubsByKey.get(k)).filter(Boolean))].sort();

  const doc = {
    assocId: source.assocId,
    assocName: source.name,
    name,
    season,
    ...competitionMeta(name),
    legacyCompetitionId,
    source: source.platform,
    sourceUrl: `${source.baseUrl}/table.asp?diorganosi=${encodeURIComponent(name)}`,
    rounds: Math.max(0, ...matches.map((m) => m.round || 0)),
    standings: outStandings,
    scorers: outScorers,
    matches: outMatches,
    teamKeys,
    clubIds,
  };
  doc.hash = hashOf(doc);
  return { id, doc, teams: [...teams] };
}

// One entry of eps_associations/{assocId}.competitions (no matches/standings).
function competitionIndexEntry(id, doc) {
  return {
    id,
    name: doc.name,
    season: doc.season,
    level: doc.level,
    ageGroup: doc.ageGroup,
    gender: doc.gender,
    teams: doc.standings.length || doc.teamKeys.length,
    rounds: doc.rounds,
    played: doc.matches.filter((m) => m.status === 'finished').length,
    total: doc.matches.length,
  };
}

module.exports = { buildCompetition, competitionMeta, competitionIndexEntry };
