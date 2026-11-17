'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const { parseCompetitionLinks, parseMatches, parseStandings } = require('../src/mascotnet');
const { buildCompetition, competitionMeta } = require('../src/build');
const { isAllowed } = require('../src/robots');
const { teamKey, slug, athensToDate, seasonFor } = require('../src/util');

const fixture = (f) => fs.readFileSync(path.join(__dirname, 'fixtures', f), 'utf8');
const source = {
  assocId: 'eps_achaias',
  name: 'ΕΠΣ Αχαΐας',
  platform: 'mascotnet',
  baseUrl: 'https://epsachaias.gr',
  legacyCompetitions: { '^Α ΕΡΑΣΙΤΕΧΝΙΚΗ': 'eps_achaias_a' },
};

test('competition links from the menu, decoded and without duplicates', () => {
  assert.deepEqual(parseCompetitionLinks(fixture('achaia_home.html')), [
    'Α ΕΡΑΣΙΤΕΧΝΙΚΗ - 1ος ΟΜΙΛΟΣ',
    'Α ΕΡΑΣΙΤΕΧΝΙΚΗ - 2ος ΟΜΙΛΟΣ',
    'Β ΕΡΑΣΙΤΕΧΝΙΚΗ - 1ος ΟΜΙΛΟΣ',
    'Κ13 ΚΟΡΑΣΙΔΩΝ 8Χ8',
  ]);
});

test('matches: played, upcoming, and without date', () => {
  const m = parseMatches(fixture('achaia_analytika.html'));
  assert.equal(m.length, 4);

  assert.equal(m[0].home, 'ΑΝΑΓΕΝΝΗΣΗ ΠΑΤΡΩΝ');
  assert.equal(m[0].away, 'ΠΗΓΑΣΟΣ ΜΠΕΓΟΥΛΑΚΙΟΥ');
  assert.equal(m[0].homeScore, 0);
  assert.equal(m[0].awayScore, 4);
  assert.equal(m[0].status, 'finished');
  assert.equal(m[0].round, 1);
  assert.equal(m[0].gameNumber, '1002');
  assert.equal(m[0].venue, 'ΔΗΜΟΤΙΚΟ ΓΗΠΕΔΟ ΖΑΡΟΥΧΛΕΙΚΩΝ');
  // 27.09.2026 19:30 Athens (summer time, UTC+3) = 16:30 UTC
  assert.equal(m[0].date.toISOString(), '2026-09-27T16:30:00.000Z');

  assert.equal(m[2].status, 'upcoming');
  assert.equal(m[2].homeScore, null);
  assert.equal(m[2].scoreText, null);
  assert.equal(m[2].round, 9);
  // 22.11.2026 18:30 Athens (winter time, UTC+2) = 16:30 UTC
  assert.equal(m[2].date.toISOString(), '2026-11-22T16:30:00.000Z');

  assert.equal(m[3].date, null);
  assert.equal(m[3].venue, null);
  assert.equal(m[3].gameNumber, '1090');
});

test('standings: names decoded, numbers parsed', () => {
  const s = parseStandings(fixture('achaia_table.html'));
  assert.equal(s.length, 3);
  assert.deepEqual(s[0], {
    position: 1,
    team: 'ΑΧΑΙΚΗ',
    points: 24,
    played: 8,
    goalsFor: 29,
    goalsAgainst: 2,
    won: 8,
    drawn: 0,
    lost: 0,
    zone: 'ΠΛΕΪ-ΟΦ',
    form: 'ΝΝΝΝΝ',
  });
  assert.equal(s[1].team, 'ΘΥΕΛΛΑ ΠΑΤΡΩΝ');
  assert.equal(s[1].lost, 1);
  assert.equal(s[2].position, 10);
  assert.equal(s[2].zone, 'ΠΛΕΪ-ΑΟΥΤ');
});

test('team keys ignore accents, case and club-type prefixes', () => {
  assert.equal(teamKey('Αχαϊκή'), 'ΑΧΑΙΚΗ');
  assert.equal(teamKey('ΑΟ Νίκη Προαστείου'), teamKey('ΝΙΚΗ ΠΡΟΑΣΤΕΙΟΥ'));
  assert.equal(teamKey('Α.Ο. Θύελλα Πατρών'), 'ΘΥΕΛΛΑ ΠΑΤΡΩΝ');
  assert.equal(teamKey('ΑΟ ΤΡΙΤΑΙΑΣ - Ο ΤΡΙΤΑΙΙΚΟΣ'), 'ΤΡΙΤΑΙΑΣ - Ο ΤΡΙΤΑΙΙΚΟΣ');
});

test('slug, season and Athens time', () => {
  assert.equal(slug('Α ΕΡΑΣΙΤΕΧΝΙΚΗ - 1ος ΟΜΙΛΟΣ'), 'a_erasitechniki_1os_omilos');
  assert.equal(slug('Κ13 ΚΟΡΑΣΙΔΩΝ 8Χ8'), 'k13_korasidon_8ch8');
  assert.equal(seasonFor(new Date('2026-09-27T00:00:00Z')), '2026-2027');
  assert.equal(seasonFor(new Date('2027-03-01T00:00:00Z')), '2026-2027');
  assert.equal(athensToDate(2027, 3, 28, 12, 0).toISOString(), '2027-03-28T09:00:00.000Z');
});

