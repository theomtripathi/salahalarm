import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fromTikTok, fromInstagram, fromX, fromZernio } from '../src/normalize.js';
import { score, qualifies, guessFormat } from '../src/score.js';
import { merge, attachConversions, toCsv } from '../src/library.js';
import { analyse, worstScreen, windows } from '../src/funnel.js';
import { scoreboard, channelOf } from '../src/channels.js';
import { readInbox, idOf, platformOf } from '../src/collect/inbox.js';
import { ascCampaigns } from '../src/collect/revenue.js';
import { collect as apifyCollect } from '../src/collect/apify.js';
import { markdown, html } from '../src/report.js';

const cfg = JSON.parse(readFileSync(new URL('../config/sources.json', import.meta.url)));
const NOW = Date.parse('2026-10-25T00:00:00Z');

const tiktokRaw = {
  id: '7400000000000000001', text: 'Muslims after praying 2 rakah before fajr #rich', createTimeISO: '2026-10-20T10:00:00Z',
  webVideoUrl: 'https://www.tiktok.com/@muslim/video/7400000000000000001',
  playCount: 3_200_000, diggCount: 640_000, shareCount: 49_400, commentCount: 5000, collectCount: 34_100,
  authorMeta: { name: 'muslim', fans: 4_400_000 }, hashtags: [{ name: 'rich' }], videoMeta: { duration: 9 },
};
const smallOutlier = { ...tiktokRaw, id: '2', text: '24 more Fajr prayers completed today', playCount: 438_000, shareCount: 1800, collectCount: 3200, authorMeta: { name: 'qadajourney', fans: 2163 } };

test('normalizes TikTok, Instagram and X items', () => {
  const t = fromTikTok(tiktokRaw, 'tiktok:hashtag:fajr');
  assert.equal(t.metrics.views, 3_200_000);
  assert.equal(t.followers, 4_400_000);
  const ig = fromInstagram({ shortCode: 'Cabc', caption: 'Fajr', likesCount: 107000, commentsCount: 208, type: 'Video', ownerUsername: 'aqill_typist', timestamp: '2026-10-01T00:00:00Z' }, 'ig');
  assert.equal(ig.id, 'Cabc');
  assert.equal(ig.metrics.views, null); // hidden plays stay unknown
  const x = fromX({ id: '9', url: 'https://x.com/a/status/9', text: 'our faith app hit $50k mrr', likeCount: 900, retweetCount: 50, quoteCount: 10, viewCount: 120000, createdAt: 'Fri Oct 24 10:00:00 +0000 2026', author: { userName: 'a', followers: 3000 } }, 'x');
  assert.equal(x.metrics.shares, 60);
});

test('Zernio posts expand to one row per account and map to tracking ids', () => {
  const rows = fromZernio({
    _id: 'p1', content: 'App is called SalahAlarm.com, for everybody asking', publishedAt: '2026-10-22T00:00:00Z',
    platforms: [
      { platform: 'tiktok', accountId: 'z1', accountUsername: 'rafiq.salahalarm', platformPostId: '111', analytics: { views: 12587, shares: 40, saves: 90, profileViews: 300 } },
      { platform: 'instagram', status: 'failed' },
    ],
  }, { z1: 'tt05' });
  assert.equal(rows.length, 1);
  assert.equal(rows[0].account, 'tt05');
  assert.equal(rows[0].metrics.profileViews, 300);
});

test('small-account outliers outrank big accounts with similar reach per follower', () => {
  const big = score(fromTikTok(tiktokRaw), cfg, NOW);
  const small = score(fromTikTok(smallOutlier), cfg, NOW);
  assert.ok(small.outlier > 100);
  assert.ok(big.score > 0 && small.score > 0);
  assert.ok(small.score > big.score - 15, 'a 200x outlier should be close to a 3M-view hit');
});

test('format guesses and app-promo detection', () => {
  assert.deepEqual(guessFormat({ text: '24 more Fajr prayers completed today' }).includes('dayx'), true);
  assert.ok(guessFormat({ text: 'What if you never missed Fajr again?' }).includes('whatif'));
  const s = score({ platform: 'tiktok', text: 'this alarm doesnt stop until you scan your prayer mat - just pray app', metrics: { views: 118000 }, followers: 36000, postedAt: '2026-10-10T00:00:00Z' }, cfg, NOW);
  assert.equal(s.promo, true);
  assert.equal(s.competitor, 'just pray');
});

