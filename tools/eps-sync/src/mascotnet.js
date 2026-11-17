'use strict';

// Parsers for ΕΠΣ websites built on the Mascot Network (MASCOTNET) platform,
// e.g. epsachaias.gr, epsl.gr, epskerkyras.gr, eps-imathias.gr.
//   table.asp?diorganosi=X            standings
//   table_analytika.asp?diorganosi=X  every match of the season, by round

const { parse } = require('node-html-parser');
const { athensToDate } = require('./util');

const clean = (s) => String(s || '').replace(/ /g, ' ').replace(/\s+/g, ' ').trim();

// Competition names linked from the home page menu ("table.asp?diorganosi=...").
function parseCompetitionLinks(homeHtml) {
  const root = parse(homeHtml);
  const names = [];
  for (const a of root.querySelectorAll('a')) {
    const href = a.getAttribute('href') || '';
    const m = href.match(/(?:^|\/)table\.asp\?diorganosi=([^&#]+)/i);
    if (!m) continue;
    let name;
    try {
      name = decodeURIComponent(m[1].replace(/\+/g, ' '));
    } catch (_) {
      name = m[1];
    }
    name = clean(name);
    if (name && !names.includes(name)) names.push(name);
  }
  return names;
}

// "27.09.2026   19.30   |   ΓΗΠΕΔΟ"  (date/time/venue may be missing)
function parseMeta(text) {
  const t = clean(text);
  const out = { date: null, venue: null };
  const dm = t.match(/(\d{1,2})\.(\d{1,2})\.(\d{4})(?:\s+(\d{1,2})[.:](\d{2}))?/);
  if (dm) {
    out.date = athensToDate(+dm[3], +dm[2], +dm[1], dm[4] ? +dm[4] : 0, dm[5] ? +dm[5] : 0);
    out.hasTime = Boolean(dm[4]);
  }
  const pipe = t.indexOf('|');
  if (pipe >= 0) {
    const venue = clean(t.slice(pipe + 1));
    if (venue) out.venue = venue;
  }
  return out;
}

function parseScore(text) {
  const m = clean(text).match(/^(\d+)\s*-\s*(\d+)/);
  return m ? { home: +m[1], away: +m[2] } : null;
}

// All matches of one competition, from table_analytika.asp.
function parseMatches(html) {
  const root = parse(html);
  const matches = [];
  for (const section of root.querySelectorAll('section.an-round')) {
    const head = clean(section.querySelector('.an-round-head strong')?.text);
    const rm = head.match(/(\d+)/);
    const round = rm ? +rm[1] : null;
    for (const el of section.querySelectorAll('.an-match')) {
      const home = clean(el.querySelector('.an-home')?.text);
      const away = clean(el.querySelector('.an-away')?.text);
      if (!home || !away) continue;

      const metaEl = el.querySelector('.an-meta');
      // The "ΠΛΗΡΟΦΟΡΙΕΣ ΑΓΩΝΑ" link sits inside .an-meta; drop it from the text.
      const link = metaEl?.querySelector('a.an-link');
      const gameHref = link?.getAttribute('href')
        || el.querySelector('a[href*="game_number="]')?.getAttribute('href') || '';
      const gm = gameHref.match(/game_number=(\d+)/);
      if (link) link.remove();
      const meta = parseMeta(metaEl?.text);

      const scoreEl = el.querySelector('.an-score');
      const score = parseScore(scoreEl?.text);
      const scoreText = clean(scoreEl?.text);

      matches.push({
        gameNumber: gm ? gm[1] : null,
        round,
        home,
        away,
        homeScore: score ? score.home : null,
        awayScore: score ? score.away : null,
        status: score ? 'finished' : 'upcoming',
        scoreText: score ? null : (scoreText && !/^[–-]\s*:\s*[–-]$/.test(scoreText) ? scoreText : null),
        date: meta.date,
        hasTime: meta.hasTime || false,
        venue: meta.venue,
      });
    }
  }
  return matches;
}

// Standings from table.asp.
function parseStandings(html) {
  const root = parse(html);
  const table = root.querySelector('table.epsm-standings-table') || root.querySelector('table.ach-table');
  if (!table) return [];
  const rows = [];
  for (const tr of table.querySelectorAll('tbody tr')) {
    const tds = tr.querySelectorAll('td');
    if (tds.length < 5) continue;
    const nameLink = tds[0].querySelector('a.ach-name') || tds[0].querySelector('a');
    const rawName = clean(nameLink ? nameLink.text : tds[0].getAttribute('title') || tds[0].text);
    const pm = rawName.match(/^(\d+)\.\s*(.*)$/);
    const team = clean(tds[0].getAttribute('title')) || (pm ? pm[2] : rawName);
    const num = (i) => {
      const v = parseInt(clean(tds[i]?.text), 10);
      return Number.isNaN(v) ? 0 : v;
    };
    const pair = (i) => clean(tds[i]?.text).split('-').map((x) => parseInt(x, 10) || 0);
    const [gf, ga] = pair(3);
    const [w, d, l] = pair(4);
    const badge = clean(tds[0].querySelector('.ach-rank-badge')?.text) || null;
    const formEl = tr.querySelector('.ach-form');
    const form = formEl ? clean(formEl.text).replace(/\s/g, '') : '';
    rows.push({
      position: pm ? +pm[1] : rows.length + 1,
      team,
      points: num(1),
      played: num(2),
      goalsFor: gf,
      goalsAgainst: ga,
      won: w,
      drawn: d || 0,
      lost: l || 0,
      zone: badge,
      form,
    });
  }
  return rows;
}

// Scorers from table_scorers.asp (published for senior championships only).
function parseScorers(html) {
  const root = parse(html);
  const rows = [];
  for (const tr of root.querySelectorAll('tr.mn-player-row')) {
    const name = clean(tr.querySelector('.scorer-name')?.text);
    const teamEl = tr.querySelector('.scorer-team');
    const team = clean(teamEl?.getAttribute('title')) || clean(teamEl?.text);
    const goals = parseInt(clean(tr.querySelector('.goal-value')?.text), 10);
    if (!name || Number.isNaN(goals)) continue;
    const halves = clean(tr.querySelector('.goal-halves')?.text).match(/(\d+)\s*\+\s*(\d+)/);
    rows.push({
      name,
      team,
      goals,
      firstHalf: halves ? +halves[1] : null,
      secondHalf: halves ? +halves[2] : null,
    });
  }
  return rows;
}

module.exports = { parseCompetitionLinks, parseMatches, parseStandings, parseScorers, parseMeta };
