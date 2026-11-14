// Ramadan 2027 timetable pages, one per city, plus a hub page.
// Times come from the vendored adhan library (MIT), computed at build time for the
// expected Ramadan dates (1 Ramadan = 8 February 2027). Each city uses the calculation
// method most common there, and every page says which one and asks readers to check
// their local mosque, because many mosques publish their own fixed timetables.
import { Coordinates, CalculationMethod, PrayerTimes } from '../vendor/adhan.mjs';
import { escapeHtml as esc } from '../lib/markdown.mjs';
import { layout, ctaChallenge, ctaBand, storeButtons, stickyApp } from '../lib/ui.mjs';

export const HUB = '/ramadan-timetable-2027/';
const START = Date.UTC(2027, 1, 8); // 8 Feb 2027, expected 1 Ramadan
const DAYS = 30;

const METHODS = {
  NorthAmerica: { fn: () => CalculationMethod.NorthAmerica(), en: 'ISNA (Fajr 15°)', ar: 'الجمعية الإسلامية لأمريكا الشمالية' },
  MoonsightingCommittee: { fn: () => CalculationMethod.MoonsightingCommittee(), en: 'Moonsighting Committee', ar: 'لجنة رؤية الهلال' },
  UmmAlQura: { fn: () => CalculationMethod.UmmAlQura(), en: 'Umm al-Qura', ar: 'تقويم أم القرى' },
  Egyptian: { fn: () => CalculationMethod.Egyptian(), en: 'Egyptian General Authority of Survey', ar: 'الهيئة المصرية العامة للمساحة' },
  Dubai: { fn: () => CalculationMethod.Dubai(), en: 'Dubai', ar: 'دائرة الشؤون الإسلامية بدبي' },
  Kuwait: { fn: () => CalculationMethod.Kuwait(), en: 'Kuwait', ar: 'وزارة الأوقاف الكويتية' },
  Qatar: { fn: () => CalculationMethod.Qatar(), en: 'Qatar', ar: 'وزارة الأوقاف القطرية' },
  MuslimWorldLeague: { fn: () => CalculationMethod.MuslimWorldLeague(), en: 'Muslim World League', ar: 'رابطة العالم الإسلامي' },
};

