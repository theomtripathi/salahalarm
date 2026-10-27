// Hand-found posts: from ChatGPT, Muse (Meta AI), a VA, or scrolling.
// data/inbox/manual.csv columns: url, views, likes, shares, saves, comments,
// followers, author, text, found_by. Only url is required. Rows with no
// numbers still go in the library as "unverified" so the next Apify run (or a
// human) can fill them in. AI assistants often make up view counts, so
// numbers from them are kept only once a scraper confirms the post exists.
import { readFileSync, existsSync } from 'node:fs';

export function platformOf(url) {
  if (/tiktok\.com/.test(url)) return 'tiktok';
  if (/instagram\.com/.test(url)) return 'instagram';
  if (/(twitter|x)\.com/.test(url)) return 'x';
  if (/youtube\.com|youtu\.be/.test(url)) return 'youtube';
  if (/pinterest\./.test(url)) return 'pinterest';
  return 'web';
}

export function idOf(url) {
  const m = /(?:video|photo)\/(\d+)|\/(?:p|reel|reels)\/([\w-]+)|status\/(\d+)|pin\/(?:[\w-]*?-)?(\d+)\/?|shorts\/([\w-]+)|[?&]v=([\w-]+)/.exec(url);
  return m ? m.slice(1).find(Boolean) : url.replace(/^https?:\/\//, '').replace(/[?#].*$/, '');
}

function parseCsv(text) {
  const rows = []; let row = [], cell = '', q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) { if (c === '"' && text[i + 1] === '"') { cell += '"'; i++; } else if (c === '"') q = false; else cell += c; }
    else if (c === '"') q = true;
    else if (c === ',') { row.push(cell); cell = ''; }
    else if (c === '\n' || c === '\r') { if (c === '\r' && text[i + 1] === '\n') i++; row.push(cell); rows.push(row); row = []; cell = ''; }
    else cell += c;
  }
  if (cell || row.length) { row.push(cell); rows.push(row); }
  return rows.filter((r) => r.some((x) => x.trim()));
}

export function readInbox(path) {
  if (!existsSync(path)) return [];
  const [head, ...rows] = parseCsv(readFileSync(path, 'utf8'));
  const cols = head.map((h) => h.trim().toLowerCase());
  // Accepts 26000, 26,000, 26k, 1.3m.
  const n = (v) => {
    const m = /^([\d.]+)\s*([km]?)$/i.exec(String(v ?? '').replace(/[, ]/g, ''));
    return m ? Math.round(Number(m[1]) * { '': 1, k: 1e3, m: 1e6 }[m[2].toLowerCase()]) : null;
  };
  return rows.map((r) => Object.fromEntries(cols.map((c, i) => [c, r[i] ?? '']))).filter((r) => r.url).map((r) => {
    const fromAi = /gpt|muse|meta|ai/i.test(r.found_by || '');
    const views = n(r.views);
    return {
      platform: platformOf(r.url), id: idOf(r.url), url: r.url.trim(), author: r.author || null,
      followers: fromAi ? null : n(r.followers ?? ''), text: r.text || '', lang: null, hashtags: [],
      mediaType: 'video', durationSec: null, sound: null, postedAt: null,
      metrics: fromAi ? { views: null } : { views, likes: n(r.likes ?? ''), shares: n(r.shares ?? ''), saves: n(r.saves ?? ''), comments: n(r.comments ?? '') },
      claimedViews: fromAi ? views : undefined,
      unverified: fromAi || views === null,
      source: `manual:${r.found_by || 'unknown'}`,
    };
  });
}
