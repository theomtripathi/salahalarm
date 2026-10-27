import test from 'node:test';
import assert from 'node:assert/strict';
import { render, parseFrontmatter } from '../scripts/lib/markdown.mjs';
import { loadArticles, ctaUrl } from '../scripts/build.mjs';
import { score } from '../seo/scripts/pick-next.mjs';
import { aggregate, opportunities } from '../seo/scripts/rank-report.mjs';
import { findResults, metricsOf } from '../seo/scripts/import-keyword-metrics.mjs';
import { findRows } from '../seo/scripts/gsc.mjs';

test('every article passes validation, drafts included', () => {
  const { articles, problems } = loadArticles({ drafts: true });
  assert.deepEqual(problems, []);
  assert.ok(articles.length >= 6);
});

test('markdown renders headings, lists, emphasis and links', () => {
  const { html, headings } = render('## Hello world\n\n- **a**\n- *b*\n\n1. one\n\nSee [x](https://example.com).');
  assert.match(html, /<h2 id="hello-world">Hello world<\/h2>/);
  assert.match(html, /<ul><li><strong>a<\/strong><\/li><li><em>b<\/em><\/li><\/ul>/);
  assert.match(html, /<ol><li>one<\/li><\/ol>/);
  assert.match(html, /<a href="https:\/\/example.com" rel="noopener" target="_blank">x<\/a>/);
  assert.deepEqual(headings, [{ id: 'hello-world', text: 'Hello world' }]);
});

test('frontmatter parses faq entries', () => {
  const { data } = parseFrontmatter('---\ntitle: T: x\nfaq:\n  - q: Why? | a: Because.\n---\nbody');
  assert.equal(data.title, 'T: x');
  assert.deepEqual(data.faq, [{ q: 'Why?', a: 'Because.' }]);
});

test('cta links go through the tracked redirect', () => {
  assert.equal(ctaUrl('ur', 'namaz-ka-alarm'), 'https://salahalarm.com/go/seo-ur?from=namaz-ka-alarm');
});

test('score favours near deadlines, volume and low competition', () => {
  const base = { priority: '4', volume: '', competition: '', deadline: '', translation_key: '' };
  const ctx = { today: '2026-11-20', publishedKeys: new Set() };
  assert.equal(score(base, ctx), 40);
  assert.ok(score({ ...base, deadline: '2026-12-01' }, ctx) > 40);
  assert.ok(score({ ...base, volume: '1000', competition: 'LOW' }, ctx) > score({ ...base, volume: '1000', competition: 'HIGH' }, ctx));
});

test('keyword planner output is found inside a gum envelope', () => {
  const body = { data: { results: [{ text: 'fajr alarm', keywordMetrics: { avgMonthlySearches: '880', competition: 'LOW', highTopOfPageBidMicros: '1250000' } }] } };
  const [r] = findResults(body);
  assert.deepEqual(metricsOf(r), { text: 'fajr alarm', volume: '880', competition: 'LOW', cpc_high: '1.25' });
});

test('search console rows aggregate per article', () => {
  const rows = findRows({ data: { rows: [
    { keys: ['fajr alarm', 'https://salahalarm.com/blog/en/fajr-alarm-app/'], clicks: 2, impressions: 100, position: 12 },
    { keys: ['fajr alarm app', 'https://salahalarm.com/blog/en/fajr-alarm-app/'], clicks: 1, impressions: 50, position: 6 },
  ] } });
  const p = aggregate(rows).get('en/fajr-alarm-app');
  assert.equal(p.impressions, 150);
  assert.equal(p.position, 10);
  assert.equal(opportunities(rows).length, 1);
});

test('worker sends www and http to https://salahalarm.com and serves the rest', async () => {
  const { default: worker } = await import('../src/worker.js');
  const env = { ASSETS: { fetch: () => new Response('asset') } };
  const www = await worker.fetch(new Request('https://www.salahalarm.com/blog/en/?a=1'), env);
  assert.equal(www.status, 301);
  assert.equal(www.headers.get('location'), 'https://salahalarm.com/blog/en/?a=1');
  const http = await worker.fetch(new Request('http://salahalarm.com/'), env);
  assert.equal(http.headers.get('location'), 'https://salahalarm.com/');
  const ok = await worker.fetch(new Request('https://salahalarm.com/blog/en/'), env);
  assert.equal(await ok.text(), 'asset');
});
