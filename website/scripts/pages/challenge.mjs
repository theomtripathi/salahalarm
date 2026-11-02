// salahalarm.com/ramadan-2027/ : the 90-Day Ramadan Ready challenge landing page.
// Comment-to-link replies, bio links and invite links (/c/<CODE>) all land here.

import { escapeHtml as esc } from '../lib/markdown.mjs';
import { icon, layout } from '../lib/ui.mjs';

const PHASES = [
  ['Fajr foundation', 'Days 1 to 30', '10 Nov to 9 Dec', 'Fajr on time every day, plus the other four prayers logged.'],
  ['Five a day', 'Days 31 to 60', '10 Dec to 8 Jan', 'All five prayers on time, plus one page of Quran.'],
  ['Sha\'ban training', 'Days 61 to 90', '9 Jan to 7 Feb', 'All five prayers, plus the Monday and Thursday sunnah fasts.'],
  ['Ramadan finals', '30 days', 'From about 8 Feb', 'All five prayers, suhoor before Fajr and iftar at Maghrib, the whole month.'],
];

const FAQ = [
  ['Is the challenge free?', 'Yes. Joining, tracking your days and getting your invite link are free. Premium features such as SalahLock and the locked Fajr alarm stay optional.'],
  ['What counts as a day done?', 'A prayer counts when you confirm it in the app inside its prayer time. Fajr counts when you dismiss the alarm and confirm before sunrise. Each phase adds one small habit on top, like a page of Quran.'],
  ['What if I miss a day?', 'Every phase has three grace days. A missed prayer is a setback, not the end of your challenge.'],
  ['Can I still join after Day 1?', 'Yes. Joining is open until 1 December. Late joiners follow a shorter track and can earn every badge.'],
  ['How do the invite rewards work?', 'Join, then tap Invite friends in the app to get your personal link. When 3 friends join with your link and complete their Day 1, you get a month of Premium free. At 10 friends, you get a year free.'],
  ['How is the Umrah winner chosen?', 'Finishers send a 60-second video about their Ramadan Ready journey, and judges pick the winner on published criteria. It is not a lucky draw. No purchase is necessary, and the official rules and eligibility are published before it opens.'],
  ['When does Ramadan 2027 start?', 'Ramadan 2027 is expected to begin on or around Monday 8 February 2027. The exact date depends on the moon sighting in your country.'],
];

function day(date) {
  return Date.parse(`${date}T00:00:00Z`);
}

function daysBetween(from, to) {
  return Math.ceil((to - from) / 86400000);
}

function shortDate(date) {
  return new Intl.DateTimeFormat('en-GB', { weekday: 'short', day: 'numeric', month: 'short', timeZone: 'UTC' }).format(new Date(day(date)));
}

// The challenge screen in the app, drawn in HTML like the alarm phone.
function challengePhone() {
  const prayers = [['Fajr', true], ['Dhuhr', true], ['Asr', true], ['Maghrib', false], ['Isha', false]];
  return `<div class="phone phone-hero challenge-phone" role="img" aria-label="The Ramadan Ready challenge in Salah Alarm: day 23 of 90, three of five prayers done today">
  <div class="phone-screen challenge-screen" dir="ltr" aria-hidden="true">
    <div class="alarm-status"><span>9:41</span><span class="alarm-status-icons"></span></div>
    <div class="cs-tag">#ImRamadanReady</div>
    <div class="cs-ring"><svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="44"/><circle class="cs-ring-fill" cx="50" cy="50" r="44" pathLength="90" stroke-dasharray="23 90"/></svg>
      <div class="cs-ring-text"><b>23</b><span>of 90 days</span></div>
    </div>
    <div class="cs-phase">Phase 1 · Fajr foundation</div>
    <div class="cs-list">${prayers.map(([name, done]) => `<div class="cs-row${done ? ' done' : ''}"><span>${name}</span><i>${done ? icon('check', 'icon') : ''}</i></div>`).join('')}</div>
    <div class="cs-invite">${icon('sparkle', 'icon')} 2 of 3 friends joined</div>
  </div>
</div>`;
}

