#!/usr/bin/env node
// Builds the static salahalarm.com site into dist/: home page, blog indexes per
// language, one page per article, sitemap.xml with hreflang alternates, robots.txt.
// Usage: node scripts/build.mjs [--drafts]

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { render, parseFrontmatter, escapeHtml as esc } from './lib/markdown.mjs';
import { layout, ctaInline, ctaBand, storeBadges, alarmPhone } from './lib/ui.mjs';
import { homePage, card } from './pages/home.mjs';

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
      a.words = body.split(/\s+/).filter(Boolean).length;
      a.minutes = Math.max(1, Math.round(a.words / 220));
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

function formatDate(date, lang) {
  try {
    return new Intl.DateTimeFormat(lang, { year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC' }).format(new Date(date));
  } catch {
    return date;
  }
}

function articlePage(a, siblings, related) {
  const s = STRINGS(a.lang);
  const { html, headings } = render(a.body);
  // One CTA before the second section.
  const parts = html.split(/(?=<h2 )/);
  if (parts.length > 2) parts.splice(2, 0, ctaInline(config, a.lang, a.slug));
  const content = parts.join('\n');
  const faqHtml = a.faq.length
    ? `<section class="article-faq"><h2 id="faq">${esc(s.faq)}</h2><div class="faq">${a.faq
        .map((f) => `<details><summary>${esc(f.q)}</summary><p>${esc(f.a)}</p></details>`)
        .join('')}</div></section>`
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
      image: `${config.baseUrl}/img/og.png`,
      author: { '@type': 'Organization', name: config.appName, url: config.baseUrl },
      publisher: { '@type': 'Organization', name: config.appName, logo: { '@type': 'ImageObject', url: `${config.baseUrl}/icon.png` } },
    },
    {
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      itemListElement: [
        { '@type': 'ListItem', position: 1, name: config.appName, item: `${config.baseUrl}/` },
        { '@type': 'ListItem', position: 2, name: s.blogTitle, item: `${config.baseUrl}/blog/${a.lang}/` },
        { '@type': 'ListItem', position: 3, name: a.title, item: `${config.baseUrl}${a.url}` },
      ],
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
  const translations = siblings.length > 1
    ? `<p class="translations">${siblings.map((x) => x.lang === a.lang ? '' : `<a href="${x.url}" lang="${x.lang}">${esc(STRINGS(x.lang).name)}</a>`).join('')}</p>`
    : '';
  const body = `<header class="article-hero">
  <div class="wrap narrow">
    <p class="crumbs"><a href="/">${esc(config.appName)}</a><span>/</span><a href="/blog/${a.lang}/">${esc(s.blogTitle)}</a></p>
    <h1>${esc(a.title)}</h1>
    <p class="lead">${esc(a.description)}</p>
    <p class="meta"><time datetime="${updated}">${esc(formatDate(updated, a.lang))}</time> · ${esc(s.readingTime.replace('{n}', a.minutes))}</p>
    ${translations}
  </div>
</header>
<div class="wrap article-layout">
  <article class="prose">
    ${toc}
    ${content}
    ${faqHtml}
  </article>
  <aside class="article-aside">
    <div class="aside-card">
      ${alarmPhone('phone-aside')}
      <p class="cta-title">${esc(s.ctaTitle)}</p>
      <p>${esc(s.ctaBody)}</p>
      ${storeBadges(config, a.lang, `${a.slug}-aside`)}
    </div>
  </aside>
</div>
${related.length ? `<section class="section related"><div class="wrap"><h2 class="section-title">${esc(s.related)}</h2><div class="cards">${related.map((r) => card(config, r)).join('')}</div></div></section>` : ''}
${ctaBand(config, a.lang, a.slug)}`;
  return layout(config, { lang: a.lang, title: a.title, description: a.description, canonical: a.url, alternates, body, jsonLd, ogType: 'article', bodyClass: 'article-page' });
}

function blogIndex(lang, list) {
  const s = STRINGS(lang);
  const body = `<header class="article-hero blog-hero">
  <div class="wrap">
    <h1>${esc(s.blogTitle)}</h1>
    <p class="lead">${esc(s.blogIntro)}</p>
    <nav class="lang-chips" aria-label="Languages">${Object.entries(config.langs)
      .map(([code, l]) => `<a class="chip${code === lang ? ' active' : ''}" href="/blog/${code}/" lang="${code}">${esc(l.name)}</a>`)
      .join('')}</nav>
  </div>
</header>
<section class="section">
  <div class="wrap"><div class="cards">${list.map((a) => card(config, a)).join('')}</div></div>
</section>
${ctaBand(config, lang, 'blog-index')}`;
  return layout(config, { lang, title: `${s.blogTitle} | ${config.appName}`, description: s.blogIntro, canonical: `/blog/${lang}/`, body, bodyClass: 'blog-page' });
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

  for (const a of articles) {
    const related = newestFirst.filter((r) => r.lang === a.lang && r.slug !== a.slug).slice(0, 3);
    write(path.join(a.url, 'index.html'), articlePage(a, a.translationKey ? byKey[a.translationKey] : [a], related));
  }
  for (const lang of Object.keys(config.langs)) write(`blog/${lang}/index.html`, blogIndex(lang, newestFirst.filter((a) => a.lang === lang)));
  write('blog/index.html', `<!doctype html><meta http-equiv="refresh" content="0; url=/blog/en/"><link rel="canonical" href="${config.baseUrl}/blog/en/">`);
  write('index.html', homePage(config, newestFirst.filter((a) => a.lang === 'en').slice(0, 3)));
  write('404.html', layout(config, {
    lang: 'en',
    title: 'Page not found | Salah Alarm',
    description: 'This page does not exist. Find guides on waking up for Fajr and prayer times, or download Salah Alarm.',
    canonical: '/404.html',
    body: `<header class="article-hero"><div class="wrap narrow"><h1>Page not found</h1><p class="lead">This page has moved or never existed.</p><p><a class="btn" href="/">Go to the home page</a></p></div></header>`,
  }));
  write('sitemap.xml', sitemap(articles, byKey));
  write('robots.txt', `User-agent: *\nAllow: /\nDisallow: /go/\n\nSitemap: ${config.baseUrl}/sitemap.xml\n`);
  console.log(`built ${articles.length} articles into dist/${includeDrafts ? ' (including drafts)' : ''}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) build();
