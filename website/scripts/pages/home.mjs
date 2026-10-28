// The salahalarm.com landing page (English).

import { escapeHtml as esc } from '../lib/markdown.mjs';
import { icon, storeButtons, alarmPhone, layout, ctaBand } from '../lib/ui.mjs';

const FEATURES = [
  ['clock', 'Exact prayer times', 'Calculated for your location every day, with Muslim World League, Umm al-Qura, Egyptian, ISNA, Diyanet and other methods.'],
  ['bell', 'Adhan alarms', 'Every prayer can ring with a full adhan, not a notification you swipe away.'],
  ['scan', 'Prayer mat check', 'Point your camera at your prayer mat to stop the alarm and log the prayer.'],
  ['lock', 'SalahLock', 'Block distracting apps when prayer time arrives, until you have prayed.'],
  ['flame', 'Salah streaks', 'See every prayer you completed this week and keep the chain going.'],
  ['book', 'Quran', 'Read and reflect, with a daily ayah reminder on your home screen.'],
  ['compass', 'Qibla compass', 'Find the Qibla anywhere, at home or travelling.'],
  ['sparkle', 'Dua widgets', 'A dua of the day on your lock screen and home screen.'],
];

const STEPS = [
  ['/img/crop-01.webp', 'Salah Alarm home screen showing today\'s prayer times', 'Set it once', 'Allow location and Salah Alarm works out the exact Fajr, Dhuhr, Asr, Maghrib and Isha times for your city, every day.'],
  ['/img/screen-alarm.webp', 'Fajr alarm ringing with a scan your prayer mat button', 'The adhan wakes you', 'At Fajr the adhan plays as a full alarm. In strict mode there is no snooze: it keeps ringing until you get up.'],
  ['/img/crop-02.webp', 'Prayer confirmed after scanning the prayer mat', 'Walk to your mat', 'The alarm stops only when you scan your prayer mat. By then you are up, standing where you pray.'],
];

const FAQ = [
  ['How does the prayer mat scan work?', 'When the alarm rings, point your phone camera at your prayer mat and confirm the scan. That stops the alarm and logs the prayer, so you have to get out of bed to switch it off.'],
  ['Is Salah Alarm free?', 'Salah Alarm is free to download. Some features, such as SalahLock and advanced alarms, are part of an optional Premium subscription.'],
  ['Which prayer time calculation methods are supported?', 'Muslim World League, Umm al-Qura (Makkah), Egyptian General Authority, ISNA (North America), Diyanet (Turkey), Kuwait, Qatar, Dubai, Singapore and more. Choose the one your local mosque follows.'],
  ['Can I use it as a suhoor alarm in Ramadan?', 'Salah Alarm shows the imsak time and sends a reminder 30 minutes before it, so you get a nudge for suhoor. The adhan alarm at Fajr then makes sure you still pray on time.'],
  ['Is there an Android version?', 'Yes. Salah Alarm is available for Android and for iPhone. Tap Get it for Android to set up your account and start, or get the iPhone app from the App Store.'],
  ['Which languages does the app support?', 'English, Arabic, Turkish, Indonesian and Urdu.'],
];

function daysUntil(date) {
  return Math.max(0, Math.ceil((Date.parse(date) - Date.now()) / 86400000));
}

