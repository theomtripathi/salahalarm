import { esc } from '../util.js';

const NAV = [
  ['/content', 'Content'],
  ['/resources', 'Resources'],
  ['/faq', 'FAQ'],
  ['/terms', 'Payouts'],
];

export function page({ title, description = '', body, user = null, admin = false, active = '', wide = false }) {
  const nav = admin
    ? `<a href="/admin"${active === 'admin' ? ' aria-current="page"' : ''}>Overview</a><a href="/admin/review"${active === 'review' ? ' aria-current="page"' : ''}>Review</a><a href="/admin/payouts"${active === 'payouts' ? ' aria-current="page"' : ''}>Payouts</a><a href="/admin/settings"${active === 'settings' ? ' aria-current="page"' : ''}>Settings</a>`
    : NAV.map(([href, label]) => `<a href="${href}"${active === href ? ' aria-current="page"' : ''}>${label}</a>`).join('');
  const right = admin
    ? '<form method="post" action="/admin/logout"><button class="link-btn">Log out</button></form>'
    : user
      ? `<a class="btn btn-small" href="/dashboard">Dashboard</a>`
      : `<a class="nav-login" href="/login">Log in</a><a class="btn btn-small" href="/#join">Join free</a>`;
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
${description ? `<meta name="description" content="${esc(description)}">` : ''}
<meta name="robots" content="${admin ? 'noindex, nofollow' : 'index, follow'}">
<meta property="og:title" content="${esc(title)}">
<meta property="og:image" content="https://salahalarm.com/img/og.png">
<link rel="icon" href="/img/icon.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/styles.css?v=4">
</head>
<body${admin ? ' class="admin"' : ''}>
<header class="top">
  <div class="top-in${wide ? ' wide' : ''}">
    <a class="brand" href="${admin ? '/admin' : '/'}"><img src="/img/icon.png" alt="" width="30" height="30"><span>Salah Alarm <b>Affiliates</b></span></a>
    <nav class="nav">${nav}</nav>
    <div class="top-right">${right}</div>
  </div>
</header>
<main class="${wide ? 'wrap wide' : 'wrap'}">
${body}
</main>
<footer class="foot">
  <div class="wrap">
    <p><b>Salah Alarm Affiliates</b> · <a href="https://salahalarm.com">salahalarm.com</a> · <a href="https://www.instagram.com/salah_alarm/">@salah_alarm</a> · <a href="https://discord.gg/yZ2D3N5u3w">Discord</a> · <a href="/faq">FAQ</a> · <a href="/terms">Payout terms</a></p>
  </div>
</footer>
<script src="/app.js?v=3" defer></script>
</body>
</html>`;
}

export const flash = (msg, kind = 'ok') => (msg ? `<div class="flash flash-${kind}" role="status">${esc(msg)}</div>` : '');