test('competition meta', () => {
  assert.deepEqual(competitionMeta('Α ΕΡΑΣΙΤΕΧΝΙΚΗ - 1ος ΟΜΙΛΟΣ'), { level: 'senior', ageGroup: null, gender: 'men' });
  assert.deepEqual(competitionMeta('Κ13 ΚΟΡΑΣΙΔΩΝ 8Χ8'), { level: 'youth', ageGroup: 'K13', gender: 'women' });
  assert.deepEqual(competitionMeta('Κ17 - Α ELITE'), { level: 'youth', ageGroup: 'K17', gender: 'men' });
});

test('buildCompetition links Clubera clubs and is stable', () => {
  const matches = parseMatches(fixture('achaia_analytika.html'));
  const standings = parseStandings(fixture('achaia_table.html'));
  const clubsByKey = new Map([[teamKey('Αχαϊκή'), 'club_achaiki']]);
  const a = buildCompetition({ source, name: 'Α ΕΡΑΣΙΤΕΧΝΙΚΗ - 1ος ΟΜΙΛΟΣ', matches, standings, clubsByKey });
  const b = buildCompetition({ source, name: 'Α ΕΡΑΣΙΤΕΧΝΙΚΗ - 1ος ΟΜΙΛΟΣ', matches, standings, clubsByKey });

  assert.equal(a.id, 'eps_achaias__a_erasitechniki_1os_omilos');
  assert.equal(a.doc.season, '2026-2027');
  assert.equal(a.doc.legacyCompetitionId, 'eps_achaias_a');
  assert.equal(a.doc.rounds, 18);
  assert.deepEqual(a.doc.clubIds, ['club_achaiki']);
  assert.equal(a.doc.matches[1].homeClubId, 'club_achaiki');
  assert.equal(a.doc.matches[1].id, 'eps_achaias_1005');
  assert.equal(a.doc.standings[0].clubId, 'club_achaiki');
  assert.equal(a.doc.standings[1].clubId, null);
  assert.ok(a.doc.teamKeys.includes('ΘΥΕΛΛΑ ΠΑΤΡΩΝ'));
  assert.equal(a.doc.hash, b.doc.hash);

  const c = buildCompetition({ source, name: 'Α ΕΡΑΣΙΤΕΧΝΙΚΗ - 1ος ΟΜΙΛΟΣ', matches, standings, clubsByKey: new Map() });
  assert.notEqual(a.doc.hash, c.doc.hash);
});

test('robots.txt of epsachaias.gr allows us, blocks AI crawlers', () => {
  const robots = [
    'User-agent: *',
    'Content-Signal: search=yes,ai-train=no,use=reference',
    'Allow: /',
    'User-agent: ClaudeBot',
    'Disallow: /',
    'User-agent: AwarioSmartBot',
    'User-agent: AwarioRssBot',
    'Disallow: /',
  ].join('\n');
  const ua = 'CluberaBot/1.0 (+https://www.clubera-global.com)';
  assert.equal(isAllowed(robots, ua, '/table.asp'), true);
  assert.equal(isAllowed(robots, 'ClaudeBot', '/table.asp'), false);
  assert.equal(isAllowed(robots, 'AwarioRssBot', '/'), false);
  assert.equal(isAllowed('User-agent: *\nDisallow: /', ua, '/table.asp'), false);
  assert.equal(isAllowed('User-agent: *\nDisallow:', ua, '/table.asp'), true);
  assert.equal(isAllowed('', ua, '/table.asp'), true);
});

test('competition index entry is small and counts matches', () => {
  const { competitionIndexEntry } = require('../src/build');
  const matches = parseMatches(fixture('achaia_analytika.html'));
  const standings = parseStandings(fixture('achaia_table.html'));
  const { id, doc } = buildCompetition({ source, name: 'Κ13 ΚΟΡΑΣΙΔΩΝ 8Χ8', matches, standings, clubsByKey: new Map() });
  const e = competitionIndexEntry(id, doc);
  assert.deepEqual(e, {
    id: 'eps_achaias__k13_korasidon_8ch8',
    name: 'Κ13 ΚΟΡΑΣΙΔΩΝ 8Χ8',
    season: '2026-2027',
    level: 'youth',
    ageGroup: 'K13',
    gender: 'women',
    teams: 3,
    rounds: 18,
    played: 2,
    total: 4,
  });
});

test('scorers: names decoded, goals and halves, linked to clubs', () => {
  const { parseScorers } = require('../src/mascotnet');
  const s = parseScorers(fixture('achaia_scorers.html'));
  assert.equal(s.length, 3);
  assert.deepEqual(s[0], {
    name: 'ΠΑΝΤΕΛΗΣ ΚΩΝΣΤΑΝΤΙΝΟΣ',
    team: 'ΕΘΝΙΚΟΣ ΠΟΛΥΤΕΚΝΟΣ',
    goals: 7,
    firstHalf: 5,
    secondHalf: 2,
  });
  assert.equal(s[2].firstHalf, null);

  const clubsByKey = new Map([[teamKey('ΝΙΚΗ ΠΡΟΑΣΤΕΙΟΥ'), 'club_niki']]);
  const { doc } = buildCompetition({
    source, name: 'Α ΕΡΑΣΙΤΕΧΝΙΚΗ - 2ος ΟΜΙΛΟΣ', matches: [], standings: [], scorers: s, clubsByKey,
  });
  assert.equal(doc.scorers[1].clubId, 'club_niki');
  assert.equal(doc.scorers[0].clubId, null);
  assert.deepEqual(doc.scorers.map((x) => x.goals), [7, 4, 1]);
});
