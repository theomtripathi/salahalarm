#!/usr/bin/env node
// Picks the next keyword to write about. Syncs status from content/ first, then
// scores every `todo` keyword: manual priority, Keyword Planner volume and
// competition when pulled, urgency for seasonal (Ramadan) deadlines, and a small
// boost when a translation of the same article already exists.
// Usage: node seo/scripts/pick-next.mjs [--lang ur] [--today 2026-11-01] [--top 5]

import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { readKeywords, writeKeywords } = require('./keywords.cjs');
const siteRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

const DAY = 86400000;

export function score(k, { today, publishedKeys }) {
  let s = Number(k.priority || 0) * 10;
  const volume = Number(k.volume);
  if (k.volume !== '' && !Number.isNaN(volume)) s += Math.log10(volume + 1) * 8;
  s += { LOW: 6, MEDIUM: 2, HIGH: -4 }[k.competition] ?? 0;
  if (k.deadline) {
    const days = (Date.parse(k.deadline) - Date.parse(today)) / DAY;
    if (days <= 0) s += 30;
    else if (days < 45) s += (45 - days) / 1.5;
  }
  if (k.translation_key && publishedKeys.has(k.translation_key)) s += 5;
  return Math.round(s * 10) / 10;
}

// Marks keywords drafted/published when content/<lang>/<slug>.md exists.
export function syncStatus(keywords) {
  for (const k of keywords) {
    const file = path.join(siteRoot, 'content', k.lang, `${k.slug}.md`);
    if (!k.slug || !fs.existsSync(file)) continue;
    const fm = fs.readFileSync(file, 'utf8').match(/^status:\s*(\w+)/m);
    const date = fs.readFileSync(file, 'utf8').match(/^date:\s*(\S+)/m);
    k.status = fm && fm[1] === 'published' ? 'published' : 'drafted';
    if (k.status === 'published' && date) k.published = date[1];
  }
}

function main(argv) {
  const arg = (name, def) => {
    const i = argv.indexOf(`--${name}`);
    return i >= 0 ? argv[i + 1] : def;
  };
  const today = arg('today', new Date().toISOString().slice(0, 10));
  const lang = arg('lang');
  const top = Number(arg('top', 5));

  const keywords = readKeywords();
  syncStatus(keywords);
  writeKeywords(keywords);

  const publishedKeys = new Set(keywords.filter((k) => k.status !== 'todo' && k.translation_key).map((k) => k.translation_key));
  const ranked = keywords
    .filter((k) => k.status === 'todo' && (!lang || k.lang === lang))
    .map((k) => ({ ...k, score: score(k, { today, publishedKeys }) }))
    .sort((a, b) => b.score - a.score);

  const show = (list) =>
    list.slice(0, top).forEach((k) =>
      console.log(`${String(k.score).padStart(5)}  ${k.lang}  ${k.keyword}  -> content/${k.lang}/${k.slug}.md${k.deadline ? `  (by ${k.deadline})` : ''}${k.volume ? `  vol ${k.volume} ${k.competition}` : ''}`),
    );
  if (!ranked.length) return console.log('No todo keywords left. Pull new ideas with seo/gum/pull-keyword-metrics.sh.');
  console.log(`Next article (${today}):`);
  show(ranked.slice(0, 1));
  if (!lang) {
    for (const l of [...new Set(keywords.map((k) => k.lang))]) {
      console.log(`\nTop ${l}:`);
      show(ranked.filter((k) => k.lang === l));
    }
  } else {
    console.log('\nThen:');
    show(ranked.slice(1));
  }
  const missingVolume = keywords.filter((k) => k.volume === '').length;
  if (missingVolume) console.log(`\n${missingVolume} keywords have no volume yet; scores use manual priority only until seo/gum/pull-keyword-metrics.sh runs.`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main(process.argv.slice(2));