// English pages: the cities where the Makkah challenge is open (US, UK, Canada).
export const CITIES = [
  { slug: 'london', lang: 'en', name: 'London', country: 'UK', lat: 51.5074, lng: -0.1278, tz: 'Europe/London', method: 'MoonsightingCommittee' },
  { slug: 'birmingham', lang: 'en', name: 'Birmingham', country: 'UK', lat: 52.4862, lng: -1.8904, tz: 'Europe/London', method: 'MoonsightingCommittee' },
  { slug: 'manchester', lang: 'en', name: 'Manchester', country: 'UK', lat: 53.4808, lng: -2.2426, tz: 'Europe/London', method: 'MoonsightingCommittee' },
  { slug: 'bradford', lang: 'en', name: 'Bradford', country: 'UK', lat: 53.7950, lng: -1.7594, tz: 'Europe/London', method: 'MoonsightingCommittee' },
  { slug: 'leicester', lang: 'en', name: 'Leicester', country: 'UK', lat: 52.6369, lng: -1.1398, tz: 'Europe/London', method: 'MoonsightingCommittee' },
  { slug: 'glasgow', lang: 'en', name: 'Glasgow', country: 'UK', lat: 55.8642, lng: -4.2518, tz: 'Europe/London', method: 'MoonsightingCommittee' },
  { slug: 'new-york', lang: 'en', name: 'New York', country: 'US', lat: 40.7128, lng: -74.0060, tz: 'America/New_York', method: 'NorthAmerica' },
  { slug: 'chicago', lang: 'en', name: 'Chicago', country: 'US', lat: 41.8781, lng: -87.6298, tz: 'America/Chicago', method: 'NorthAmerica' },
  { slug: 'houston', lang: 'en', name: 'Houston', country: 'US', lat: 29.7604, lng: -95.3698, tz: 'America/Chicago', method: 'NorthAmerica' },
  { slug: 'dallas', lang: 'en', name: 'Dallas', country: 'US', lat: 32.7767, lng: -96.7970, tz: 'America/Chicago', method: 'NorthAmerica' },
  { slug: 'los-angeles', lang: 'en', name: 'Los Angeles', country: 'US', lat: 34.0522, lng: -118.2437, tz: 'America/Los_Angeles', method: 'NorthAmerica' },
  { slug: 'detroit', lang: 'en', name: 'Detroit', country: 'US', lat: 42.3314, lng: -83.0458, tz: 'America/Detroit', method: 'NorthAmerica' },
  { slug: 'toronto', lang: 'en', name: 'Toronto', country: 'Canada', lat: 43.6532, lng: -79.3832, tz: 'America/Toronto', method: 'NorthAmerica' },
  { slug: 'mississauga', lang: 'en', name: 'Mississauga', country: 'Canada', lat: 43.5890, lng: -79.6441, tz: 'America/Toronto', method: 'NorthAmerica' },
  { slug: 'montreal', lang: 'en', name: 'Montreal', country: 'Canada', lat: 45.5017, lng: -73.5673, tz: 'America/Toronto', method: 'NorthAmerica' },
  { slug: 'calgary', lang: 'en', name: 'Calgary', country: 'Canada', lat: 51.0447, lng: -114.0719, tz: 'America/Edmonton', method: 'NorthAmerica' },
  { slug: 'vancouver', lang: 'en', name: 'Vancouver', country: 'Canada', lat: 49.2827, lng: -123.1207, tz: 'America/Vancouver', method: 'NorthAmerica' },
  { slug: 'riyadh', lang: 'ar', name: 'الرياض', country: 'السعودية', lat: 24.7136, lng: 46.6753, tz: 'Asia/Riyadh', method: 'UmmAlQura' },
  { slug: 'jeddah', lang: 'ar', name: 'جدة', country: 'السعودية', lat: 21.4858, lng: 39.1925, tz: 'Asia/Riyadh', method: 'UmmAlQura' },
  { slug: 'makkah', lang: 'ar', name: 'مكة المكرمة', country: 'السعودية', lat: 21.3891, lng: 39.8579, tz: 'Asia/Riyadh', method: 'UmmAlQura' },
  { slug: 'cairo', lang: 'ar', name: 'القاهرة', country: 'مصر', lat: 30.0444, lng: 31.2357, tz: 'Africa/Cairo', method: 'Egyptian' },
  { slug: 'dubai', lang: 'ar', name: 'دبي', country: 'الإمارات', lat: 25.2048, lng: 55.2708, tz: 'Asia/Dubai', method: 'Dubai' },
  { slug: 'kuwait', lang: 'ar', name: 'الكويت', country: 'الكويت', lat: 29.3759, lng: 47.9774, tz: 'Asia/Kuwait', method: 'Kuwait' },
  { slug: 'doha', lang: 'ar', name: 'الدوحة', country: 'قطر', lat: 25.2854, lng: 51.5310, tz: 'Asia/Qatar', method: 'Qatar' },
  { slug: 'amman', lang: 'ar', name: 'عمّان', country: 'الأردن', lat: 31.9454, lng: 35.9284, tz: 'Asia/Amman', method: 'MuslimWorldLeague' },
];

export const cityUrl = (c) => `${HUB}${c.slug}/`;

function times(c) {
  const coords = new Coordinates(c.lat, c.lng);
  const params = METHODS[c.method].fn();
  const loc = c.lang === 'ar' ? 'ar-u-nu-latn' : 'en-GB';
  const hm = new Intl.DateTimeFormat(loc, { hour: '2-digit', minute: '2-digit', hour12: c.lang === 'ar', timeZone: c.tz });
  const day = new Intl.DateTimeFormat(c.lang === 'ar' ? 'ar-u-nu-latn' : 'en-GB', { weekday: 'short', day: 'numeric', month: 'short', timeZone: 'UTC' });
  const rows = [];
  for (let i = 0; i < DAYS; i++) {
    const d = new Date(START + i * 864e5);
    // adhan reads the calendar date from the Date's local fields; build it at local noon.
    const local = new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), 12);
    const pt = new PrayerTimes(coords, local, params);
    rows.push({ n: i + 1, date: day.format(d), fajr: hm.format(pt.fajr), maghrib: hm.format(pt.maghrib), mins: Math.round((pt.maghrib - pt.fajr) / 6e4) });
  }
  return rows;
}

