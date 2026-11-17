'use strict';

const crypto = require('crypto');

// Upper-case, no accents/diaeresis, final sigma folded, single spaces.
function normalizeName(s) {
  return String(s || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toUpperCase()
    .replace(/[.,'"`΄’]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

// Common club-type prefixes that ΕΠΣ sites and clubs use inconsistently.
const CLUB_PREFIXES = new Set([
  'ΑΟ', 'ΑΕ', 'ΑΣ', 'ΓΣ', 'ΓΕ', 'ΠΑΟ', 'ΠΑΣ', 'ΑΠΣ', 'ΑΠΟ', 'ΑΜΣ', 'ΑΓΣ',
  'ΦΣ', 'ΠΟ', 'ΜΓΣ', 'ΑΘΛ', 'ΟΜΙΛΟΣ', 'ΣΩΜΑΤΕΙΟ', 'ΑΚΑΔΗΜΙΑ', 'FC', 'ΠΑΕ',
]);

// Key used to match the same team across the ΕΠΣ site and Clubera.
function teamKey(name) {
  const words = normalizeName(name).split(' ').filter(Boolean);
  // "Α.Ο. ΘΥΕΛΛΑ" -> "Α Ο ΘΥΕΛΛΑ" -> "ΑΟ ΘΥΕΛΛΑ"
  let initials = 0;
  while (initials < words.length - 1 && words[initials].length === 1) initials++;
  if (initials >= 2) words.splice(0, initials, words.slice(0, initials).join(''));
  while (words.length > 1 && CLUB_PREFIXES.has(words[0])) words.shift();
  return words.join(' ');
}

const GREEK_TO_LATIN = {
  Α: 'a', Β: 'v', Γ: 'g', Δ: 'd', Ε: 'e', Ζ: 'z', Η: 'i', Θ: 'th', Ι: 'i',
  Κ: 'k', Λ: 'l', Μ: 'm', Ν: 'n', Ξ: 'x', Ο: 'o', Π: 'p', Ρ: 'r', Σ: 's',
  Τ: 't', Υ: 'y', Φ: 'f', Χ: 'ch', Ψ: 'ps', Ω: 'o',
};

// Readable, Firestore-safe id fragment: "Α ΕΡΑΣΙΤΕΧΝΙΚΗ - 1ος ΟΜΙΛΟΣ" -> "a_erasitechniki_1os_omilos"
function slug(s) {
  return normalizeName(s)
    .split('')
    .map((c) => (GREEK_TO_LATIN[c] !== undefined ? GREEK_TO_LATIN[c] : c.toLowerCase()))
    .join('')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

// Wall-clock time in Greece -> real instant (handles summer/winter time).
function athensToDate(year, month, day, hour = 0, minute = 0) {
  const guess = Date.UTC(year, month - 1, day, hour, minute);
  const offsetMin = (instant) => {
    const part = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Europe/Athens',
      timeZoneName: 'shortOffset',
    })
      .formatToParts(new Date(instant))
      .find((p) => p.type === 'timeZoneName').value; // "GMT+2"
    const m = part.match(/GMT([+-]\d+)(?::(\d+))?/);
    if (!m) return 0;
    const h = parseInt(m[1], 10);
    return h * 60 + Math.sign(h) * parseInt(m[2] || '0', 10);
  };
  let instant = guess - offsetMin(guess) * 60000;
  // Second pass in case the first guess was on the other side of a DST switch.
  instant = guess - offsetMin(instant) * 60000;
  return new Date(instant);
}

// "2026-2027" for a match in Sep 2026 or Mar 2027.
function seasonFor(date) {
  const y = date.getUTCFullYear();
  return date.getUTCMonth() >= 6 ? `${y}-${y + 1}` : `${y - 1}-${y}`;
}

function hashOf(value) {
  return crypto.createHash('sha1').update(JSON.stringify(value)).digest('hex');
}

module.exports = { normalizeName, teamKey, slug, athensToDate, seasonFor, hashOf };
