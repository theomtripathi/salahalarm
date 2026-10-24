#!/usr/bin/env node
// Builds the static salahalarm.com site into dist/: home page, blog indexes per
// language, one page per article, sitemap.xml with hreflang alternates, robots.txt.
// Usage: node scripts/build.mjs [--drafts]

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { render, parseFrontmatter, escapeHtml as esc } from './lib/markdown.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'site.config.json'), 'utf8'));
const includeDrafts = process.argv.includes('--drafts');
const dist = path.join(root, 'dist');

export function ctaUrl(lang, slug) {
  return config.ctaLinkPattern.replace('{lang}', lang).replace('{slug}', encodeURIComponent(slug));
}

export function loadArticles({ drafts = includeDrafts } = {}) {
  const articles = [];
  const problems = [];
  for (const lang of Object.keys(config.langs)) {
    const dir = path.join(root, 'content', lang);
    if (!fs.existsSync(dir)) continue;
    for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.md')).sort()) {
      const src = fs.readFileSync(path.join(dir, file), 'utf8');
      const { data, body } = parseFrontmatter(src);
      const slug = file.replace(/\.md$/, '');
      const a = { ...data, lang, slug, body, file: `content/${lang}/${file}` };
      a.url = `/blog/${lang}/${slug}/`;
      a.faq = a.faq || [];
      problems.push(...validate(a));
      if (a.status === 'draft' && !drafts) continue;
      articles.push(a);
    }
  }
  return { articles, problems };
}

export function validate(a) {
  const out = [];
  const where = a.file;
  for (const key of ['title', 'description', 'keyword', 'date', 'status']) {
    if (!a[key]) out.push(`${where}: missing ${key}`);
  }
  if (!/^[a-z0-9-]+$/.test(a.slug)) out.push(`${where}: slug must be lowercase ascii with hyphens`);
  if (a.title && a.title.length > 70) out.push(`${where}: title is ${a.title.length} chars (max 70)`);
  if (a.description && (a.description.length < 70 || a.description.length > 165))
    out.push(`${where}: description is ${a.description.length} chars (want 70-165)`);
  if (a.keyword && a.title && !a.title.toLowerCase().includes(a.keyword.toLowerCase().split(' ')[0]))
    out.push(`${where}: title does not contain the start of the keyword "${a.keyword}"`);
  if (a.status && !['draft', 'published'].includes(a.status)) out.push(`${where}: status must be draft or published`);
  const words = a.body.split(/\s+/).filter(Boolean).length;
  if (words < 600) out.push(`${where}: only ${words} words (min 600)`);
  return out;
}

const STRINGS = (lang) => config.langs[lang];

function ctaBlock(lang, slug) {
  const s = STRINGS(lang);
  return `<aside class="cta">
  <img src="/icon.png" alt="" width="64" height="64">
  <div>
    <p class="cta-title">${esc(s.ctaTitle)}</p>
    <p>${esc(s.ctaBody)}</p>
    <a class="button" href="${esc(ctaUrl(lang, slug))}" data-cta="${lang}-${slug}">${esc(s.ctaButton)}</a>
  </div>
</aside>`;
}

function layout({ lang, title, description, canonical, alternates = [], body, jsonLd = [] }) {
  const s = STRINGS(lang);
  const alt = alternates
    .map((x) => `<link rel="alternate" hreflang="${x.lang}" href="${config.baseUrl}${x.url}">`)
    .join('\n');
  const ld = jsonLd.map((o) => `<script type="application/ld+json">${JSON.stringify(o)}</script>`).join('\n');
  return `<!doctype html>
<html lang="${lang}" dir="${s.dir}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
<link rel="canonical" href="${config.baseUrl}${canonical}">
${alt}
<meta name="apple-itunes-app" content="app-id=${config.appStoreId}">
<meta property="og:type" content="article">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${config.baseUrl}${canonical}">
<meta property="og:image" content="${config.baseUrl}/icon.png">
<link rel="icon" href="/icon.png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="stylesheet" href="/styles.css">
${ld}
</head>
<body>
<header class="site">
  <a class="brand" href="/"><img src="/icon.png" alt="" width="32" height="32">${esc(config.appName)}</a>
  <nav><a href="/blog/${lang}/">${esc(s.allArticles)}</a></nav>
</header>
<main>
${body}
</main>
<footer class="site">
  <nav class="langs">${Object.entries(config.langs)
    .map(([code, l]) => `<a href="/blog/${code}/" lang="${code}">${esc(l.name)}</a>`)
    .join(' ')}</nav>
  <p>© ${new Date().getFullYear()} ${esc(config.appName)}</p>
</footer>
</body>
</html>
`;
}

