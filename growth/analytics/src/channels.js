// Channel scoreboard: one row per channel for the last 7 days, from views to
// installs. Channels come from the tracking account ids:
//   ig*  -> instagram     tt*  -> tiktok     x*  -> x
//   seo-* -> seo          cl*  -> clipping   ad-* or paid posts -> ads
export const CHANNELS = ['tiktok', 'instagram', 'x', 'seo', 'clipping', 'ads'];

export function channelOf(account, platform, isAd = false) {
  if (isAd || account?.startsWith('ad-')) return 'ads';
  if (account?.startsWith('seo-')) return 'seo';
  if (account?.startsWith('cl')) return 'clipping';
  if (account?.startsWith('ig') || platform === 'instagram') return 'instagram';
  if (account?.startsWith('tt') || platform === 'tiktok') return 'tiktok';
  if (account?.startsWith('x') || platform === 'x') return 'x';
  return 'other';
}

const blank = () => ({ posts: 0, views: 0, passOn: 0, profileViews: 0, follows: 0, clicks: 0, impressions: 0, pageViews: 0, installs: 0, proceeds: 0 });

// ownPosts: library items with own=true posted in the window.
// links: PostHog link rows {account, clicks}. gsc: Search Console rows.
// asc: App Store campaign rows {account, pageViews, installs, proceeds}.
export function scoreboard({ ownPosts = [], links = [], gsc = [], asc = [] }) {
  const out = Object.fromEntries(CHANNELS.map((c) => [c, blank()]));
  const add = (ch, k, v) => { (out[ch] ||= blank())[k] += Number(v || 0); };
  for (const p of ownPosts) {
    const ch = channelOf(p.account, p.platform, p.isAd);
    add(ch, 'posts', 1);
    add(ch, 'views', p.metrics?.views);
    add(ch, 'passOn', (p.metrics?.shares || 0) + (p.metrics?.saves || 0));
    add(ch, 'profileViews', p.metrics?.profileViews);
    add(ch, 'follows', p.metrics?.follows);
  }
  for (const l of links) add(channelOf(l.account), 'clicks', l.clicks);
  for (const g of gsc) { add('seo', 'impressions', g.impressions); add('seo', 'views', g.clicks); }
  for (const a of asc) {
    const ch = channelOf(a.account);
    add(ch, 'pageViews', a.pageViews); add(ch, 'installs', a.installs); add(ch, 'proceeds', a.proceeds);
  }
  for (const r of Object.values(out)) {
    r.clicksPer1k = r.views ? (r.clicks * 1000) / r.views : null;
    r.installsPer1k = r.views ? (r.installs * 1000) / r.views : null;
    r.profileRate = r.views ? r.profileViews / r.views : null;
  }
  return out;
}
