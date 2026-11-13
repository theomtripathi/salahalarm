// Serves the static site from dist/ and sends every request to one canonical
// origin (https://salahalarm.com), so Google never sees www or http duplicates.
// Also answers /ramadan-2027/stats.json with the live challenge joiner count.

const STATS_PATH = '/ramadan-2027/stats.json';
const STATS_TTL = 60; // seconds; one Firestore read a minute per data centre at most

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.hostname === 'www.salahalarm.com' || url.protocol === 'http:') {
      url.hostname = 'salahalarm.com';
      url.protocol = 'https:';
      return Response.redirect(url.toString(), 301);
    }
    if (url.pathname === STATS_PATH) return challengeStats(request, env, ctx);
    if (url.pathname === '/_aff/event' && request.method === 'POST') return affiliateEvent(request, env);
    const res = await env.ASSETS.fetch(request);
    if (res.status === 404 && AFFILIATE_PATH.test(url.pathname)) return affiliateVisit(request, env, url, res);
    return res;
  },
};

// Affiliate links: salahalarm.com/<username>. Only paths that would otherwise 404 are
// checked, so no existing page or URL can ever change. The salahalarm-affiliates Worker
// (service binding AFFILIATES) logs the click, sets the sa_aff cookie and redirects to
// the onboarding; for any name that isn't an affiliate the normal 404 page is returned.
export const AFFILIATE_PATH = /^\/[A-Za-z0-9_]{3,24}\/?$/;

async function affiliateVisit(request, env, url, notFound) {
  if (!env.AFFILIATES) return notFound;
  try {
    const name = url.pathname.replace(/\//g, '');
    const headers = forwardHeaders(request);
    const res = await env.AFFILIATES.fetch(new Request(`https://aff.internal/_visit/${encodeURIComponent(name)}${url.search}`, { headers, redirect: 'manual' }));
    return res.status === 302 ? res : notFound;
  } catch {
    return notFound;
  }
}

// Onboarding beacons (checkout_started, store_redirect) with the visitor's cookies.
async function affiliateEvent(request, env) {
  if (!env.AFFILIATES) return new Response('{"ok":true}', { headers: { 'content-type': 'application/json' } });
  try {
    const body = await request.text();
    return await env.AFFILIATES.fetch(new Request('https://aff.internal/_aff/event', { method: 'POST', headers: forwardHeaders(request), body: body.slice(0, 4000) }));
  } catch {
    return new Response('{"ok":false}', { status: 502, headers: { 'content-type': 'application/json' } });
  }
}

function forwardHeaders(request) {
  const h = new Headers();
  for (const k of ['cookie', 'user-agent', 'accept-language']) {
    const v = request.headers.get(k);
    if (v) h.set(k, v);
  }
  h.set('content-type', 'application/json');
  if (request.cf?.country) h.set('x-aff-country', request.cf.country);
  const ref = request.headers.get('referer');
  if (ref) h.set('x-aff-referer', ref);
  return h;
}

// challengeStats/global.joinedCount, written by the app on each join. Needs the
// Firestore rule `match /challengeStats/{doc} { allow read: if true; }`.
export async function challengeStats(request, env, ctx) {
  const cache = globalThis.caches?.default;
  const key = new Request(new URL(STATS_PATH, request.url).href);
  const hit = cache && (await cache.match(key));
  if (hit) return hit;

  const project = env.FIREBASE_PROJECT_ID || 'ramadan-pro-684da';
  let joined = null;
  try {
    const res = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/challengeStats/global`);
    if (res.ok) joined = joinedCountOf(await res.json());
  } catch {
    // Network error: answer null so the page keeps its fallback text.
  }
  const body = JSON.stringify({ joined, updatedAt: new Date().toISOString() });
  const out = new Response(body, {
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': `public, max-age=${joined === null ? 10 : STATS_TTL}`,
    },
  });
  if (cache && joined !== null) ctx?.waitUntil?.(cache.put(key, out.clone()));
  return out;
}

export function joinedCountOf(doc) {
  const f = doc?.fields?.joinedCount;
  const n = Number(f?.integerValue ?? f?.doubleValue);
  return Number.isFinite(n) && n >= 0 ? Math.floor(n) : null;
}