function articlePage(a, siblings) {
  const s = STRINGS(a.lang);
  const { html, headings } = render(a.body);
  // One CTA before the second section, one at the end.
  const parts = html.split(/(?=<h2 )/);
  if (parts.length > 2) parts.splice(2, 0, ctaBlock(a.lang, a.slug));
  const content = parts.join('\n') + '\n' + ctaBlock(a.lang, a.slug);
  const faqHtml = a.faq.length
    ? `<section class="faq"><h2 id="faq">${esc(s.faq)}</h2>${a.faq
        .map((f) => `<details><summary>${esc(f.q)}</summary><p>${esc(f.a)}</p></details>`)
        .join('')}</section>`
    : '';
  const toc = headings.length > 2
    ? `<details class="toc"><summary>${esc(s.contents)}</summary><ul>${headings
        .map((h) => `<li><a href="#${h.id}">${esc(h.text.replace(/^\d+\.\s*/, ''))}</a></li>`)
        .join('')}</ul></details>`
    : '';
  const updated = a.updated || a.date;
  const jsonLd = [
    {
      '@context': 'https://schema.org',
      '@type': 'Article',
      headline: a.title,
      description: a.description,
      inLanguage: a.lang,
      datePublished: a.date,
      dateModified: updated,
      mainEntityOfPage: `${config.baseUrl}${a.url}`,
      image: `${config.baseUrl}/icon.png`,
      author: { '@type': 'Organization', name: config.appName, url: config.baseUrl },
      publisher: { '@type': 'Organization', name: config.appName, logo: { '@type': 'ImageObject', url: `${config.baseUrl}/icon.png` } },
    },
    {
      '@context': 'https://schema.org',
      '@type': 'MobileApplication',
      name: config.appName,
      operatingSystem: 'iOS',
      applicationCategory: 'LifestyleApplication',
      downloadUrl: config.appStoreUrl,
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
    },
  ];
  if (a.faq.length) {
    jsonLd.push({
      '@context': 'https://schema.org',
      '@type': 'FAQPage',
      mainEntity: a.faq.map((f) => ({ '@type': 'Question', name: f.q, acceptedAnswer: { '@type': 'Answer', text: f.a } })),
    });
  }
  const alternates = siblings.map((x) => ({ lang: x.lang, url: x.url }));
  if (alternates.length > 1) {
    const def = siblings.find((x) => x.lang === config.defaultLang) || siblings[0];
    alternates.push({ lang: 'x-default', url: def.url });
  }
  const body = `<article>
<p class="crumbs"><a href="/">${esc(s.home)}</a> › <a href="/blog/${a.lang}/">${esc(s.blogTitle)}</a></p>
<h1>${esc(a.title)}</h1>
<p class="meta">${esc(s.updated)}: <time datetime="${updated}">${updated}</time></p>
${toc}
${content}
${faqHtml}
</article>`;
  return layout({ lang: a.lang, title: a.title, description: a.description, canonical: a.url, alternates, body, jsonLd });
}

function listItems(list) {
  return `<ul class="list">${list
    .map((a) => `<li lang="${a.lang}" dir="${STRINGS(a.lang).dir}"><a href="${a.url}">${esc(a.title)}</a><p>${esc(a.description)}</p></li>`)
    .join('')}</ul>`;
}

