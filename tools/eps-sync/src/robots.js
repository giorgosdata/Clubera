'use strict';

// Minimal robots.txt check: is `path` allowed for `agent`?
// Uses the most specific matching User-agent group (our name, else "*"),
// and the longest matching Allow/Disallow rule inside it.
function isAllowed(robotsTxt, agent, path) {
  const groups = [];
  let current = null;
  let lastWasAgent = false;
  for (const raw of String(robotsTxt || '').split(/\r?\n/)) {
    const line = raw.replace(/#.*/, '').trim();
    if (!line) continue;
    const idx = line.indexOf(':');
    if (idx < 0) continue;
    const key = line.slice(0, idx).trim().toLowerCase();
    const value = line.slice(idx + 1).trim();
    if (key === 'user-agent') {
      if (!lastWasAgent) {
        current = { agents: [], rules: [] };
        groups.push(current);
      }
      current.agents.push(value.toLowerCase());
      lastWasAgent = true;
    } else {
      lastWasAgent = false;
      if (!current) continue;
      if (key === 'allow' || key === 'disallow') current.rules.push({ allow: key === 'allow', path: value });
    }
  }
  const a = agent.toLowerCase();
  let group = groups.find((g) => g.agents.some((x) => x !== '*' && a.includes(x)));
  if (!group) group = groups.find((g) => g.agents.includes('*'));
  if (!group) return true;
  let best = null;
  for (const r of group.rules) {
    if (!r.path) continue; // "Disallow:" (empty) allows everything
    if (path.startsWith(r.path) && (!best || r.path.length > best.path.length
      || (r.path.length === best.path.length && r.allow))) {
      best = r;
    }
  }
  return best ? best.allow : true;
}

module.exports = { isAllowed };
