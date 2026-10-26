#!/usr/bin/env node
// Imports a research batch that ChatGPT (or Muse) saved on Om's Mac, e.g.
//   ~/Documents/Salah Alarm/Content Library/2026-10-25/
// Reads every manifest.json and <file>.source.json sidecar under the folder and adds each post to the
// library. Counts were read off the app's UI by an assistant, so posts come in
// as unverified: the next Apify run re-reads their real numbers. Downloaded
// files are research references only (republishing rights are not
// established), and the library records where they are on the Mac.
//
//   node src/import-batch.js <batch folder> [--mac-root "/Users/pc/Documents/Salah Alarm/Content Library/2026-10-25"]
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { load, save, merge, ranked, toCsv } from './library.js';
import { idOf, platformOf } from './collect/inbox.js';

// Muse's briefs say "SalaLam"; the product is Salah Alarm (salahalarm.com).
const brand = (t) => (t ? String(t).replace(/Sala[- ]?Lam/gi, 'Salah Alarm') : t);
const num = (v) => (v === null || v === undefined || v === '' || Number.isNaN(Number(v)) ? null : Number(v));

function findManifests(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) out.push(...findManifests(p));
    else if (name === 'manifest.json' || name.endsWith('.source.json')) out.push(p);
  }
  return out;
}

export function fromBatchEntry(e, { batchDir, manifestDir, macRoot, foundBy }) {
  const type = String(e.metric_type || '').toLowerCase();
  const views = num(e.observed_grid_views_rounded) ?? num(e.views) ?? (type.includes('views') ? num(e.metric) : null);
  const likes = num(e.likes_from_public_extractor) ?? num(e.likes) ?? (type.includes('likes') ? num(e.metric) : null);
  const files = (e.files || (e.filename ? [e.filename] : []))
    .map((f) => (e.filename && f === e.filename ? relative(batchDir, join(manifestDir, f)) : f));
  const duration = num((e.media_probe || e.probe)?.format?.duration) ?? num(e.duration_observed);
  const fmt = String(e.source_format || '').toLowerCase();
  return {
    platform: String(e.platform || platformOf(e.url)).toLowerCase(),
    // Muse prefixes ids (ig_…, tiktok_<user>_…, yt_…); the URL gives the bare id the library keys on.
    id: e.url ? idOf(e.url) : String(e.id),
    url: e.url,
    author: (e.creator || '').split(' / ')[0].replace(/^@/, '').replace(/&amp;/g, '&') || null,
    followers: null,
    text: [e.topic, e.source_caption].filter(Boolean).join(': ').replace(/[⁦-⁩\t]/g, '').trim(),
    lang: null,
    hashtags: [],
    mediaType: /static|image|carousel/.test(fmt) ? (fmt.includes('carousel') ? 'carousel' : 'image') : 'video',
    durationSec: duration ? Math.round(duration * 10) / 10 : null,
    sound: null,
    postedAt: e.published_utc || (/^\d{4}-\d{2}-\d{2}$/.test(e.post_date_observed || e.post_date || '') ? `${e.post_date_observed || e.post_date}T00:00:00Z` : null),
    metrics: { views, likes, comments: num(e.comments_from_public_extractor) ?? num(e.comments), shares: num(e.browser_reposts_rounded) ?? num(e.shares), saves: num(e.saves) },
    unverified: true,
    source: `batch:${foundBy}`,
    research: {
      localFiles: files.map((f) => (macRoot ? `${macRoot}/${f}` : f)),
      adaptation: brand(e.adaptation || e.note) || null,
      cta: brand(e.cta_en || e.cta) || null,
      visual: e.visual_review || e.source_visual || null,
      downloadStatus: e.download_status || null,
      republish: e.republish_permission || 'not established',
    },
  };
}

export function readBatch(batchDir, { macRoot = null, foundBy = 'chatgpt' } = {}) {
  const byKey = new Map();
  // A single .json file (e.g. Muse's merged manifest) is read as the batch's only manifest.
  const manifests = batchDir.endsWith('.json') ? [batchDir] : findManifests(batchDir);
  if (batchDir.endsWith('.json')) batchDir = dirname(batchDir);
  for (const m of manifests) {
    // A manifest lists many posts; a sidecar (<file>.source.json) describes one.
    const parsed = JSON.parse(readFileSync(m, 'utf8'));
    const list = Array.isArray(parsed) ? parsed : [parsed];
    for (const e of list) {
      if (!e.id || !e.url) continue;
      const it = fromBatchEntry(e, { batchDir, manifestDir: dirname(m), macRoot, foundBy });
      const k = `${it.platform}:${it.id}`;
      const prev = byKey.get(k);
      // The same post can appear in the top manifest and a sub-folder's; keep the richer one.
      if (!prev || Object.values(it.metrics).filter((v) => v !== null).length >= Object.values(prev.metrics).filter((v) => v !== null).length)
        byKey.set(k, prev ? { ...prev, ...it, research: { ...prev.research, ...it.research, localFiles: [...new Set([...prev.research.localFiles, ...it.research.localFiles])] } } : it);
    }
  }
  return [...byKey.values()];
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const dir = args[0];
  const opt = (f) => (args.includes(f) ? args[args.indexOf(f) + 1] : null);
  const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
  const cfg = JSON.parse(readFileSync(join(ROOT, 'config/sources.json'), 'utf8'));
  const lib = load(join(ROOT, 'data/library.json'));
  const items = readBatch(dir, { macRoot: opt('--mac-root'), foundBy: opt('--found-by') || 'chatgpt' });
  const r = merge(lib, items, cfg, opt('--date') || new Date().toISOString().slice(0, 10));
  save(join(ROOT, 'data/library.json'), lib);
  writeFileSync(join(ROOT, 'data/library.csv'), toCsv(ranked(lib)));
  console.log(`batch: ${items.length} posts read, ${r.added} added, ${r.updated} updated, library ${r.total}`);
}

