// Shared page chrome and components: layout, header, footer, App Store badge,
// phone frame, icons and the article CTA blocks.

import { escapeHtml as esc } from './markdown.mjs';

const ICON_PATHS = {
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  bell: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
  lock: '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
  flame: '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.29 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>',
  book: '<path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20"/>',
  compass: '<circle cx="12" cy="12" r="9"/><path d="m16.2 7.8-2.1 6.3-6.3 2.1 2.1-6.3z"/>',
  sparkle: '<path d="M12 3l1.9 5.8L20 11l-6.1 2.2L12 19l-1.9-5.8L4 11l6.1-2.2z"/>',
  globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
  scan: '<path d="M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2"/><path d="M7 12h10"/>',
  moon: '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>',
  check: '<path d="M20 6 9 17l-5-5"/>',
  x: '<path d="M18 6 6 18M6 6l12 12"/>',
  arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
  star: '<path d="m12 2 3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z"/>',
};

export function icon(name, cls = 'icon') {
  return `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICON_PATHS[name]}</svg>`;
}

const APPLE = '<svg viewBox="0 0 24 24" aria-hidden="true" fill="currentColor"><path d="M16.37 12.6c-.02-2.3 1.88-3.4 1.96-3.46-1.07-1.56-2.73-1.78-3.32-1.8-1.41-.14-2.76.83-3.47.83-.72 0-1.82-.81-3-.79-1.54.02-2.96.9-3.76 2.27-1.6 2.78-.41 6.9 1.15 9.16.77 1.1 1.68 2.34 2.87 2.3 1.15-.05 1.59-.75 2.98-.75 1.39 0 1.78.75 3 .72 1.24-.02 2.02-1.12 2.77-2.23.88-1.28 1.24-2.52 1.26-2.59-.03-.01-2.42-.93-2.44-3.66zM14.1 5.86c.63-.77 1.06-1.83.94-2.89-.91.04-2.02.61-2.67 1.37-.58.67-1.1 1.76-.96 2.8 1.02.08 2.06-.52 2.69-1.28z"/></svg>';

export function appStoreBadge(s, href, cta, cls = '') {
  return `<a class="store-badge ${cls}" href="${esc(href)}" data-cta="${esc(cta)}">${APPLE}<span><small>${esc(s.badgeTop)}</small>App Store</span></a>`;
}

const ANDROID = '<svg viewBox="0 0 24 24" aria-hidden="true" fill="currentColor"><path d="M17.6 9.48 19.44 6.3a.38.38 0 0 0-.66-.38l-1.87 3.23a11.43 11.43 0 0 0-9.82 0L5.22 5.92a.38.38 0 0 0-.66.38L6.4 9.48A10.78 10.78 0 0 0 1 18h22a10.78 10.78 0 0 0-5.4-8.52zM7 15.25a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5zm10 0a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5z"/></svg>';

export function linkFor(config, platform, lang, slug) {
  const pattern = platform === 'android' ? config.androidLinkPattern : config.ctaLinkPattern;
  return pattern.replace('{lang}', lang).replace('{slug}', encodeURIComponent(slug));
}

// The Android + iOS button pair used in every CTA. `from` tells the /go and
// /android funnels which section the click came from.
export function storeButtons(config, lang, slug, cls = '') {
  const s = config.langs[lang];
  const btn = (platform, logo, name) =>
    `<a class="store-badge store-${platform}" rel="nofollow" href="${esc(linkFor(config, platform, lang, slug))}" data-cta="${esc(`${lang}-${slug}-${platform}`)}">${logo}<span><small>${esc(s.getItFor)}</small>${name}</span></a>`;
  return `<div class="store-buttons ${cls}">${btn('android', ANDROID, 'Android')}${btn('ios', APPLE, 'iOS')}</div>`;
}

export function phone(src, alt, cls = '') {
  return `<div class="phone ${cls}"><div class="phone-screen"><img src="${src}" alt="${esc(alt)}" loading="lazy" decoding="async"></div></div>`;
}

// The ringing Fajr alarm, drawn in HTML so it stays sharp and matches the app.
export function alarmPhone(cls = '') {
  return `<div class="phone ${cls}" role="img" aria-label="Salah Alarm ringing at Fajr, 5:14 AM, with a Scan Mat button to dismiss">
  <div class="phone-screen alarm-screen" dir="ltr" aria-hidden="true">
    <div class="alarm-status"><span>9:41</span><span class="alarm-status-icons"></span></div>
    <div class="alarm-name">Fajr</div>
    <div class="alarm-ar" lang="ar" dir="rtl">الفجر</div>
    <div class="alarm-time">5:14 AM</div>
    <div class="alarm-pulse"><span></span><span></span><span></span><i>${icon('bell')}</i></div>
    <div class="alarm-card">
      <div class="alarm-card-title">Scan your prayer mat to dismiss</div>
      <div class="alarm-card-sub">Point your phone at your prayer mat and confirm the scan</div>
      <div class="alarm-card-btn">${icon('scan', 'icon icon-sm')} Scan Mat</div>
    </div>
  </div>
</div>`;
}

