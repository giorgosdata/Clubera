'use strict';

// eps_days/{assocId}__{YYYY-MM-DD}
//   All dated matches of one ΕΠΣ on one day (Greek date), so the app's
//   "Προσεχείς" / "Αποτελέσματα" / "Κουπόνι" screens read one small document
//   per day instead of every championship.

const { hashOf } = require('./util');

const dayFormat = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Europe/Athens',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

// "2026-11-21" for an instant, in Greek time.
function athensDay(date) {
  return dayFormat.format(date);
}

// competitions: [{ id, doc }] as produced by buildCompetition.
// Returns Map dayId -> document.
function buildDays(assocId, assocName, competitions) {
  const days = new Map();
  for (const { id, doc } of competitions) {
    for (const m of doc.matches) {
      if (!m.scheduledAt || !m.id) continue;
      const day = athensDay(new Date(m.scheduledAt));
      const dayId = `${assocId}__${day}`;
      if (!days.has(dayId)) days.set(dayId, { assocId, assocName, day, matches: [] });
      days.get(dayId).matches.push({
        ...m,
        competitionId: id,
        competitionName: doc.name,
        level: doc.level,
        gender: doc.gender,
      });
    }
  }
  for (const d of days.values()) {
    d.matches.sort((a, b) => (a.scheduledAt < b.scheduledAt ? -1 : a.scheduledAt > b.scheduledAt ? 1 : 0)
      || a.competitionName.localeCompare(b.competitionName));
    d.hash = hashOf(d);
  }
  return days;
}

module.exports = { buildDays, athensDay };