test('qualification bar: big, outlier, promo or own', () => {
  const low = { platform: 'tiktok', text: 'nice', metrics: { views: 9000 }, followers: 100000, postedAt: '2026-10-20T00:00:00Z' };
  assert.equal(qualifies(low, score(low, cfg, NOW), cfg), false);
  assert.equal(qualifies({ ...low, own: true }, score(low, cfg, NOW), cfg), true);
  const old = { ...low, metrics: { views: 1e6 }, postedAt: '2025-01-01T00:00:00Z' };
  assert.equal(qualifies(old, score(old, cfg, NOW), cfg), false);
  const evergreen = { ...old, unverified: true, source: 'batch:muse' };
  assert.equal(qualifies(evergreen, score(evergreen, cfg, NOW), cfg), true);
});

test('library merge keeps history, sources and growth', () => {
  const lib = {};
  const a = fromTikTok(tiktokRaw, 'tiktok:hashtag:fajr');
  let r = merge(lib, [a], cfg, '2026-10-24', NOW);
  assert.equal(r.added, 1);
  const b = fromTikTok({ ...tiktokRaw, playCount: 3_500_000 }, 'tiktok:search:fajr');
  r = merge(lib, [b], cfg, '2026-10-25', NOW);
  const it = lib['tiktok:7400000000000000001'];
  assert.equal(r.updated, 1);
  assert.equal(it.history.length, 2);
  assert.equal(it.growth, 300_000);
  assert.deepEqual(it.sources, ['tiktok:hashtag:fajr', 'tiktok:search:fajr']);
  assert.equal(it.status, 'new');
  assert.ok(toCsv([it]).split('\n')[1].startsWith(String(it.score)));
});

test('hand-found AI posts stay unverified and never overwrite real numbers', () => {
  const lib = {};
  merge(lib, [fromTikTok(tiktokRaw, 'tiktok:hashtag:fajr')], cfg, '2026-10-25', NOW);
  const manual = { platform: 'tiktok', id: '7400000000000000001', url: tiktokRaw.webVideoUrl, metrics: { views: null }, unverified: true, source: 'manual:muse', text: '' };
  merge(lib, [manual], cfg, '2026-10-25', NOW);
  const it = lib['tiktok:7400000000000000001'];
  assert.equal(it.metrics.views, 3_200_000);
  assert.ok(it.sources.includes('manual:muse'));
  const fresh = { ...manual, id: '555', url: 'https://www.tiktok.com/@x/video/555' };
  merge(lib, [fresh], cfg, '2026-10-25', NOW);
  assert.equal(lib['tiktok:555'].status, 'unverified');
});

test('inbox CSV parsing, ids and AI-claimed numbers', () => {
  assert.equal(idOf('https://www.tiktok.com/@a/video/123?lang=en'), '123');
  assert.equal(idOf('https://www.instagram.com/reel/DAbc_1/'), 'DAbc_1');
  assert.equal(platformOf('https://x.com/a/status/1'), 'x');
  const items = readInbox(new URL('./fixtures/manual.csv', import.meta.url).pathname);
  assert.equal(items.length, 2);
  assert.equal(items[0].unverified, true);
  assert.equal(items[0].claimedViews, 1_300_000);
  assert.equal(items[1].unverified, false);
  assert.equal(items[1].metrics.views, 26_000);
});

test('own-post conversions split account clicks by views', () => {
  const lib = { a: { own: true, account: 'tt03', views: 3000 }, b: { own: true, account: 'tt03', views: 1000 } };
  attachConversions(lib, { tt03: { clicks: 8, installs: 4 } });
  assert.equal(lib.a.conv.clicks, 6);
  assert.equal(lib.b.conv.installs, 1);
});

