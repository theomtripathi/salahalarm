#!/usr/bin/env node
// Merges gum Keyword Planner output into seo/data/keywords.csv.
//   *-historical.json -> volume / competition / cpc_high on matching keywords
//   *-ideas.json      -> new keyword ideas appended to seo/data/ideas.csv
// Usage: node seo/scripts/import-keyword-metrics.mjs seo/data/metrics/2026-10-24-*.json

import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { readKeywords, writeKeywords, parseCsv } = require('./keywords.cjs');

// gum may wrap the API body in an envelope; find the first `results` array.
export function findResults(node) {
  if (!node || typeof node !== 'object') return null;
  if (Array.isArray(node.results)) return node.results;
  for (const v of Object.values(node)) {
    const r = findResults(v);
    if (r) return r;
  }
  return null;
}

export function metricsOf(result) {
  const m = result.keywordMetrics || result.keywordIdeaMetrics || {};
  const micros = m.highTopOfPageBidMicros;
  return {
    text: (result.text || '').trim(),
    volume: m.avgMonthlySearches ?? '',
    competition: (m.competition || '').replace(/^UNSPECIFIED$|^UNKNOWN$/, ''),
    cpc_high: micros ? (Number(micros) / 1e6).toFixed(2) : '',
  };
}

const norm = (s) => s.toLowerCase().normalize('NFKC').replace(/\s+/g, ' ').trim();

function main(files) {
  const keywords = readKeywords();
  const byText = new Map(keywords.map((k) => [`${k.lang}|${norm(k.keyword)}`, k]));
  const ideasFile = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'data', 'ideas.csv');
  const ideas = new Map();
  if (fs.existsSync(ideasFile)) {
    const [, ...rows] = parseCsv(fs.readFileSync(ideasFile, 'utf8'));
    for (const r of rows) ideas.set(`${r[0]}|${norm(r[1])}`, r);
  }
  let updated = 0;
  let added = 0;
  for (const file of files) {
    const base = path.basename(file);
    const m = base.match(/^(\d{4}-\d{2}-\d{2})-([a-z]{2})-(historical|ideas)\.json$/);
    if (!m) {
      console.warn(`skipping ${base}: expected <date>-<lang>-historical|ideas.json`);
      continue;
    }
    const [, date, lang, kind] = m;
    const results = findResults(JSON.parse(fs.readFileSync(file, 'utf8'))) || [];
    for (const r of results) {
      const x = metricsOf(r);
      const key = `${lang}|${norm(x.text)}`;
      const row = byText.get(key);
      if (row) {
        Object.assign(row, { volume: x.volume, competition: x.competition, cpc_high: x.cpc_high, metrics_date: date });
        updated++;
      } else if (kind === 'ideas' && !ideas.has(key)) {
        ideas.set(key, [lang, x.text, x.volume, x.competition, x.cpc_high, date]);
        added++;
      }
    }
  }
  writeKeywords(keywords);
  const sorted = [...ideas.values()].sort((a, b) => Number(b[2] || 0) - Number(a[2] || 0));
  const lines = ['lang,keyword,volume,competition,cpc_high,metrics_date', ...sorted.map((r) => r.map((v) => (/[",]/.test(v) ? `"${String(v).replace(/"/g, '""')}"` : v)).join(','))];
  fs.writeFileSync(ideasFile, lines.join('\n') + '\n');
  console.log(`updated ${updated} keywords, added ${added} new ideas to seo/data/ideas.csv`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main(process.argv.slice(2));
