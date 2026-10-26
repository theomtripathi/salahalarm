// Money: RevenueCat's overview metrics (MRR, active trials and subscriptions,
// 28-day revenue, new customers). Needs REVENUECAT_API_KEY (a v2 secret key
// with read-only "charts metrics" permission) and REVENUECAT_PROJECT_ID.
// App Store Connect campaign numbers (page views and installs per `ct`) have
// no simple API, so they come from a CSV export dropped in data/inbox/.
import { readFileSync, existsSync } from 'node:fs';

export async function revenuecat(key, projectId, { fetchImpl = fetch } = {}) {
  const res = await fetchImpl(`https://api.revenuecat.com/v2/projects/${projectId}/metrics/overview`, {
    headers: { Authorization: `Bearer ${key}` },
  });
  if (!res.ok) throw new Error(`revenuecat ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const j = await res.json();
  return Object.fromEntries((j.metrics || []).map((m) => [m.id, m.value]));
}

// data/inbox/asc-campaigns.csv, exported from App Analytics > Acquisition >
// Campaigns. Columns (any order): date, ct (campaign), page_views, installs, proceeds.
// Several days can be appended; later rows for the same date+ct win.
export function ascCampaigns(path) {
  if (!existsSync(path)) return [];
  const [head, ...lines] = readFileSync(path, 'utf8').trim().split(/\r?\n/);
  const cols = head.split(',').map((c) => c.trim().toLowerCase().replace(/[^a-z_]/g, '_'));
  const rows = {};
  for (const line of lines) {
    const v = line.split(',');
    const r = Object.fromEntries(cols.map((c, i) => [c, v[i]?.trim()]));
    const ct = r.ct || r.campaign;
    if (!ct) continue;
    rows[`${r.date}|${ct}`] = {
      date: r.date, ct, account: ct.split('-').slice(0, ct.startsWith('seo-') ? 2 : 1).join('-'),
      pageViews: Number(r.page_views || r.impressions || 0),
      installs: Number(r.installs || r.first_time_downloads || r.app_units || 0),
      proceeds: Number(r.proceeds || 0),
    };
  }
  return Object.values(rows);
}
