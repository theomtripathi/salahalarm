// Turn each scraper's raw item into one shape the library understands.
// Missing numbers stay null (unknown), never 0, so scoring can tell them apart.

const num = (v) => (v === undefined || v === null || v === '' || Number.isNaN(Number(v)) ? null : Number(v));

export function fromTikTok(raw, source) {
  const a = raw.authorMeta || {};
  return {
    platform: 'tiktok',
    id: String(raw.id),
    url: raw.webVideoUrl || `https://www.tiktok.com/@${a.name}/video/${raw.id}`,
    author: a.name || null,
    followers: num(a.fans),
    text: raw.text || '',
    lang: raw.textLanguage || null,
    hashtags: (raw.hashtags || []).map((h) => (typeof h === 'string' ? h : h.name)).filter(Boolean),
    mediaType: raw.isSlideshow || raw.imagePost ? 'carousel' : 'video',
    durationSec: num(raw.videoMeta?.duration),
    sound: raw.musicMeta?.musicName || null,
    postedAt: raw.createTimeISO || (raw.createTime ? new Date(raw.createTime * 1000).toISOString() : null),
    metrics: {
      views: num(raw.playCount),
      likes: num(raw.diggCount),
      comments: num(raw.commentCount),
      shares: num(raw.shareCount),
      saves: num(raw.collectCount),
    },
    source,
  };
}

export function fromInstagram(raw, source) {
  const views = num(raw.videoPlayCount) ?? num(raw.videoViewCount) ?? num(raw.igPlayCount);
  return {
    platform: 'instagram',
    id: String(raw.shortCode || raw.id),
    url: raw.url || `https://www.instagram.com/p/${raw.shortCode}/`,
    author: raw.ownerUsername || null,
    followers: num(raw.ownerFollowersCount ?? raw.followersCount),
    text: raw.caption || '',
    lang: null,
    hashtags: raw.hashtags || [],
    mediaType: raw.type === 'Sidecar' ? 'carousel' : raw.type === 'Image' ? 'image' : 'video',
    durationSec: num(raw.videoDuration),
    sound: raw.musicInfo?.song_name || null,
    postedAt: raw.timestamp || null,
    metrics: {
      views,
      likes: num(raw.likesCount) === -1 ? null : num(raw.likesCount),
      comments: num(raw.commentsCount),
      shares: num(raw.sharesCount),
      saves: null,
    },
    source,
  };
}

export function fromX(raw, source) {
  const a = raw.author || {};
  return {
    platform: 'x',
    id: String(raw.id),
    url: raw.url || raw.twitterUrl,
    author: a.userName || null,
    followers: num(a.followers),
    text: raw.text || raw.fullText || '',
    lang: raw.lang || null,
    hashtags: (raw.entities?.hashtags || []).map((h) => h.text),
    mediaType: raw.extendedEntities?.media?.[0]?.type === 'video' ? 'video' : raw.extendedEntities?.media ? 'image' : 'text',
    durationSec: null,
    sound: null,
    postedAt: raw.createdAt ? new Date(raw.createdAt).toISOString() : null,
    metrics: {
      views: num(raw.viewCount),
      likes: num(raw.likeCount),
      comments: num(raw.replyCount),
      shares: (num(raw.retweetCount) ?? 0) + (num(raw.quoteCount) ?? 0),
      saves: num(raw.bookmarkCount),
    },
    source,
  };
}

// Our own posts, from Zernio's /v1/analytics. A post published to several
// accounts carries one `platforms` entry each, so one post can become several
// rows. `accountMap` maps a Zernio accountId or username to our tracking
// account id (tt03, ig1...).
export function fromZernio(post, accountMap = {}) {
  const targets = post.platforms?.length
    ? post.platforms.filter((p) => p.status !== 'failed')
    : [{ platform: post.platform, analytics: post.analytics, platformPostUrl: post.platformPostUrl }];
  return targets.map((t) => {
    const m = t.analytics || post.analytics || {};
    const platform = (t.platform || post.platform) === 'twitter' ? 'x' : t.platform || post.platform;
    const username = t.accountUsername || null;
    return {
      platform,
      id: String(t.platformPostId || post._id),
      url: t.platformPostUrl || post.platformPostUrl || null,
      author: username,
      followers: null,
      text: post.content || '',
      lang: null,
      hashtags: [],
      mediaType: post.mediaType || 'video',
      durationSec: null,
      sound: null,
      postedAt: post.publishedAt || null,
      thumbnail: post.thumbnailUrl || null,
      metrics: {
        views: num(m.views) ?? num(m.impressions),
        likes: num(m.likes),
        comments: num(m.comments),
        shares: num(m.shares),
        saves: num(m.saves),
        profileViews: num(m.profileViews),
        follows: num(m.follows),
        completionRate: num(m.completionRate),
      },
      own: true,
      account: accountMap[t.accountId] || accountMap[username] || accountMap['@' + username] || null,
      isAd: !!post.isAd,
      source: 'zernio',
    };
  });
}