const dur = (m, lang) => (lang === 'ar' ? `${Math.floor(m / 60)} ساعة و${m % 60} دقيقة` : `${Math.floor(m / 60)}h ${m % 60}m`);

const COPY = {
  en: (c, r, method) => ({
    title: `Ramadan Timetable 2027 ${c.name}: Sehri and Iftar Times`,
    description: `Ramadan 2027 timetable for ${c.name}: sehri (Fajr) and iftar (Maghrib) times for all 30 days, from the expected start on 8 February 2027.`,
    h1: `Ramadan 2027 timetable for ${c.name}`,
    lead: `Sehri and iftar times in ${c.name} for every day of Ramadan 2027, expected to begin on Monday 8 February.`,
    cols: ['Ramadan', 'Date', 'Sehri ends (Fajr)', 'Iftar (Maghrib)'],
    intro: [
      `Ramadan 2027 is expected to start on Monday 8 February 2027, with the first taraweeh on the evening of Sunday 7 February. The official start in ${c.country === 'UK' ? 'the UK' : c.country === 'US' ? 'the US' : 'Canada'} depends on the moon sighting your mosque follows, so the whole table can shift by a day.`,
      `On the first day the fast in ${c.name} runs from ${r[0].fajr} to ${r[0].maghrib}, about ${dur(r[0].mins, 'en')}. By day 29 it lasts about ${dur(r[28].mins, 'en')}, because the days lengthen through February and March.`,
    ],
    methodNote: `Times are calculated for central ${c.name} with the ${method} method. Sehri ends at the start of Fajr; many mosques stop eating 10 minutes earlier as a precaution. Your local mosque's printed timetable may differ by a few minutes, so follow it where you have one.`,
    faq: [
      [`When does Ramadan 2027 start in ${c.name}?`, `It is expected to begin on Monday 8 February 2027, with taraweeh on the evening of 7 February. Confirm the date with your local mosque after the moon sighting.`],
      [`What time is sehri on the first day of Ramadan 2027 in ${c.name}?`, `Sehri is expected to end at ${r[0].fajr} on 8 February 2027, when Fajr begins.`],
      [`What time is iftar on the first day of Ramadan 2027 in ${c.name}?`, `Iftar is expected at ${r[0].maghrib} on 8 February 2027, at sunset (Maghrib).`],
      [`How long is the fast in ${c.name}?`, `About ${dur(r[0].mins, 'en')} on the first day, rising to about ${dur(r[28].mins, 'en')} by day 29.`],
    ],
    day30: 'Day 30 is only fasted if Ramadan completes 30 days.',
    hubLink: 'All Ramadan 2027 timetables',
    guides: [['/blog/en/what-time-to-wake-up-for-suhoor/', 'What time to wake up for suhoor'], ['/blog/en/ramadan-2027-calendar/', 'Ramadan 2027 calendar'], ['/blog/en/laylatul-qadr-2027/', 'Laylatul Qadr 2027']],
    alarmTitle: `Wake up for sehri in ${c.name}`,
    alarmBody: 'Salah Alarm calculates sehri and Fajr times for your exact location every day, reminds you before imsak, and plays the Fajr adhan as an alarm that only stops when you scan your prayer mat.',
  }),
  ar: (c, r, method) => ({
    title: `امساكية رمضان 2027 ${c.name}: مواعيد السحور والإفطار`,
    description: `امساكية رمضان 2027 في ${c.name}: موعد الإمساك (الفجر) والإفطار (المغرب) لكل أيام الشهر، من البداية المتوقعة يوم 8 فبراير 2027.`,
    h1: `امساكية رمضان 2027 في ${c.name}`,
    lead: `مواعيد السحور والإفطار في ${c.name} لكل يوم من رمضان 2027، المتوقع أن يبدأ يوم الاثنين 8 فبراير.`,
    cols: ['رمضان', 'التاريخ', 'الإمساك (الفجر)', 'الإفطار (المغرب)'],
    intro: [
      `يُتوقع أن يبدأ رمضان 1448 هـ يوم الاثنين 8 فبراير 2027، وتكون أول تراويح مساء الأحد 7 فبراير. والبداية الرسمية في ${c.country} تتبع إعلان رؤية الهلال، فقد يتقدم الجدول أو يتأخر يومًا.`,
      `في اليوم الأول يمتد الصيام في ${c.name} من ${r[0].fajr} إلى ${r[0].maghrib}، أي نحو ${dur(r[0].mins, 'ar')}. وفي اليوم التاسع والعشرين يصل إلى نحو ${dur(r[28].mins, 'ar')}.`,
    ],
    methodNote: `المواعيد محسوبة لوسط ${c.name} بطريقة ${method}. ينتهي السحور عند أذان الفجر، وكثير من المساجد تمسك قبله بعشر دقائق احتياطًا. وقد تختلف الامساكية الرسمية في بلدك بدقائق، فاتبعها إن وُجدت.`,
    faq: [
      [`متى يبدأ رمضان 2027 في ${c.name}؟`, `يُتوقع أن يبدأ يوم الاثنين 8 فبراير 2027، وتكون أول تراويح مساء 7 فبراير. تأكد من الإعلان الرسمي بعد رؤية الهلال.`],
      [`متى الإمساك في أول يوم من رمضان 2027 في ${c.name}؟`, `يُتوقع أن يكون الإمساك عند الفجر الساعة ${r[0].fajr} يوم 8 فبراير 2027.`],
      [`متى الإفطار في أول يوم من رمضان 2027 في ${c.name}؟`, `يُتوقع أن يكون الإفطار عند المغرب الساعة ${r[0].maghrib} يوم 8 فبراير 2027.`],
      [`كم ساعة الصيام في ${c.name}؟`, `نحو ${dur(r[0].mins, 'ar')} في أول يوم، وتصل إلى نحو ${dur(r[28].mins, 'ar')} في اليوم التاسع والعشرين.`],
    ],
    day30: 'اليوم الثلاثون يُصام فقط إذا أكمل رمضان ثلاثين يومًا.',
    hubLink: 'كل امساكيات رمضان 2027',
    guides: [['/blog/ar/kayfa-astayqiz-lilsuhur/', 'كيف أستيقظ للسحور'], ['/blog/ar/imsakiyat-ramadan-2027/', 'امساكية رمضان 2027'], ['/blog/ar/laylat-alqadr-2027/', 'ليلة القدر 2027']],
    alarmTitle: `استيقظ للسحور في ${c.name}`,
    alarmBody: 'يحسب Salah Alarm مواعيد السحور والفجر لموقعك كل يوم، ويذكّرك قبل الإمساك، ويشغّل أذان الفجر كمنبه لا يتوقف إلا عندما تمسح سجادة الصلاة بكاميرا هاتفك.',
  }),
};

