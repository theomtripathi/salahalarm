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
    return env.ASSETS.fetch(request);
  },
};

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
