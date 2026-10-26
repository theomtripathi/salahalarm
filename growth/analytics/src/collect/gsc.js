// SEO: Google Search Console clicks and impressions for salahalarm.com, per
// blog language and per page. Needs GSC_SERVICE_ACCOUNT_JSON (the whole JSON
// key of a service account that was added as a user on the property) and
// optionally GSC_SITE (default sc-domain:salahalarm.com).
import { createSign } from 'node:crypto';

const b64url = (b) => Buffer.from(b).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');

async function token(sa, fetchImpl) {
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = b64url(JSON.stringify({
    iss: sa.client_email, scope: 'https://www.googleapis.com/auth/webmasters.readonly',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  }));
  const sig = createSign('RSA-SHA256').update(`${head}.${claim}`).sign(sa.private_key);
  const res = await fetchImpl('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${head}.${claim}.${b64url(sig)}` }),
  });
  if (!res.ok) throw new Error(`gsc token ${res.status}: ${(await res.text()).slice(0, 200)}`);
  return (await res.json()).access_token;
}

export function langOf(page) {
  const m = /\/blog\/([a-z]{2})\//.exec(page || '');
  return m ? `seo-${m[1]}` : 'seo-home';
}

export async function collect(saJson, { site = process.env.GSC_SITE || 'sc-domain:salahalarm.com', startDate, endDate, fetchImpl = fetch } = {}) {
  const sa = typeof saJson === 'string' ? JSON.parse(saJson) : saJson;
  const t = await token(sa, fetchImpl);
  const res = await fetchImpl(`https://www.googleapis.com/webmasters/v3/sites/${encodeURIComponent(site)}/searchAnalytics/query`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${t}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ startDate, endDate, dimensions: ['date', 'page', 'query'], rowLimit: 5000 }),
  });
  if (!res.ok) throw new Error(`gsc query ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const rows = ((await res.json()).rows || []).map((r) => ({
    date: r.keys[0], page: r.keys[1], query: r.keys[2], account: langOf(r.keys[1]),
    clicks: r.clicks, impressions: r.impressions, position: r.position,
  }));
  return { rows, errors: [] };
}