export function challengePage(config) {
  const c = config.challenge;
  const now = Date.now();
  const start = day(c.start);
  const ramadan = day(config.ramadanStart);
  const toRamadan = Math.max(0, daysBetween(now, ramadan));
  const toStart = daysBetween(now, start);
  const statusText = toStart > 0
    ? `Day 1 is ${shortDate(c.start)}`
    : `Day ${Math.min(c.days, 1 - toStart)} of ${c.days}`;
  const showPrize = c.prize !== false;
  const faq = FAQ.filter(([q]) => showPrize || !q.includes('Umrah'));

  const buttons = (where, light = true) => `<div class="challenge-actions">
    <a class="btn btn-gold" rel="nofollow" href="${esc(c.joinUrl)}" data-join data-cta="challenge-${where}-join">${icon('moon', 'icon icon-sm')} Download and join</a>
    <a class="btn ${light ? 'btn-ghost-light' : 'btn-ghost'}" rel="nofollow" href="${esc(c.inviteUrl)}" data-cta="challenge-${where}-invite">${icon('arrow', 'icon icon-sm')} Get my invite link</a>
  </div>`;

  const body = `
<section class="hero challenge-hero">
  <div class="wrap hero-inner">
    <div class="hero-copy">
      <p class="pill">${icon('moon', 'icon icon-sm')} ${esc(c.hashtag)} · free ${c.days}-day challenge</p>
      <h1>Be Ramadan Ready in ${c.days} days.</h1>
      <p class="hero-lead">Ramadan 2027 is expected around 8 February. Start now with one habit at a time: Fajr first, then all five prayers, Quran and sunnah fasts. Arrive at Ramadan already in rhythm, with thousands of Muslims doing it with you.</p>
      <div class="invite-note" data-invite hidden>
        <p><strong>Your friend invited you.</strong> Join with their code so it counts for both of you.</p>
        <div class="invite-code"><code data-invite-code></code><button type="button" class="btn btn-small btn-ghost-light" data-copy>Copy code</button></div>
        <p class="invite-help">If the app doesn't pick it up, enter it under "Got an invite code?" when you join.</p>
      </div>
      ${buttons('hero')}
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

<section class="section offer" id="invite">
  <div class="wrap">
    <p class="eyebrow">Bring your friends</p>
    <h2 class="section-title">Bring 3 friends, get a month free. Bring 10, get a year free.</h2>
    <p class="section-lead">Ramadan is easier together. Every joiner gets a personal invite link, and your rewards unlock as your friends start.</p>
    <div class="offer-grid">
      <div class="offer-card">
        <p class="offer-num">3</p>
        <h3>friends join</h3>
        <p>1 month of Premium free, with every alarm and SalahLock unlocked.</p>
      </div>
      <div class="offer-card offer-card-big">
        <p class="offer-num">10</p>
        <h3>friends join</h3>
        <p>1 year of Premium free. Post your link with your challenge videos and let your followers count too.</p>
      </div>
    </div>
    <ol class="offer-steps">
      <li><b>Join free</b> in Salah Alarm.</li>
      <li><b>Tap Invite friends</b> to get your link, like salahalarm.com/c/K7QX2M.</li>
      <li><b>Share it</b> in your stories, group chats and comments.</li>
      <li><b>Each friend counts</b> once they complete their Day 1. We'll tell you when a reward unlocks.</li>
    </ol>
    ${buttons('offer', false)}
  </div>
</section>

<section class="section phases-section">
  <div class="wrap">
    <p class="eyebrow">The ${c.days} days</p>
    <h2 class="section-title">Three phases, then Ramadan</h2>
    <div class="phases">
      ${PHASES.map(([name, days, dates, text], i) => `<article class="phase${i === PHASES.length - 1 ? ' phase-finals' : ''}">
        <p class="phase-days">${esc(days)} · ${esc(dates)}</p>
        <h3>${esc(name)}</h3>
        <p>${esc(text)}</p>
      </article>`).join('')}
    </div>
    <p class="phases-note">${icon('check', 'icon icon-sm')} Three grace days in every phase. Finish ${c.days} days to earn the Ramadan Ready badge, 80% for Silver, 30 days for Bronze.</p>
  </div>
</section>

${showPrize ? `<section class="section prize-section">
  <div class="wrap">
    <div class="ramadan prize">
      <div class="ramadan-copy">
        <p class="eyebrow eyebrow-gold">The prize</p>
        <h2>Finish the challenge. One finisher goes to Umrah with someone they love.</h2>
        <p>A 7-day Umrah trip for two: flights, a hotel near the Haram and visas. Finishers who joined by ${esc(shortDate(c.joinCloses))} send a 60-second video about their Ramadan Ready journey, and judges pick the winner on published criteria. It's not a lucky draw.</p>
        <p class="fine">No purchase necessary. Official rules and eligibility are published before it opens.</p>
      </div>
      <div class="countdown prize-badge" aria-hidden="true">
        ${icon('compass', 'icon prize-icon')}
        <span class="countdown-label">Umrah for 2</span>
      </div>
    </div>
  </div>
</section>` : ''}

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
    <h2>Day 1 is ${esc(shortDate(c.start))}. Start with Fajr.</h2>
    <p>Join free, bring your friends, and be ready when the crescent is sighted.</p>
    ${buttons('band')}
  </div>
</section>

<script>
(function () {
  var cfg = ${JSON.stringify({ start: c.start, days: c.days, ramadan: config.ramadanStart, showFrom: c.showCountFrom, joinCloses: shortDate(c.joinCloses) })};
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
    // Download carries the code, so the app can fill it in on first open.
    document.querySelectorAll('[data-join]').forEach(function (a) { a.href = '/c/' + code + '?src=page-invite'; });
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
    title: '90-Day Ramadan Ready Challenge 2027: Join Free | Salah Alarm',
    description: 'Get ready for Ramadan 2027 in 90 days: Fajr first, then all five prayers, Quran and sunnah fasts. Free to join. Bring 3 friends for a free month.',
    canonical: c.path,
    body,
    bodyClass: 'home challenge-page',
    jsonLd: [
      {
        '@context': 'https://schema.org',
        '@type': 'Event',
        name: `${c.name} (${c.hashtag})`,
        description: 'A free 90-day challenge to build Fajr, the five daily prayers, Quran and sunnah fasting before Ramadan 2027, tracked in the Salah Alarm app.',
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
const RULES = [
  ['Sponsor', ['The 90-Day Ramadan Ready challenge (the "Challenge") is run by Salah Alarm, the developer of the Salah Alarm app (the "Sponsor").']],
  ['Apple is not involved', ['Apple is not a sponsor of, and is not involved in, this Challenge in any way. Google is not a sponsor either. Questions about the Challenge go to the Sponsor, not to Apple or Google.']],
  ['Free to join, no purchase necessary', ['Joining and taking part are free. No purchase or subscription is necessary to join, to track your days, to get an invite link or to earn any reward. Buying a subscription does not improve your results or rewards.']],
  ['Dates', ['Day 1 is Tuesday 10 November 2026 and Day 90 is Sunday 7 February 2027. Joining is open until 1 December 2026. People who join after Day 1 start on the day they join and follow a shorter track.', 'Dates and times use the local time zone set on your phone.']],
  ['Who can take part', ['Anyone who can use the Salah Alarm app may join. If you are under the age of majority where you live, you need a parent or guardian\'s permission. One Challenge entry per person.']],
  ['How days are counted', ['A prayer counts when you confirm it in the app inside its prayer time for your location. Fajr counts when you dismiss the alarm and confirm before sunrise.', 'Phase 1 (days 1 to 30): Fajr on time, plus the other four prayers logged. Phase 2 (days 31 to 60): all five prayers on time, plus one page of Quran. Phase 3 (days 61 to 90): all five prayers, plus the Monday and Thursday sunnah fasts.', 'Each phase includes three grace days that cover missed days.']],
  ['Badges', ['Ramadan Ready: all 90 days done, using at most the grace days. Silver: 80% of days done. Bronze: 30 days done. Badges have no cash value.']],
  ['Invite rewards', ['Every person who joins gets a personal invite link and code. A friend counts toward your rewards when they join using your link or code and complete their own Day 1. A friend does not have to buy anything to count.', '3 friends who count: 1 month of Salah Alarm Premium free. 10 friends who count: 1 year of Salah Alarm Premium free. Each reward can be earned once per person.', 'Rewards are given as free Premium time in the app, for example through an App Store offer code. They cannot be exchanged for cash, transferred or sold.']],
  ['No prize draw', ['There is no lottery or prize draw in this Challenge. If the Sponsor adds a prize later, it will come with its own official rules, published before it opens.']],
  ['Fair play', ['Invites from your own extra accounts, fake accounts, paid or automated sign-ups, and faked prayer logs do not count. The Sponsor may remove entries, badges or rewards earned this way.']],
  ['Privacy', ['Your Challenge progress is stored with your Salah Alarm account. Friends you invite are not shown your prayer logs. See the privacy policy for details.']],
  ['Changes', ['The Sponsor may update these rules for clarity or to fix problems. Changes will not take away a reward you have already earned. The latest version is always on this page.']],
];

export function challengeRulesPage(config) {
  const c = config.challenge;
  const body = `<header class="article-hero">
  <div class="wrap narrow">
    <p class="crumbs"><a href="/">${esc(config.appName)}</a><span>/</span><a href="${esc(c.path)}">Ramadan Ready challenge</a></p>
    <h1>Official rules: 90-Day Ramadan Ready challenge</h1>
    <p class="lead">Free to join. No purchase necessary. Apple is not a sponsor of, and is not involved in, this challenge.</p>
    <p class="meta">Last updated 2 November 2026</p>
  </div>
</header>
<div class="wrap narrow">
  <article class="prose rules">
    ${RULES.map(([h, ps], i) => `<h2 id="r${i + 1}">${i + 1}. ${esc(h)}</h2>${ps.map((p) => `<p>${esc(p)}</p>`).join('')}`).join('\n    ')}
    <h2 id="contact">${RULES.length + 1}. Contact</h2>
    <p>Questions about the Challenge: <a href="${esc(config.supportUrl)}">Salah Alarm support</a>. Privacy policy: <a href="${esc(config.privacyUrl)}">${esc(config.privacyUrl)}</a>.</p>
    <p><a class="link-arrow" href="${esc(c.path)}">Back to the challenge ${icon('arrow', 'icon icon-sm')}</a></p>
  </article>
</div>`;
  return layout(config, {
    lang: 'en',
    title: 'Ramadan Ready Challenge Official Rules | Salah Alarm',
    description: 'Official rules for the free 90-Day Ramadan Ready challenge in Salah Alarm: dates, how days count, invite rewards and fair play. No purchase necessary.',
    canonical: c.rulesPath,
    body,
    bodyClass: 'rules-page',
  });
}
