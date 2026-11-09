// salahalarm.com/ramadan-2027/ : the Free Makkah Trip Challenge landing page
// (the 90-day #ImRamadanReady prayer challenge with an Umrah prize draw), and
// its official rules at /ramadan-2027/rules/. Comment-to-link replies, bio links
// and invite links (/c/<CODE>) all land here.

import { escapeHtml as esc } from '../lib/markdown.mjs';
import { icon, layout, APPLE, ANDROID } from '../lib/ui.mjs';


const PHASES = [
  ['Fajr foundation', 'Days 1 to 30', '10 Nov to 9 Dec', 'Get Fajr right first: the alarm only stops at your prayer mat.'],
  ['Five a day', 'Days 31 to 60', '10 Dec to 8 Jan', 'All five prayers on time, and a page of Quran if you can.'],
  ['Sha\'ban training', 'Days 61 to 90', '9 Jan to 7 Feb', 'Keep all five, and try the Monday and Thursday sunnah fasts.'],
  ['Ramadan', '30 days', 'From about 8 Feb', 'You arrive already in rhythm. The winner is drawn as Ramadan begins.'],
];

function faqFor(c) {
  return [
    ['Is it really free?', `Yes. Joining, logging your prayers, your invite link and your entries are all free. No purchase is necessary to enter or win, and buying Premium does not improve your chances. You can also enter without the app (see the official rules).`],
    ['How do I enter?', 'Download Salah Alarm, join the challenge, and log all five daily prayers in the app. Every day with all five logged counts. 30 days earns 1 entry, 60 days earns 2 entries and 90 days earns 3 entries.'],
    ['How do invites give me extra entries?', `Tap Invite friends in the app to get your personal link. Every friend who joins with your link or code and logs their first full day gives you 1 extra entry, up to ${c.bonusCap}. Invite entries count once you have logged at least 30 days yourself.`],
    ['I am joining late. Can I still win?', `Yes. Join by 10 Dec for the 60-day track or by ${shortDate(c.joinCloses)} for the 30-day track. Log 30 full days before ${shortDate(c.end)} and you are in the draw.`],
    ['What is the prize?', `A ${c.prizeName}: return flights, a hotel near the Haram and visas, for the winner and one companion (approximate value US$${c.prizeValueUsd.toLocaleString('en-US')}).`],
    ['Who can win?', `Residents of ${c.eligibleCountries} who are 18 or older. Anyone, anywhere can take part in the challenge and earn the free Premium rewards.`],
    ['When is the winner picked?', `By random draw from all entries on ${longDate(c.drawDate)}, as Ramadan begins. The winner is contacted in the app and by email. Odds depend on the number of entries.`],
    ['Is a prize draw allowed in Islam?', 'Nobody pays to enter and nobody loses anything, so it is a gift from the sponsor to one participant, not a bet. Many scholars treat free promotional draws like this as permissible. If you are unsure, ask your local imam.'],
    ['When does Ramadan 2027 start?', 'Ramadan 2027 is expected to begin on or around Monday 8 February 2027. The exact date depends on the moon sighting in your country.'],
  ];
}

function day(date) {
  return Date.parse(`${date}T00:00:00Z`);
}

function daysBetween(from, to) {
  return Math.ceil((to - from) / 86400000);
}

function shortDate(date) {
  return new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', timeZone: 'UTC' }).format(new Date(day(date)));
}