test('funnel alerts on the real 25 Oct snapshot', () => {
  const ph = JSON.parse(readFileSync(new URL('./fixtures/posthog-2026-10-25.json', import.meta.url)));
  const f = analyse(ph.daily, ph.screens, '2026-10-25');
  assert.equal(f.totals.cur.installs, 82);
  const text = f.alerts.map((a) => a.text).join('\n');
  assert.match(text, /cancelled on Apple's payment sheet/);
  assert.match(text, /No purchase recorded/);
  assert.doesNotMatch(text, /Install to paid/); // folded into the no-purchase alert
  assert.doesNotMatch(text, /Reach the paywall/); // last week's 115% is capped, no false drop
  const leak = worstScreen(ph.screens);
  assert.equal(leak.screen, 'screen2'); // 73 -> 64; screen17's resume bump is ignored
});

test('funnel windows follow the calendar when a day has no events', () => {
  const days = ['2026-10-10', '2026-10-16', '2026-10-17', '2026-10-18', '2026-10-22', '2026-10-24', '2026-10-25'].map((day) => ({ day }));
  const w = windows(days, '2026-10-25');
  assert.deepEqual(w.cur.map((r) => r.day), ['2026-10-18', '2026-10-22', '2026-10-24']);
  assert.deepEqual(w.prev.map((r) => r.day), ['2026-10-16', '2026-10-17']);
  assert.equal(w.yesterday.day, '2026-10-24');
});

test('brief links keep underscores in the URL', () => {
  const page = html({}, '[@fatimama__](https://www.tiktok.com/@fatimama__/video/7627289220935109908) and _note_');
  assert.match(page, /href="https:\/\/www.tiktok.com\/@fatimama__\/video\/7627289220935109908"/);
  assert.match(page, /<i>note<\/i>/);
});

test('channels and App Store campaign rows', () => {
  assert.equal(channelOf('seo-en'), 'seo');
  assert.equal(channelOf('tt03'), 'tiktok');
  assert.equal(channelOf('cl01'), 'clipping');
  assert.equal(channelOf('ig1', 'instagram', true), 'ads');
  const asc = ascCampaigns(new URL('./fixtures/asc-campaigns.csv', import.meta.url).pathname);
  assert.deepEqual(asc.map((r) => r.account), ['tt03', 'seo-en']);
  const sb = scoreboard({
    ownPosts: [{ account: 'tt03', platform: 'tiktok', metrics: { views: 10000, shares: 20, saves: 30 } }],
    links: [{ account: 'tt03', clicks: 12 }, { account: 'seo-en', clicks: 31 }],
    gsc: [{ clicks: 40, impressions: 900 }],
    asc,
  });
  assert.equal(sb.tiktok.clicksPer1k, 1.2);
  assert.equal(sb.tiktok.installs, 5);
  assert.equal(sb.seo.views, 40);
});

test('apify collector builds jobs and survives a failing actor', async () => {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, body: JSON.parse(init.body) });
    if (url.includes('instagram')) return { ok: false, status: 402, text: async () => 'not enough credit' };
    if (url.includes('tweet')) return { ok: true, json: async () => [] };
    return { ok: true, json: async () => [tiktokRaw] };
  };
  const r = await apifyCollect(cfg, 't', { fetchImpl, log: () => {}, verifyUrls: ['https://www.tiktok.com/@a/video/1'] });
  assert.equal(calls.length, 6);
  assert.equal(r.items.length, 4);
  assert.equal(r.errors.length, 1);
  assert.match(r.errors[0], /402/);
});

test('brief renders with missing sources', () => {
  const ph = JSON.parse(readFileSync(new URL('./fixtures/posthog-2026-10-25.json', import.meta.url)));
  const md = markdown({
    date: '2026-10-25', funnel: analyse(ph.daily, ph.screens, '2026-10-25'), revenue: null,
    channels: scoreboard({}), library: { total: 0, own: 0, external: 0, added: 0, byPlatform: {}, byFormat: {} },
    clipQueue: [], rising: [], promos: [], own: [], errors: ['Discovery: APIFY_TOKEN not set'],
  });
  assert.match(md, /## 1\. Funnel/);
  assert.match(md, /APIFY_TOKEN not set/);
});

test('imports an assistant research batch from its manifests', async () => {
  const { readBatch } = await import('../src/import-batch.js');
  const dir = new URL('./fixtures/batch', import.meta.url).pathname;
  const items = readBatch(dir, { macRoot: '/Users/pc/CL' });
  assert.equal(items.length, 3);
  const eight = items.find((i) => i.id === 'DcbQy_nIafe');
  assert.equal(eight.metrics.views, 5_400_000); // sub-folder manifest is richer and wins
  assert.deepEqual(eight.research.localFiles, ['/Users/pc/CL/Reel/sub/8tvnn__DcbQy_nIafe.mp4']);
  const lib = {};
  const r = merge(lib, items, cfg, '2026-10-25', NOW);
  assert.equal(r.added, 3); // research batches skip the age cap, so the 2024 post stays
  const jp = lib['instagram:DeXpTz7T4Q5'];
  assert.equal(jp.status, 'unverified');
  assert.equal(jp.viewsEstimated, true);
  assert.equal(jp.author, 'dassahlynnn');
});