const FONTS = {
  latin: 'family=Plus+Jakarta+Sans:wght@400;500;600;700;800',
  ar: 'family=Noto+Naskh+Arabic:wght@400;600;700',
  ur: 'family=Noto+Nastaliq+Urdu:wght@400;600;700',
};

export function layout(config, { lang, title, description, canonical, alternates = [], body, jsonLd = [], ogType = 'website', bodyClass = '' }) {
  const s = config.langs[lang];
  // Arabic script is used on every page (language links, the alarm screen); Google Fonts
  // serves it with unicode-range, so browsers only fetch it where Arabic text appears.
  const fonts = [FONTS.latin, FONTS.ar, FONTS[lang] === FONTS.ar ? null : FONTS[lang]].filter(Boolean).join('&');
  const alt = alternates.map((x) => `<link rel="alternate" hreflang="${x.lang}" href="${config.baseUrl}${x.url}">`).join('\n');
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
<meta name="theme-color" content="#0a3d2a">
<meta property="og:type" content="${ogType}">
<meta property="og:site_name" content="${esc(config.appName)}">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${config.baseUrl}${canonical}">
<meta property="og:image" content="${config.baseUrl}/img/og.png">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="/icon.png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?${fonts}&display=swap">
<link rel="stylesheet" href="/styles.css">
${ld}
</head>
<body class="${bodyClass}">
${header(config, lang)}
<main id="main">
${body}
</main>
${footer(config, lang)}
</body>
</html>
`;
}

function header(config, lang) {
  const s = config.langs[lang];
  const homeNav = lang === 'en'
    ? `<a href="/#how">How it works</a><a href="/#features">Features</a><a href="/#ramadan">Ramadan</a>`
    : '';
  return `<header class="site-header">
  <div class="wrap header-inner">
    <a class="brand" href="/"><img src="/icon.png" alt="" width="34" height="34"><span>${esc(config.appName)}</span></a>
    <nav class="header-nav" aria-label="Main">${homeNav}<a href="/blog/${lang}/">${esc(s.guides)}</a></nav>
    <div class="header-cta">
      <a class="btn btn-small" rel="nofollow" href="${esc(linkFor(config, 'android', lang, 'header'))}" data-cta="${lang}-header-android" aria-label="${esc(s.getItFor)} Android">${ANDROID}<span>Android</span></a>
      <a class="btn btn-small" rel="nofollow" href="${esc(linkFor(config, 'ios', lang, 'header'))}" data-cta="${lang}-header-ios" aria-label="${esc(s.getItFor)} iOS">${APPLE}<span>iOS</span></a>
    </div>
  </div>
</header>`;
}

function footer(config, lang) {
  const year = new Date().getFullYear();
  const langs = Object.entries(config.langs)
    .map(([code, l]) => `<a href="/blog/${code}/" lang="${code}">${esc(l.name)}</a>`)
    .join('');
  return `<footer class="site-footer">
  <div class="wrap footer-grid">
    <div class="footer-brand">
      <a class="brand" href="/"><img src="/icon.png" alt="" width="34" height="34"><span>${esc(config.appName)}</span></a>
      <p>The Fajr alarm that gets you to the prayer mat. Built for Muslims everywhere.</p>
    </div>
    <div><h2>App</h2><a href="/#how">How it works</a><a href="/#features">Features</a><a href="/#ramadan">Ramadan 2027</a><a rel="nofollow" href="${esc(linkFor(config, 'android', lang, 'footer'))}">Android</a><a rel="nofollow" href="${esc(linkFor(config, 'ios', lang, 'footer'))}">iOS</a></div>
    <div><h2>Guides</h2>${langs}</div>
    <div><h2>Legal</h2><a href="${esc(config.privacyUrl)}">Privacy</a><a href="${esc(config.termsUrl)}">Terms</a><a href="${esc(config.supportUrl)}">Support</a></div>
  </div>
  <div class="wrap footer-base"><p>© ${year} ${esc(config.appName)}</p><p>Android · iPhone · English · العربية · Türkçe · Bahasa Indonesia · اردو</p></div>
</footer>`;
}

// Inline CTA used inside articles.
export function ctaInline(config, lang, slug) {
  const s = config.langs[lang];
  return `<aside class="cta-inline">
  <img src="/icon.png" alt="" width="56" height="56">
  <div>
    <p class="cta-title">${esc(s.ctaTitle)}</p>
    <p>${esc(s.ctaBody)}</p>
    ${storeButtons(config, lang, slug, 'buttons-light')}
  </div>
</aside>`;
}

// Dark full-width band closing every page.
export function ctaBand(config, lang, slug) {
  const s = config.langs[lang];
  return `<section class="cta-band">
  <div class="wrap cta-band-inner">
    <div>
      <h2>${esc(s.ctaBandTitle)}</h2>
      <p>${esc(s.ctaBandBody)}</p>
      ${storeButtons(config, lang, `${slug}-band`, 'buttons-light')}
    </div>
    ${alarmPhone('phone-tilt')}
  </div>
</section>`;
}