export function cityPage(config, c) {
  const r = times(c);
  const m = METHODS[c.method][c.lang];
  const t = COPY[c.lang](c, r, m);
  const slug = `timetable-${c.slug}`;
  const table = `<div class="tt-wrap"><table class="tt">
<thead><tr>${t.cols.map((x) => `<th scope="col">${esc(x)}</th>`).join('')}</tr></thead>
<tbody>${r.map((x) => `<tr${x.n === 27 || x.n % 2 ? '' : ' class="even"'}><td>${x.n}</td><td>${esc(x.date)}</td><td>${esc(x.fajr)}</td><td>${esc(x.maghrib)}</td></tr>`).join('\n')}</tbody>
</table></div>
<p class="tt-note">${esc(t.day30)}</p>`;
  const faqHtml = `<section class="article-faq"><h2 id="faq">${esc(config.langs[c.lang].faq)}</h2><div class="faq">${t.faq.map(([q, a]) => `<details><summary>${esc(q)}</summary><p>${esc(a)}</p></details>`).join('')}</div></section>`;
  const body = `<header class="article-hero">
  <div class="wrap narrow">
    <p class="crumbs"><a href="/">${esc(config.appName)}</a><span>/</span><a href="${HUB}">${esc(t.hubLink)}</a></p>
    <h1>${esc(t.h1)}</h1>
    <p class="lead">${esc(t.lead)}</p>
  </div>
</header>
<div class="wrap narrow">
  <article class="prose">
    ${t.intro.map((p) => `<p>${esc(p)}</p>`).join('\n')}
    ${table}
    <p>${esc(t.methodNote)}</p>
    <aside class="cta-inline">
      <img src="/icon.png" alt="" width="56" height="56">
      <div>
        <p class="cta-title">${esc(t.alarmTitle)}</p>
        <p>${esc(t.alarmBody)}</p>
        ${storeButtons(config, c.lang, slug, 'buttons-light')}
      </div>
    </aside>
    ${c.lang === 'en' ? ctaChallenge(config, slug) : ''}
    <h2>${c.lang === 'ar' ? 'أدلة ذات صلة' : 'Related guides'}</h2>
    <ul>${t.guides.map(([href, label]) => `<li><a href="${href}">${esc(label)}</a></li>`).join('')}<li><a href="${HUB}">${esc(t.hubLink)}</a></li></ul>
    ${faqHtml}
  </article>
</div>
${ctaBand(config, c.lang, slug)}
${stickyApp(config, c.lang, slug)}`;
  const jsonLd = [{
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: t.faq.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })),
  }];
  return layout(config, { lang: c.lang, title: t.title, description: t.description, canonical: cityUrl(c), body, jsonLd, bodyClass: 'article-page timetable-page' });
}