function blogIndex(lang, list) {
  const s = STRINGS(lang);
  const body = `<h1>${esc(s.blogTitle)}</h1><p class="lead">${esc(s.blogIntro)}</p>${listItems(list)}${ctaBlock(lang, 'blog-index')}`;
  return layout({ lang, title: s.blogTitle, description: s.blogIntro, canonical: `/blog/${lang}/`, body });
}

function homePage(latest) {
  const s = STRINGS('en');
  const body = `<section class="hero">
  <img src="/icon.png" alt="${esc(config.appName)} app icon" width="96" height="96">
  <h1>Salah Alarm: the Fajr alarm that gets you to the prayer mat</h1>
  <p class="lead">Accurate prayer times for your city, an adhan alarm that only stops at your prayer mat, Qibla, Quran, duas and widgets. Built for Muslims who keep missing Fajr.</p>
  <a class="button" href="${esc(ctaUrl('en', 'home'))}">${esc(s.ctaButton)}</a>
</section>
<h2>Latest guides</h2>
${listItems(latest)}`;
  return layout({
    lang: 'en',
    title: 'Salah Alarm: Fajr Alarm & Prayer Times App for iPhone',
    description: 'Salah Alarm wakes you for Fajr at the exact prayer time and only stops at your prayer mat. Prayer times, Qibla, Quran and duas for iPhone.',
    canonical: '/',
    body,
    jsonLd: [{ '@context': 'https://schema.org', '@type': 'MobileApplication', name: config.appName, operatingSystem: 'iOS', applicationCategory: 'LifestyleApplication', downloadUrl: config.appStoreUrl }],
  });
}

function sitemap(articles, byKey) {
  const urls = [
    { loc: '/', lastmod: null, alts: [] },
    ...Object.keys(config.langs).map((l) => ({ loc: `/blog/${l}/`, lastmod: null, alts: [] })),
    ...articles.map((a) => ({ loc: a.url, lastmod: a.updated || a.date, alts: a.translationKey ? byKey[a.translationKey] : [] })),
  ];
  const body = urls
    .map((u) => {
      const alts = u.alts.length > 1
        ? u.alts.map((x) => `<xhtml:link rel="alternate" hreflang="${x.lang}" href="${config.baseUrl}${x.url}"/>`).join('')
        : '';
      return `<url><loc>${config.baseUrl}${u.loc}</loc>${u.lastmod ? `<lastmod>${u.lastmod}</lastmod>` : ''}${alts}</url>`;
    })
    .join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
${body}
</urlset>
`;
}

function write(rel, content) {
  const file = path.join(dist, rel);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
}

export function build() {
  const { articles, problems } = loadArticles();
  if (problems.length) {
    console.error(problems.join('\n'));
    process.exitCode = 1;
    return;
  }
  fs.rmSync(dist, { recursive: true, force: true });
  fs.cpSync(path.join(root, 'static'), dist, { recursive: true });

  const byKey = {};
  for (const a of articles) if (a.translationKey) (byKey[a.translationKey] ||= []).push(a);
  const newestFirst = [...articles].sort((x, y) => (y.date > x.date ? 1 : y.date < x.date ? -1 : 0));

  for (const a of articles) write(path.join(a.url, 'index.html'), articlePage(a, a.translationKey ? byKey[a.translationKey] : [a]));
  for (const lang of Object.keys(config.langs)) write(`blog/${lang}/index.html`, blogIndex(lang, newestFirst.filter((a) => a.lang === lang)));
  write('blog/index.html', `<!doctype html><meta http-equiv="refresh" content="0; url=/blog/en/"><link rel="canonical" href="${config.baseUrl}/blog/en/">`);
  write('index.html', homePage(newestFirst.slice(0, 12)));
  write('sitemap.xml', sitemap(articles, byKey));
  write('robots.txt', `User-agent: *\nAllow: /\nDisallow: /go/\n\nSitemap: ${config.baseUrl}/sitemap.xml\n`);
  console.log(`built ${articles.length} articles into dist/${includeDrafts ? ' (including drafts)' : ''}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) build();
