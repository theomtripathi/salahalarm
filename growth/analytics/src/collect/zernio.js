// Our own posts and daily totals from Zernio (the scheduler that posts to the
// TikTok and Instagram accounts). Needs ZERNIO_API_KEY (a read-only key is enough).
import { fromZernio } from '../normalize.js';

const BASE = 'https://zernio.com/api';

async function get(path, params, key, fetchImpl) {
  const qs = new URLSearchParams(Object.entries(params).filter(([, v]) => v != null)).toString();
  const res = await fetchImpl(`${BASE}${path}?${qs}`, { headers: { Authorization: `Bearer ${key}` } });
  if (!res.ok) throw new Error(`zernio ${path} ${res.status}: ${(await res.text()).slice(0, 200)}`);
  return res.json();
}

// `accounts` is config/accounts.json; an account entry may carry
// `zernioAccountId` or a real `handle` so posts map back to tt01, ig1...
export function accountMapFrom(accounts) {
  const map = {};
  for (const a of accounts.accounts || []) {
    if (a.zernioAccountId) map[a.zernioAccountId] = a.id;
    if (a.handle && !a.handle.includes('REPLACE_ME')) {
      map[a.handle] = a.id;
      map[a.handle.replace(/^@/, '')] = a.id;
    }
  }
  return map;
}

export async function collect(key, accounts, { fromDate, toDate, fetchImpl = fetch } = {}) {
  const map = accountMapFrom(accounts);
  const items = [], errors = [];
  let unmapped = new Set();
  for (let page = 1; page <= 20; page++) {
    try {
      const r = await get('/v1/analytics', { fromDate, toDate, limit: 100, page, sortBy: 'date', order: 'desc' }, key, fetchImpl);
      for (const p of r.posts || []) for (const row of fromZernio(p, map)) {
        if (!row.account && row.author) unmapped.add(row.author);
        items.push(row);
      }
      if (!r.pagination || page >= (r.pagination.pages || 1)) break;
    } catch (e) { errors.push(e.message); break; }
  }
  let daily = null;
  try {
    daily = await get('/v1/analytics/daily-metrics', { fromDate, toDate }, key, fetchImpl);
  } catch (e) { errors.push(e.message); }
  if (unmapped.size) errors.push(`zernio: posts from accounts not in config/accounts.json: ${[...unmapped].join(', ')}`);
  return { items, daily, errors };
}
