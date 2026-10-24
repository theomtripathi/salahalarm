#!/usr/bin/env node
// Turns a Search Console export (gum searchanalytics.query, dimensions query+page)
// into a ranking report, and writes position/clicks/impressions per article
// back into seo/data/keywords.csv.
// Usage: node seo/scripts/rank-report.mjs seo/data/gsc/2026-11-20.json

import fs from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { findRows } from './gsc.mjs';

const require = createRequire(import.meta.url);
const { readKeywords, writeKeywords } = require('./keywords.cjs');

export function aggregate(rows) {
  const pages = new Map();
  for (const r of rows) {
    const [query, page] = r.keys;
    const m = page.match(/\/blog\/([a-z]{2})\/([a-z0-9-]+)\/?$/);
    if (!m) continue;
    const key = `${m[1]}/${m[2]}`;
    const p = pages.get(key) || { lang: m[1], slug: m[2], clicks: 0, impressions: 0, posSum: 0, queries: [] };
    p.clicks += r.clicks || 0;
    p.impressions += r.impressions || 0;
    p.posSum += (r.position || 0) * (r.impressions || 0);
    p.queries.push({ query, clicks: r.clicks || 0, impressions: r.impressions || 0, position: r.position || 0 });
    pages.set(key, p);
  }
  for (const p of pages.values()) {
    p.position = p.impressions ? Math.round((p.posSum / p.impressions) * 10) / 10 : null;
    p.queries.sort((a, b) => b.impressions - a.impressions);
  }
  return pages;
}

// Queries ranking 8-30 with real impressions: a refresh or a dedicated article
// is most likely to move these onto page one.
export function opportunities(rows, minImpressions = 20) {
  return rows
    .filter((r) => r.position >= 8 && r.position <= 30 && r.impressions >= minImpressions)
    .sort((a, b) => b.impressions - a.impressions)
    .map((r) => ({ query: r.keys[0], page: r.keys[1], impressions: r.impressions, position: Math.round(r.position * 10) / 10 }));
}

function main(file) {
  const rows = findRows(JSON.parse(fs.readFileSync(file, 'utf8')));
  const pages = aggregate(rows);
  const keywords = readKeywords();
  for (const k of keywords) {
    const p = pages.get(`${k.lang}/${k.slug}`);
    if (!p) continue;
    k.gsc_position = p.position ?? '';
    k.gsc_clicks = p.clicks;
    k.gsc_impressions = p.impressions;
  }
  writeKeywords(keywords);

  console.log('Articles by impressions (28 days):');
  [...pages.values()]
    .sort((a, b) => b.impressions - a.impressions)
    .forEach((p) => console.log(`  ${p.lang}/${p.slug}  pos ${p.position}  ${p.impressions} impr  ${p.clicks} clicks  top query: ${p.queries[0]?.query ?? '-'}`));
  const opp = opportunities(rows);
  if (opp.length) {
    console.log('\nPage-two opportunities (refresh these or write a dedicated article):');
    opp.slice(0, 20).forEach((o) => console.log(`  "${o.query}"  pos ${o.position}  ${o.impressions} impr  ${o.page}`));
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main(process.argv[2]);