export function hubPage(config) {
  const list = (lang) => CITIES.filter((c) => c.lang === lang)
    .map((c) => `<li><a href="${cityUrl(c)}">${esc(c.name)}</a> <span class="tt-country">${esc(c.country)}</span></li>`).join('');
  const body = `<header class="article-hero">
  <div class="wrap narrow">
    <h1>Ramadan 2027 timetables by city</h1>
    <p class="lead">Sehri and iftar times for every day of Ramadan 2027, expected to begin on Monday 8 February 2027.</p>
  </div>
</header>
<div class="wrap narrow">
  <article class="prose">
    <p>Pick your city for a 30-day table of sehri (Fajr) and iftar (Maghrib) times. Each table names its calculation method. Your local mosque's timetable may differ by a few minutes, so follow it where you have one.</p>
    <h2>UK, US and Canada</h2>
    <ul class="tt-cities">${list('en')}</ul>
    <h2 lang="ar" dir="rtl">امساكية رمضان 2027 في المدن العربية</h2>
    <ul class="tt-cities" lang="ar" dir="rtl">${list('ar')}</ul>
    ${ctaChallenge(config, 'timetable-hub')}
    <p>Not in the list? <a href="/blog/en/what-time-to-wake-up-for-suhoor/">Here is how to work out your own sehri time</a>, or let Salah Alarm calculate it for your exact location.</p>
  </article>
</div>
${ctaBand(config, 'en', 'timetable-hub')}
${stickyApp(config, 'en', 'timetable-hub')}`;
  return layout(config, {
    lang: 'en',
    title: 'Ramadan Timetable 2027: Sehri and Iftar Times by City',
    description: 'Ramadan 2027 timetables for UK, US, Canadian and Arab cities: sehri and iftar times for all 30 days, from the expected start on 8 February 2027.',
    canonical: HUB,
    body,
    bodyClass: 'article-page timetable-page',
  });
}
