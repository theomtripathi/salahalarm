// Discovery: other people's top posts on TikTok, Instagram and X, through
// Apify scrapers. Needs APIFY_TOKEN. Each actor run is synchronous and
// returns its dataset; a failed query is logged and skipped, not fatal.
import { fromTikTok, fromInstagram, fromX } from '../normalize.js';

const ACTORS = {
  tiktok: 'clockworks~tiktok-scraper',
  instagram: 'apify~instagram-hashtag-scraper',
  x: 'apidojo~tweet-scraper',
};

async function run(actor, input, token, fetchImpl = fetch) {
  const url = `https://api.apify.com/v2/acts/${actor}/run-sync-get-dataset-items?timeout=280`;
  const res = await fetchImpl(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(input),
  });
  if (!res.ok) throw new Error(`${actor} ${res.status}: ${(await res.text()).slice(0, 200)}`);
  return res.json();
}

// Returns { items, errors }. Queries run one actor call per kind, so a day's
// run is about 4 actor calls.
export async function collect(cfg, token, { fetchImpl = fetch, log = console.log, verifyUrls = [] } = {}) {
  const items = [], errors = [];
  const n = cfg.perQuery ?? 40;
  const jobs = [];
  const tt = cfg.tiktok || {};
  if (tt.hashtags?.length)
    jobs.push(['tiktok', 'hashtag', ACTORS.tiktok, { hashtags: tt.hashtags, resultsPerPage: n, shouldDownloadVideos: false, shouldDownloadCovers: false }]);
  if (tt.searches?.length)
    jobs.push(['tiktok', 'search', ACTORS.tiktok, { searchQueries: tt.searches, resultsPerPage: n, searchSection: '/video', shouldDownloadVideos: false, shouldDownloadCovers: false }]);
  if (tt.profiles?.length)
    jobs.push(['tiktok', 'profile', ACTORS.tiktok, { profiles: tt.profiles, resultsPerPage: n, profileScrapeSections: ['videos'], profileSorting: 'popular', shouldDownloadVideos: false, shouldDownloadCovers: false }]);
  // Hand-found posts get their real numbers from the same scrapers.
  const vt = verifyUrls.filter((u) => /tiktok\.com/.test(u));
  const vi = verifyUrls.filter((u) => /instagram\.com/.test(u));
  if (vt.length) jobs.push(['tiktok', 'verify', ACTORS.tiktok, { postURLs: vt, shouldDownloadVideos: false, shouldDownloadCovers: false }]);
  if (vi.length) jobs.push(['instagram', 'verify', 'apify~instagram-scraper', { directUrls: vi, resultsType: 'posts', resultsLimit: 1 }]);
  if (cfg.instagram?.hashtags?.length)
    jobs.push(['instagram', 'hashtag', ACTORS.instagram, { hashtags: cfg.instagram.hashtags, resultsLimit: n, resultsType: 'posts' }]);
  if (cfg.x?.searches?.length)
    jobs.push(['x', 'search', ACTORS.x, { searchTerms: cfg.x.searches, maxItems: n * cfg.x.searches.length, sort: 'Top' }]);

  const norm = { tiktok: fromTikTok, instagram: fromInstagram, x: fromX };
  for (const [platform, kind, actor, input] of jobs) {
    try {
      const raw = await run(actor, input, token, fetchImpl);
      const tag = (r) => `${platform}:${kind}:${r.searchHashtag?.name || r.input || r.searchQuery || r.inputUrl || ''}`.replace(/:$/, '');
      for (const r of raw) if (!r.error && !r.noResults) items.push(norm[platform](r, tag(r)));
      log(`apify ${platform}/${kind}: ${raw.length} raw`);
    } catch (e) {
      errors.push(`apify ${platform}/${kind}: ${e.message}`);
    }
  }
  return { items, errors };
}
