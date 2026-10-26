// Scores a normalized item. Three questions, in this order of weight:
//   1. Did it break out of its account's normal reach? (outlier)
//   2. Did people pass it on? (shares + saves per view; likes are cheap)
//   3. Is it big in absolute terms? (views)
// Plus a bonus when the post sells an app, because those are the posts whose
// structure most directly converts for us.

const FORMAT_RULES = [
  ['whatif', /\bwhat if\b|\bimagine if\b|ماذا لو|kya ho agar|bagaimana jika/i],
  ['ramadan', /ramadan|ramzan|رمضان|ramazan|puasa|iftar|suhoor|sehri/i],
  ['dayx', /\bday \d+\b|\b\d+ (more )?(fajr|days?)\b|يوم \d+|din \d+|hari ke-?\d+/i],
  ['pov', /\bpov\b|\bme after\b|\bwhen you\b|\banyone else\b|relatable/i],
  ['skit', /\bvs\b|😂|🤣|😭/],
  ['alarm', /alarm|wake (you|me) up|won'?t stop|doesn'?t stop|snooze|منبه|alarm/i],
  ['hadith', /hadith|sahih|muslim \d+|bukhari|tirmidhi|حديث|رواه/i],
  ['quran', /quran|qur'an|surah|ayah|recitation|قرآن|سورة|tilawat/i],
  ['dua', /\bdua\b|دعاء|دعوات|doa\b/i],
  ['list', /\b\d+ (things|ways|sunnahs?|tips|steps|habits)\b|\bthings? (you|nobody)\b/i],
];

export function guessFormat(item) {
  const t = `${item.text || ''} ${(item.hashtags || []).join(' ')}`;
  const hits = FORMAT_RULES.filter(([, re]) => re.test(t)).map(([k]) => k);
  if (item.mediaType === 'carousel') hits.unshift('carousel');
  return hits.length ? hits : ['reminder'];
}

export function appSignal(item, cfg) {
  const t = (item.text || '').toLowerCase();
  const competitor = (cfg.competitors || []).find((c) => t.includes(c.toLowerCase())) || null;
  const promo = competitor !== null || (cfg.appSignals || []).some((s) => t.includes(s.toLowerCase()));
  return { promo, competitor };
}

const log10 = (x) => Math.log10(Math.max(1, x));

export function score(item, cfg = {}, now = Date.now()) {
  const m = item.metrics || {};
  const views = m.views ?? (m.likes != null ? m.likes * 12 : null); // IG often hides plays: ~8% like rate
  const passOn = (m.shares ?? 0) + (m.saves ?? 0);
  const engaged = (m.likes ?? 0) + (m.comments ?? 0) + passOn;
  const shareRate = views && (m.shares != null || m.saves != null) ? passOn / views : null; // unknown, not 0
  const engagementRate = views ? engaged / views : null;
  const outlier = views && item.followers ? views / Math.max(item.followers, 500) : null;
  const ageDays = item.postedAt ? Math.max(0.5, (now - Date.parse(item.postedAt)) / 864e5) : null;
  const viewsPerDay = views && ageDays ? views / ageDays : null;
  const { promo, competitor } = appSignal(item, cfg);

  const s =
    10 * log10(views ?? 0) + // 1M views -> 60
    12 * Math.min(log10(1 + (outlier ?? 1)), 3) + // 100x followers -> 24, capped at 1000x
    300 * Math.min(shareRate ?? 0, 0.1) + // 5% pass-on -> 15, capped at 30
    (promo ? 8 : 0) +
    (ageDays !== null && ageDays <= 14 ? 4 : 0);

  return {
    score: Math.round(s * 10) / 10,
    views,
    viewsEstimated: m.views == null && views != null,
    shareRate,
    engagementRate,
    outlier,
    viewsPerDay,
    ageDays,
    promo,
    competitor,
    formats: guessFormat(item),
  };
}

// Whether an item earns a place in the library. Thresholds are per platform
// because reach differs a lot; outliers from small accounts get in on a lower bar.
export function qualifies(item, sc, cfg = {}) {
  const maxAge = cfg.maxAgeDays ?? 180;
  // Hand-picked research batches are often evergreen hits, so they skip the age cap.
  const research = String(item.source || '').startsWith('batch:');
  if (!research && sc.ageDays !== null && sc.ageDays > maxAge) return false;
  if (item.own) return true; // always track our own posts
  if (item.unverified) return true; // hand-found, waiting for a scraper to confirm numbers
  const v = sc.views ?? 0;
  const bar = { tiktok: 50_000, instagram: 30_000, x: 30_000 }[item.platform] ?? 50_000;
  if (v >= bar) return true;
  if (sc.outlier !== null && sc.outlier >= 20 && v >= 10_000) return true;
  if (sc.promo && v >= 10_000) return true;
  return false;
}
