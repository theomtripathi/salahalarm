// The content library: every qualifying post we've seen, keyed by platform:id,
// with a short view history so we can see what is still climbing.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { score, qualifies } from './score.js';

export const keyOf = (it) => `${it.platform}:${it.id}`;

export function load(path) {
  if (!existsSync(path)) return {};
  return JSON.parse(readFileSync(path, 'utf8'));
}

export function save(path, lib) {
  writeFileSync(path, JSON.stringify(lib, null, 1));
}

// Merge fresh items into the library. Returns counts for the report.
export function merge(lib, items, cfg, today, now = Date.now()) {
  let added = 0, updated = 0, skipped = 0;
  for (const it of items) {
    if (!it || !it.id) { skipped++; continue; }
    const k = keyOf(it);
    const sc = score(it, cfg, now);
    const prev = lib[k];
    if (it.unverified && prev && !prev.unverified) {
      // Already have real numbers for this post; just remember who flagged it.
      prev.sources = [...new Set([...(prev.sources || []), it.source])];
      updated++;
      continue;
    }
    if (!prev && !qualifies(it, sc, cfg)) { skipped++; continue; }
    const history = prev?.history || [];
    if (sc.views !== null && history.at(-1)?.d !== today) history.push({ d: today, v: sc.views });
    else if (sc.views !== null) history.at(-1).v = sc.views;
    lib[k] = {
      ...prev,
      ...it,
      // A post found through several hashtags keeps every source.
      sources: [...new Set([...(prev?.sources || []), it.source].filter(Boolean))],
      firstSeen: prev?.firstSeen || today,
      lastSeen: today,
      history: history.slice(-30),
      ...sc,
      unverified: !!it.unverified,
      growth: growthOf(history),
      status: it.unverified ? prev?.status || 'unverified' : prev?.status && prev.status !== 'unverified' ? prev.status : 'new',
      clipNotes: prev?.clipNotes || '',
    };
    delete lib[k].source;
    prev ? updated++ : added++;
  }
  return { added, updated, skipped, total: Object.keys(lib).length };
}

// Views gained per day across the last two snapshots.
function growthOf(h) {
  if (h.length < 2) return null;
  const a = h.at(-2), b = h.at(-1);
  const days = Math.max(1, (Date.parse(b.d) - Date.parse(a.d)) / 864e5);
  return Math.round((b.v - a.v) / days);
}

// Attach real conversion numbers to our own posts. `perAccount` comes from the
// funnel source: { tt03: { clicks, installs, trials } } for the window.
// Installs are split across an account's posts by their share of views, the
// same rule the conversion tracker uses.
export function attachConversions(lib, perAccount) {
  const byAcct = {};
  for (const it of Object.values(lib)) if (it.own && it.account) (byAcct[it.account] ||= []).push(it);
  for (const [acct, posts] of Object.entries(byAcct)) {
    const c = perAccount[acct];
    if (!c) continue;
    const total = posts.reduce((s, p) => s + (p.views || 0), 0) || 1;
    for (const p of posts) {
      const share = (p.views || 0) / total;
      p.conv = {
        clicks: round1((c.clicks || 0) * share),
        installs: c.installs == null ? null : round1(c.installs * share),
        trials: c.trials == null ? null : round1(c.trials * share),
        clicksPer1k: p.views ? round1(((c.clicks || 0) * share * 1000) / p.views) : null,
      };
    }
  }
}

const round1 = (x) => Math.round(x * 10) / 10;

export function ranked(lib, { own = null, platform = null, limit = Infinity } = {}) {
  return Object.values(lib)
    .filter((it) => (own === null || !!it.own === own) && (!platform || it.platform === platform))
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);
}

const CSV_COLS = [
  'score', 'platform', 'url', 'author', 'followers', 'views', 'viewsEstimated', 'unverified', 'outlier', 'shareRate', 'viewsPerDay',
  'growth', 'promo', 'competitor', 'formats', 'mediaType', 'durationSec', 'postedAt', 'firstSeen',
  'status', 'own', 'account', 'localFile', 'adaptation', 'text',
];

export function toCsv(items) {
  const esc = (v) => {
    if (v === null || v === undefined) return '';
    if (Array.isArray(v)) v = v.join('|');
    if (typeof v === 'number' && !Number.isInteger(v)) v = v.toFixed(4);
    const s = String(v).replace(/\s+/g, ' ').slice(0, 300);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const val = (it, c) => (c === 'localFile' ? it.research?.localFiles?.[0] : c === 'adaptation' ? it.research?.adaptation : it[c]);
  return [CSV_COLS.join(','), ...items.map((it) => CSV_COLS.map((c) => esc(val(it, c))).join(','))].join('\n') + '\n';
}
