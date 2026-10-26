// Competitor and outside-niche ads from the Meta Ad Library. An ad that has
// run for months, or in many variations, is one its owner keeps paying for:
// a testing signal worth copying the structure of, not proof that it pays.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';

// Reads a capture's ads.json ({captured_on, ads: [...]}) and rewrites
// creative and video paths to absolute paths on the Mac that holds them.
export function importAds(path, macRoot = null) {
  const d = JSON.parse(readFileSync(path, 'utf8'));
  const at = (p) => (p && macRoot ? `${macRoot}/${p}` : p || null);
  const ads = (d.ads || d).map((a) => ({
    ...a,
    creative_files: [].concat(a.creative_files || []).flatMap((f) => String(f).split('|')).filter(Boolean).map(at),
    video_file: at(a.video_file),
  }));
  return { capturedOn: d.captured_on || null, ads };
}

// Longest-running active ads, one row per distinct hook, at most `perAdvertiser`
// per advertiser so one brand doesn't fill the list.
export function topAds(ads, { limit = 15, perAdvertiser = 2, group = null } = {}) {
  const seen = new Set(), per = {};
  return ads
    .filter((a) => a.status === 'active' && a.days_running && (!group || a.group === group))
    .sort((a, b) => b.days_running - a.days_running || (b.variations_same_creative || 0) - (a.variations_same_creative || 0))
    .filter((a) => {
      const k = `${a.advertiser}|${(a.hook || a.headline || '').slice(0, 60)}`;
      if (seen.has(k) || (per[a.advertiser] || 0) >= perAdvertiser) return false;
      seen.add(k); per[a.advertiser] = (per[a.advertiser] || 0) + 1;
      return true;
    })
    .slice(0, limit);
}

export function load(path) {
  return existsSync(path) ? JSON.parse(readFileSync(path, 'utf8')) : null;
}

export function save(path, data) {
  writeFileSync(path, JSON.stringify(data, null, 1));
}