export function homePage(config, latest) {
  // The Android + iOS pair closing a section; light buttons on dark sections.
  const cta = (slug, dark = false) => `<div class="section-cta">${storeButtons(config, 'en', slug, dark ? 'buttons-light' : '')}</div>`;
  const days = daysUntil(config.ramadanStart);

  const body = `
<section class="hero">
  <div class="wrap hero-inner">
    <div class="hero-copy">
      <p class="pill">${icon('moon', 'icon icon-sm')} The Fajr alarm for Android and iPhone</p>
      <h1>Never miss Fajr again.</h1>
      <p class="hero-lead">The adhan alarm that only stops when you reach your prayer mat. Exact prayer times for your city, SalahLock, streaks, Quran and Qibla in one app.</p>
      <div class="hero-actions">
        ${storeButtons(config, 'en', 'hero', 'buttons-light')}
        <p class="rating">${icon('star', 'icon icon-star')}${icon('star', 'icon icon-star')}${icon('star', 'icon icon-star')}${icon('star', 'icon icon-star')}${icon('star', 'icon icon-star')}<span>Rated 4.8 on the App Store</span></p>
      </div>
    </div>
    <div class="hero-visual">
      <div class="rings" aria-hidden="true"><span></span><span></span><span></span></div>
      ${alarmPhone('phone-hero')}
    </div>
  </div>
  <svg class="arch-line" viewBox="0 0 1440 120" preserveAspectRatio="none" aria-hidden="true"><path d="M0 120V60h560c40 0 80-60 160-60s120 60 160 60h560v60z"/></svg>
</section>

<section class="section compare">
  <div class="wrap">
    <p class="eyebrow">Why normal alarms fail</p>
    <h2 class="section-title">Your Fajr alarm is easy to beat. That is the problem.</h2>
    <div class="compare-grid">
      <div class="compare-card bad">
        <h3>A normal alarm</h3>
        <ol>
          <li>${icon('bell', 'icon icon-sm')} Rings at 5:14</li>
          <li>${icon('x', 'icon icon-sm')} Swiped away half asleep</li>
          <li>${icon('x', 'icon icon-sm')} You wake up to sunlight</li>
        </ol>
      </div>
      <div class="compare-card good">
        <h3>Salah Alarm</h3>
        <ol>
          <li>${icon('bell', 'icon icon-sm')} Adhan rings at exact Fajr</li>
          <li>${icon('scan', 'icon icon-sm')} Stops only at your prayer mat</li>
          <li>${icon('check', 'icon icon-sm')} You are up, with wudu and two rak'ahs to go</li>
        </ol>
      </div>
    </div>
    ${cta('compare')}
  </div>
</section>

<section class="section" id="how">
  <div class="wrap">
    <p class="eyebrow">How it works</p>
    <h2 class="section-title">From asleep to the prayer mat in three steps</h2>
    <div class="steps">
      ${STEPS.map(([img, alt, title, text], i) => `<article class="step">
        <div class="step-visual">${i === 1 ? alarmPhone('phone-step') : `<img src="${img}" alt="${esc(alt)}" loading="lazy" decoding="async">`}</div>
        <p class="step-num">${i + 1}</p>
        <h3>${esc(title)}</h3>
        <p>${esc(text)}</p>
      </article>`).join('')}
    </div>
    ${cta('how-it-works')}
  </div>
</section>

<section class="section spotlight">
  <div class="wrap spotlight-inner">
    <div class="spotlight-visual"><img src="/img/crop-04.webp" alt="SalahLock active: apps are blocked until you complete your prayer" loading="lazy" decoding="async"></div>
    <div class="spotlight-copy">
      <p class="eyebrow eyebrow-gold">SalahLock</p>
      <h2>Your phone waits until you pray.</h2>
      <p>When prayer time arrives, SalahLock blocks the apps that steal your attention. Scan your prayer mat when you have prayed and everything unlocks.</p>
      <ul class="ticks">
        <li>${icon('check', 'icon icon-sm')} Choose which apps to block</li>
        <li>${icon('check', 'icon icon-sm')} Strict mode keeps them locked until you scan your mat</li>
        <li>${icon('check', 'icon icon-sm')} Works with every one of the five daily prayers</li>
      </ul>
      ${storeButtons(config, 'en', 'salahlock', 'buttons-light')}
    </div>
  </div>
</section>

<section class="section" id="features">
  <div class="wrap">
    <p class="eyebrow">Everything for your salah</p>
    <h2 class="section-title">One app for the whole day of prayer</h2>
    <div class="features">
      ${FEATURES.map(([ic, title, text]) => `<div class="feature">${icon(ic)}<h3>${esc(title)}</h3><p>${esc(text)}</p></div>`).join('')}
    </div>
    ${cta('features')}
  </div>
</section>

<section class="section gallery-section" aria-label="App screenshots">
  <div class="gallery">
    ${[1, 2, 3, 4, 5, 6, 7, 8].map((n) => `<img src="/img/store-0${n}.webp" alt="Salah Alarm App Store screenshot ${n}" width="270" height="584" decoding="async">`).join('')}
  </div>
  <div class="wrap">${cta('screenshots')}</div>
</section>

<section class="section" id="ramadan">
  <div class="wrap">
    <div class="ramadan">
      <div class="ramadan-copy">
        <p class="eyebrow eyebrow-gold">Ramadan 2027</p>
        <h2>Ramadan is expected to begin on Monday 8 February 2027.</h2>
        <p>Suhoor is won or lost the same way Fajr is: in the first minute after the alarm. Build the habit now and the month will feel easy.</p>
        <a class="link-arrow" href="/blog/en/ramadan-2027-start-date/">Ramadan 2027 dates and how to prepare ${icon('arrow', 'icon icon-sm')}</a>
        ${storeButtons(config, 'en', 'ramadan', 'buttons-light')}
      </div>
      <div class="countdown" data-target="${config.ramadanStart}">
        <span class="countdown-num" data-days>${days}</span>
        <span class="countdown-label">days to go</span>
      </div>
    </div>
  </div>
</section>

<section class="section languages">
  <div class="wrap">
    <p class="eyebrow">Made for the Ummah</p>
    <h2 class="section-title">In your language</h2>
    <div class="lang-chips">
      ${Object.entries(config.langs).map(([code, l]) => `<a class="chip" href="/blog/${code}/" lang="${code}" dir="${l.dir}">${esc(l.name)}</a>`).join('')}
    </div>
    ${cta('languages')}
  </div>
</section>

${latest.length ? `<section class="section">
  <div class="wrap">
    <div class="section-head"><div><p class="eyebrow">Guides</p><h2 class="section-title">Read before you sleep</h2></div><a class="link-arrow" href="/blog/en/">All guides ${icon('arrow', 'icon icon-sm')}</a></div>
    <div class="cards">${latest.map((a) => card(config, a)).join('')}</div>
    ${cta('guides')}
  </div>
</section>` : ''}

<section class="section faq-section">
  <div class="wrap narrow">
    <p class="eyebrow">Questions</p>
    <h2 class="section-title">Frequently asked questions</h2>
    <div class="faq">${FAQ.map(([q, a]) => `<details><summary>${esc(q)}</summary><p>${esc(a)}</p></details>`).join('')}</div>
    ${cta('faq')}
  </div>
</section>

${ctaBand(config, 'en', 'home')}

<script>
(function () {
  var el = document.querySelector('.countdown');
  if (!el) return;
  var d = Math.max(0, Math.ceil((Date.parse(el.dataset.target) - Date.now()) / 86400000));
  el.querySelector('[data-days]').textContent = d;
})();
</script>`;

  return layout(config, {
    lang: 'en',
    title: 'Salah Alarm: Fajr Alarm & Prayer Times App for Android & iPhone',
    description: 'Salah Alarm wakes you for Fajr at the exact prayer time and only stops at your prayer mat. Prayer times, SalahLock, Qibla, Quran and duas for Android and iPhone.',
    canonical: '/',
    body,
    bodyClass: 'home',
    jsonLd: [
      { '@context': 'https://schema.org', '@type': 'MobileApplication', name: config.appName, operatingSystem: 'iOS, Android', applicationCategory: 'LifestyleApplication', downloadUrl: config.appStoreUrl, offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' } },
      { '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: FAQ.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) },
    ],
  });
}

export function card(config, a) {
  const s = config.langs[a.lang];
  return `<a class="card" href="${a.url}" lang="${a.lang}" dir="${s.dir}">
  <span class="card-meta">${esc(s.name)} · ${esc(s.readingTime.replace('{n}', a.minutes))}</span>
  <h3>${esc(a.title)}</h3>
  <p>${esc(a.description)}</p>
  <span class="card-more">${esc(s.readMore)} ${icon('arrow', 'icon icon-sm')}</span>
</a>`;
}