function longDate(date) {
  return new Intl.DateTimeFormat('en-GB', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' }).format(new Date(day(date)));
}

// The challenge screen in the app, drawn in HTML like the alarm phone.
function challengePhone() {
  const prayers = [['Fajr', true], ['Dhuhr', true], ['Asr', true], ['Maghrib', false], ['Isha', false]];
  return `<div class="phone phone-hero challenge-phone" role="img" aria-label="The challenge in Salah Alarm: day 23 of 90, three of five prayers logged today, 2 friends joined">
  <div class="phone-screen challenge-screen" dir="ltr" aria-hidden="true">
    <div class="alarm-status"><span>9:41</span><span class="alarm-status-icons"></span></div>
    <div class="cs-tag">Free Makkah Trip Challenge</div>
    <div class="cs-ring"><svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="44"/><circle class="cs-ring-fill" cx="50" cy="50" r="44" pathLength="90" stroke-dasharray="23 90"/></svg>
      <div class="cs-ring-text"><b>23</b><span>of 90 days</span></div>
    </div>
    <div class="cs-phase">Today · 3 of 5 prayers logged</div>
    <div class="cs-list">${prayers.map(([name, done]) => `<div class="cs-row${done ? ' done' : ''}"><span>${name}</span><i>${done ? icon('check', 'icon') : ''}</i></div>`).join('')}</div>
    <div class="cs-invite">${icon('sparkle', 'icon')} 2 friends joined · +2 entries</div>
  </div>
</div>`;
}

// iPhone + Android pair. Both go through /c/ so clicks are logged; ?to= makes
// each button reach its own store from any device.
function platformButtons(c, where, light) {
  const btn = (platform, href, logo, name) =>
    `<a class="store-badge store-${platform}" rel="nofollow" href="${esc(href)}" data-join="${platform}" data-cta="challenge-${where}-${platform}">${logo}<span><small>Join free on</small>${name}</span></a>`;
  return `<div class="store-buttons ${light ? 'buttons-light' : ''}">${btn('ios', c.iosUrl, APPLE, 'iPhone')}${btn('android', c.androidUrl, ANDROID, 'Android')}</div>`;
}

export function challengePage(config) {
  const c = config.challenge;
  const now = Date.now();
  const toRamadan = Math.max(0, daysBetween(now, day(config.ramadanStart)));
  const toStart = daysBetween(now, day(c.start));
  const statusText = toStart > 0 ? `Day 1 is ${shortDate(c.start)}` : `Day ${Math.min(c.days, 1 - toStart)} of ${c.days}`;
  const faq = faqFor(c);

  const actions = (where, light = true) => `<div class="challenge-cta">
    ${platformButtons(c, where, light)}
    <a class="btn ${light ? 'btn-ghost-light' : 'btn-ghost'}" rel="nofollow" href="${esc(c.inviteUrl)}" data-cta="challenge-${where}-invite">${icon('arrow', 'icon icon-sm')} Get my invite link</a>
  </div>`;

  const body = `
<section class="hero challenge-hero">
  <div class="wrap hero-inner">
    <div class="hero-copy">
      <p class="pill">${icon('compass', 'icon icon-sm')} ${esc(c.name)} · ${esc(c.hashtag)}</p>
      <h1>Win a free <span class="gold">Makkah trip.</span></h1>
      <p class="hero-lead">Log your five daily prayers in Salah Alarm for 30, 60 or 90 days before Ramadan and you're in the draw for an ${esc(c.prizeName)}. Every friend you bring adds an extra entry. Free to join.</p>
      <div class="invite-note" data-invite hidden>
        <p><strong>Your friend invited you.</strong> Join with their code and you both move closer to Makkah.</p>
        <div class="invite-code"><code data-invite-code></code><button type="button" class="btn btn-small btn-ghost-light" data-copy>Copy code</button></div>
        <p class="invite-help">If the app doesn't pick it up, enter it under "Got an invite code?" when you join.</p>
      </div>
      ${actions('hero')}
      <div class="challenge-stats">
        <div><b data-ramadan-days>${toRamadan}</b><span>days until Ramadan</span></div>
        <div><b data-status>${esc(statusText)}</b><span>${esc(shortDate(c.start))} to ${esc(shortDate(c.end))}</span></div>
        <div><b data-joined>Free</b><span data-joined-label>to join, open until ${esc(shortDate(c.joinCloses))}</span></div>
      </div>
    </div>
    <div class="hero-visual">
      <div class="rings rings-gold" aria-hidden="true"><span></span><span></span><span></span></div>
      ${challengePhone()}
    </div>
  </div>
  <svg class="arch-line" viewBox="0 0 1440 120" preserveAspectRatio="none" aria-hidden="true"><path d="M0 120V60h560c40 0 80-60 160-60s120 60 160 60h560v60z"/></svg>
</section>

<section class="section" id="how">
  <div class="wrap">
    <p class="eyebrow">How to enter</p>
    <h2 class="section-title">Pray, log it, get entries</h2>
    <ol class="offer-steps">
      <li><b>Download Salah Alarm</b> on iPhone or Android and join the challenge. It's free.</li>
      <li><b>Log all five prayers</b> each day in the app. Every full day counts.</li>
      <li><b>Reach 30, 60 or 90 days</b> before ${esc(shortDate(c.end))} to earn 1, 2 or 3 entries.</li>
      <li><b>Invite friends</b> with your link: +1 entry for each friend who joins and logs their first full day.</li>
    </ol>
    <div class="entries">
      <div class="entry-card"><p class="offer-num">1</p><h3>entry</h3><p>30 days with all five prayers logged</p></div>
      <div class="entry-card"><p class="offer-num">2</p><h3>entries</h3><p>60 days with all five prayers logged</p></div>
      <div class="entry-card"><p class="offer-num">3</p><h3>entries</h3><p>All 90 days. You're Ramadan Ready.</p></div>
      <div class="entry-card entry-card-gold"><p class="offer-num">+1</p><h3>per friend</h3><p>Each friend who joins with your link, up to ${c.bonusCap} extra entries</p></div>
    </div>
    <p class="entries-example">${icon('sparkle', 'icon icon-sm')} Example: finish all 90 days and bring 7 friends, and you have 10 entries in the draw.</p>
    ${actions('how', false)}
  </div>
</section>

<section class="section prize-section">
  <div class="wrap">
    <div class="ramadan prize">
      <div class="ramadan-copy">
        <p class="eyebrow eyebrow-gold">The prize</p>
        <h2>Umrah for you and someone you love.</h2>
        <p>Return flights, a hotel near the Haram and Umrah visas for two (approximate value US$${c.prizeValueUsd.toLocaleString('en-US')}). The winner is drawn at random from all entries on ${esc(longDate(c.drawDate))}, as Ramadan begins.</p>
        <p class="fine">No purchase necessary; a purchase does not improve your chances. Open to residents of ${esc(c.eligibleCountries)}, 18+. Free entry without the app is available. Odds depend on the number of entries. Apple and Google are not sponsors. <a href="${esc(c.rulesPath)}">Official rules</a>.</p>
      </div>
      <div class="countdown prize-badge" aria-hidden="true">
        ${icon('compass', 'icon prize-icon')}
        <span class="countdown-label">Umrah for 2</span>
      </div>
    </div>
  </div>
</section>

<section class="section offer" id="invite">
  <div class="wrap">
    <p class="eyebrow">Bring your friends</p>
    <h2 class="section-title">Every friend is another chance. And free Premium.</h2>
    <p class="section-lead">Besides the extra entries, bring 3 friends and get a month of Premium free. Bring 10 and get a year free.</p>
    <div class="offer-grid">
      <div class="offer-card">
        <p class="offer-num">3</p>
        <h3>friends join</h3>
        <p>+3 entries and 1 month of Premium free, with every alarm and SalahLock unlocked.</p>
      </div>
      <div class="offer-card offer-card-big">
        <p class="offer-num">10</p>
        <h3>friends join</h3>
        <p>+10 entries and 1 year of Premium free. Post your link with your challenge videos and let your followers count too.</p>
      </div>
    </div>
  </div>
</section>

<section class="section phases-section">
  <div class="wrap">
    <p class="eyebrow">Your ${c.days} days</p>
    <h2 class="section-title">Three phases, then Ramadan</h2>
    <div class="phases">
      ${PHASES.map(([name, days, dates, text], i) => `<article class="phase${i === PHASES.length - 1 ? ' phase-finals' : ''}">
        <p class="phase-days">${esc(days)} · ${esc(dates)}</p>
        <h3>${esc(name)}</h3>
        <p>${esc(text)}</p>
      </article>`).join('')}
    </div>
    <p class="phases-note">${icon('check', 'icon icon-sm')} Only the five daily prayers count toward your entries. The rest is there to help you arrive ready.</p>
  </div>
</section>

<section class="section faq-section">
  <div class="wrap narrow">
    <p class="eyebrow">Questions</p>
    <h2 class="section-title">Before you join</h2>
    <div class="faq">${faq.map(([q, a]) => `<details><summary>${esc(q)}</summary><p>${esc(a)}</p></details>`).join('')}</div>
    <p class="faq-more"><a class="link-arrow" href="${esc(c.rulesPath)}">Official rules ${icon('arrow', 'icon icon-sm')}</a></p>
    <p class="faq-more"><a class="link-arrow" href="/blog/en/ramadan-2027-start-date/">Ramadan 2027 dates and how to prepare ${icon('arrow', 'icon icon-sm')}</a></p>
  </div>
</section>

<section class="cta-band challenge-band">
  <div class="wrap">
    <h2>Start tonight. Makkah could be next.</h2>
    <p>Join free on iPhone or Android, log your prayers, and bring your friends.</p>
    ${actions('band')}
    <p class="band-fine">The challenge is open to everyone, everywhere. No purchase necessary. Prize draw eligibility is in the <a href="${esc(c.rulesPath)}">official rules</a>.</p>
  </div>
</section>

<script>
(function () {
  var cfg = ${JSON.stringify({ start: c.start, days: c.days, ramadan: config.ramadanStart, showFrom: c.showCountFrom })};
  var DAY = 86400000;
  function midnight(d) { var p = d.split('-'); return new Date(+p[0], p[1] - 1, +p[2]).getTime(); }
  var today = new Date(); today.setHours(0, 0, 0, 0);
  var toRamadan = Math.max(0, Math.round((midnight(cfg.ramadan) - today) / DAY));
  var toStart = Math.round((midnight(cfg.start) - today) / DAY);
  document.querySelectorAll('[data-ramadan-days]').forEach(function (el) { el.textContent = toRamadan; });
  var status = document.querySelector('[data-status]');
  if (status) status.textContent = toStart > 1 ? 'Starts in ' + toStart + ' days' : toStart === 1 ? 'Starts tomorrow' : toStart === 0 ? 'Day 1 is today' : 'Day ' + Math.min(cfg.days, 1 - toStart) + ' of ' + cfg.days;

  // Invite code from /c/<CODE> (or ?code= typed by hand).
  var code = (new URLSearchParams(location.search).get('code') || '').toUpperCase();
  if (/^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/.test(code)) {
    var box = document.querySelector('[data-invite]');
    box.hidden = false;
    box.querySelector('[data-invite-code]').textContent = code;
    box.querySelector('[data-copy]').addEventListener('click', function (e) {
      var b = e.currentTarget;
      (navigator.clipboard ? navigator.clipboard.writeText(code) : Promise.reject()).then(function () { b.textContent = 'Copied'; }, function () { b.textContent = code; });
    });
    // The download buttons carry the code, so the app or Android signup can fill it in.
    document.querySelectorAll('[data-join]').forEach(function (a) { a.href = '/c/' + code + '?to=' + a.dataset.join + '&src=page-invite'; });
  }

  // Live joiner count, shown once it is big enough to be social proof.
  fetch('/ramadan-2027/stats.json').then(function (r) { return r.json(); }).then(function (s) {
    if (typeof s.joined !== 'number' || s.joined < cfg.showFrom) return;
    document.querySelector('[data-joined]').textContent = s.joined.toLocaleString('en');
    document.querySelector('[data-joined-label]').textContent = 'people have joined';
  }).catch(function () {});
})();
</script>`;

  return layout(config, {
    lang: 'en',
    title: 'Free Makkah Trip Challenge: Win Umrah for 2 | Salah Alarm',
    description: `Log your five daily prayers in Salah Alarm for 30, 60 or 90 days before Ramadan 2027 and win a free Umrah trip for two. Free to join on iPhone and Android.`,
    canonical: c.path,
    body,
    bodyClass: 'home challenge-page',
    jsonLd: [
      {
        '@context': 'https://schema.org',
        '@type': 'Event',
        name: `${c.name} (${c.hashtag})`,
        description: 'A free 90-day prayer challenge before Ramadan 2027, tracked in the Salah Alarm app, with a prize draw for an Umrah trip for two.',
        startDate: c.start,
        endDate: c.end,
        eventStatus: 'https://schema.org/EventScheduled',
        eventAttendanceMode: 'https://schema.org/OnlineEventAttendanceMode',
        isAccessibleForFree: true,
        location: { '@type': 'VirtualLocation', url: `${config.baseUrl}${c.path}` },
        image: `${config.baseUrl}/img/og.png`,
        organizer: { '@type': 'Organization', name: config.appName, url: config.baseUrl },
        offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD', availability: 'https://schema.org/InStock', url: `${config.baseUrl}${c.path}`, validFrom: '2026-11-01' },
      },
      { '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: faq.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) },
    ],
  });
}

// salahalarm.com/ramadan-2027/rules/ : the official rules the app links to.
function rulesFor(config) {
  const c = config.challenge;
  return [
    ['Sponsor', ['The Free Makkah Trip Challenge, also called the 90-Day Ramadan Ready challenge (the "Challenge"), and its prize draw (the "Draw") are run by Salah Alarm, the developer of the Salah Alarm app (the "Sponsor").']],
    ['Apple and Google are not involved', ['Apple is not a sponsor of, and is not involved in, this Challenge or Draw in any way. Google is not a sponsor either. Questions about the Challenge go to the Sponsor, not to Apple or Google.']],
    ['No purchase necessary', ['No purchase or subscription is necessary to join, to earn entries or to win. A purchase does not increase your chances of winning. Void where prohibited.']],
    ['Dates', [`The Challenge runs from ${longDate(c.start)} (Day 1) to ${longDate(c.end)} (Day 90). Joining is open until ${longDate(c.joinCloses)}. Days are counted in the time zone set on your phone. Free entries by email (rule 7) must arrive by 23:59 UTC on ${longDate(c.end)}.`]],
    ['Who can enter the Draw', [`The Draw is open to legal residents of ${c.eligibleCountries} who are 18 or older when they enter. Anyone may take part in the Challenge and earn badges and Premium rewards, but only eligible residents can win the prize. Employees of the Sponsor and their immediate families cannot win.`]],
    ['How to earn entries in the app', ['Join the Challenge in the Salah Alarm app and log all five daily prayers. A day counts when all five prayers are confirmed in the app for that day. Days before you joined do not count against you.', 'Logging 30 full days during the Challenge earns 1 entry, 60 full days earns 2 entries in total, and all 90 days earns 3 entries in total.', `Invite entries: every person who joins using your invite link or code and logs their own first full day earns you 1 extra entry, up to ${c.bonusCap} extra entries. Invite entries only count once you have earned at least 1 entry yourself.`]],
    ['How to enter without the app', [`You can also enter by email, without downloading the app or logging prayers. Send an email to ${c.freeEntryEmail} with the subject "Makkah Trip free entry" and your full name, country of residence, and confirmation that you are 18 or older. Each eligible person may send one email entry, which counts as 1 entry. Email entries have the same chance of winning as each app entry.`]],
    ['The prize', [`One winner receives an ${c.prizeName}: return economy flights from a major airport in the winner's country of residence, hotel accommodation near the Masjid al-Haram, and Umrah visas for the winner and one companion. Approximate retail value: US$${c.prizeValueUsd.toLocaleString('en-US')}. The trip must be taken by 31 December 2027 on dates agreed with the Sponsor. The winner and companion must hold passports valid for travel and meet Saudi visa requirements. Anything not listed, such as spending money and travel insurance, is not included. The prize cannot be exchanged for cash or transferred, except that the Sponsor may substitute a prize of equal or greater value if the trip cannot be provided.`]],
    ['How the winner is chosen', [`The winner is drawn at random from all valid entries on ${longDate(c.drawDate)}. The odds of winning depend on the number of entries received. The winner is contacted in the app and by email and must reply within 14 days, or another winner is drawn. Winners in Canada must correctly answer a mathematical skill-testing question before receiving the prize. The winner may be asked to sign a declaration of eligibility. Taxes on the prize, if any, are the winner's responsibility.`]],
    ['Badges and Premium rewards', ['Badges: Ramadan Ready for all 90 days, Silver for 80% of days, Bronze for 30 days. Badges have no cash value.', 'Bring 3 friends who join with your link or code and log their first full day: 1 month of Salah Alarm Premium free. Bring 10: 1 year free. Each reward can be earned once per person, is given as free Premium time in the app (for example through an App Store offer code), and cannot be exchanged for cash, transferred or sold. These rewards are open to everyone, wherever they live.']],
    ['Fair play', ['Invites from your own extra accounts, fake accounts, paid or automated sign-ups, and faked prayer logs do not count. The Sponsor may check logs and remove entries, badges or rewards earned this way, and may disqualify anyone who breaks these rules.']],
    ['Privacy', ['Your Challenge progress is stored with your Salah Alarm account and is used to run the Challenge and the Draw. Friends you invite do not see your prayer logs. The winner\'s first name and country may be announced. See the privacy policy for details.']],
    ['Changes', ['The Sponsor may update these rules for clarity or to fix problems. Changes will not take away entries or rewards you have already earned. The latest version is always on this page.']],
  ];
}

export function challengeRulesPage(config) {
  const c = config.challenge;
  const rules = rulesFor(config);
  const body = `<header class="article-hero">
  <div class="wrap narrow">
    <p class="crumbs"><a href="/">${esc(config.appName)}</a><span>/</span><a href="${esc(c.path)}">${esc(c.name)}</a></p>
    <h1>Official rules: ${esc(c.name)}</h1>
    <p class="lead">No purchase necessary. Apple is not a sponsor of, and is not involved in, this challenge.</p>
    <p class="meta">Last updated ${esc(longDate(c.rulesUpdated || '2026-11-09'))}</p>
  </div>
</header>
<div class="wrap narrow">
  <article class="prose rules">
    ${rules.map(([h, ps], i) => `<h2 id="r${i + 1}">${i + 1}. ${esc(h)}</h2>${ps.map((p) => `<p>${esc(p)}</p>`).join('')}`).join('\n    ')}
    <h2 id="contact">${rules.length + 1}. Contact</h2>
    <p>Questions about the Challenge: <a href="${esc(config.supportUrl)}">Salah Alarm support</a>. Privacy policy: <a href="${esc(config.privacyUrl)}">${esc(config.privacyUrl)}</a>.</p>
    <p><a class="link-arrow" href="${esc(c.path)}">Back to the challenge ${icon('arrow', 'icon icon-sm')}</a></p>
  </article>
</div>`;
  return layout(config, {
    lang: 'en',
    title: 'Free Makkah Trip Challenge: Official Rules | Salah Alarm',
    description: 'Official rules for the Free Makkah Trip Challenge in Salah Alarm: dates, eligibility, how to earn entries, free entry by email, the prize and the draw.',
    canonical: c.rulesPath,
    body,
    bodyClass: 'rules-page',
  });
}
