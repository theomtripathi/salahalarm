// Zero-dependency SEO audit of the built site in dist/.
// Reports duplicate titles and descriptions, missing canonical or description tags,
// pages in the sitemap with no internal links pointing at them (orphans), and
// blog pages missing from the sitemap. Run after `npm run build`.
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative } from 'node:path';

const dist = new URL('../../dist/', import.meta.url).pathname;

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (name === 'index.html') out.push(p);
  }
  return out;
}

const pages = new Map(); // url path -> { title, description, canonical, html }
for (const file of walk(dist)) {
  const rel = relative(dist, file).replace(/index\.html$/, '');
  const urlPath = '/' + rel;
  const html = readFileSync(file, 'utf8');
  const title = (html.match(/<title>([^<]*)<\/title>/) || [])[1] || '';
  const description = (html.match(/<meta name="description" content="([^"]*)"/) || [])[1] || '';
  const canonical = (html.match(/<link rel="canonical" href="([^"]*)"/) || [])[1] || '';
  pages.set(urlPath, { title, description, canonical, html });
}

const problems = [];
const byTitle = new Map();
const byDesc = new Map();
for (const [path, p] of pages) {
  if (path === '/404.html' || path === '/blog/') continue; // /blog/ is a redirect stub
  if (!p.title) problems.push(`missing <title>: ${path}`);
  if (!p.description) problems.push(`missing meta description: ${path}`);
  if (!p.canonical) problems.push(`missing canonical: ${path}`);
  // Blog index pages share the brand title across languages on purpose.
  if (p.title && !/^\/blog\/[a-z]{2}\/$/.test(path)) byTitle.set(p.title, [...(byTitle.get(p.title) || []), path]);
  if (p.description) byDesc.set(p.description, [...(byDesc.get(p.description) || []), path]);
}
for (const [t, paths] of byTitle) if (paths.length > 1) problems.push(`duplicate title "${t}": ${paths.join(', ')}`);
for (const [d, paths] of byDesc) if (paths.length > 1) problems.push(`duplicate description: ${paths.join(', ')}`);

// Internal links: which pages are linked from some other page.
const sitemap = existsSync(join(dist, 'sitemap.xml')) ? readFileSync(join(dist, 'sitemap.xml'), 'utf8') : '';
const inSitemap = new Set([...sitemap.matchAll(/<loc>https:\/\/salahalarm\.com([^<]*)<\/loc>/g)].map((m) => m[1]));
const linked = new Set();
for (const [path, p] of pages) {
  for (const m of p.html.matchAll(/href="(\/[^"#?]*)/g)) {
    if (m[1] !== path) linked.add(m[1].endsWith('/') ? m[1] : m[1] + '/');
  }
}
for (const url of inSitemap) {
  if (!pages.has(url) && !pages.has(url.replace(/\/?$/, '/'))) problems.push(`sitemap lists a page not in dist: ${url}`);
  const norm = url.endsWith('/') ? url : url + '/';
  if (!linked.has(norm) && norm !== '/') problems.push(`orphan (in sitemap, no internal link): ${url}`);
}
for (const path of pages.keys()) {
  if (path.startsWith('/blog/') && path !== '/blog/' && !inSitemap.has(path) && !inSitemap.has(path.replace(/\/$/, ''))) {
    problems.push(`blog page missing from sitemap: ${path}`);
  }
}

console.log(`pages checked: ${pages.size}`);
console.log(problems.length ? problems.join('\n') : 'no problems found');
console.log(`problems: ${problems.length}`);
