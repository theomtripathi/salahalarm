// Affiliate-facing pages: landing + sign-up, login, content library, resources, FAQ, payout terms.
import { esc } from '../util.js';
import { page, flash } from './layout.js';
import {
  TYPES, findType, SCREENSHOTS, BENEFITS, HOOK_STYLES, CTAS, BIO_LINES, makkahPrompt, daysUntil, numberWords,
  RAMADAN_2027, ENTRIES_CLOSE,
} from '../content-data.js';

export const DISCORD = 'https://discord.gg/yZ2D3N5u3w';
export const CLIP_BUILDER = 'https://drive.google.com/drive/folders/1fe1tnS-jqtPIa-lB7BdXSMaymRcu0VC9?usp=sharing';
export const CLIP_REFERENCE = 'https://drive.google.com/drive/folders/15Ob_DQNHSBxPMM4GuUeTO_losAsQcVL2?usp=sharing';

export function linkCtx(env, user, now = new Date()) {
  const main = env.MAIN_SITE || 'https://salahalarm.com';
  const host = main.replace(/^https?:\/\//, '');
  const n = daysUntil(RAMADAN_2027, now);
  return user
    ? { loggedIn: true, username: user.username, link: `${host}/${user.username}`, linkUrl: `${main}/${user.username}`, daysToRamadan: n, daysWords: numberWords(n) }
    : { loggedIn: false, username: '', link: '[your link]', linkUrl: '[your link]', daysToRamadan: n, daysWords: numberWords(n) };
}

const copyBlock = (id, text, label = 'Copy') =>
  `<div class="copy-block has-btn"><button class="btn btn-small btn-ghost copy" data-copy="#${id}">${label}</button><pre id="${id}">${esc(text)}</pre></div>`;

export function termsBox() {
  return `<div class="terms-box">
    <div><b>50%</b>of the revenue from users you bring in</div>
    <div><b>$100</b>minimum payout</div>
    <div><b>Every 15 days</b>payouts on the 1st and 16th</div>
    <div><b>Wise, PayPal or Payoneer</b>you choose</div>
  </div>`;
}

function signupForm(msg) {
  return `<form method="post" action="/signup" class="inline-form" id="join-form">
    <input type="email" name="email" required placeholder="you@email.com" autocomplete="email" aria-label="Email">
    <button class="btn btn-gold" type="submit">Get my link</button>
  </form>${msg ? `<p class="small" style="margin-top:10px">${esc(msg)}</p>` : '<p class="small" style="margin:10px 0 0">Just your email. Your personal link appears instantly.</p>'}`;
}

export function landing({ user, msg }) {
  const body = `
<section class="hero">
  <div>
    <span class="kicker">Salah Alarm Affiliates</span>
    <h1>Help Muslims never miss a prayer. Earn 50% of the revenue.</h1>
    <p class="lead">Post short videos and slideshows about Salah Alarm on TikTok and Instagram. Everyone who buys Salah Alarm on salahalarm.com through your link earns you half of what they pay. We give you the content ideas, hooks, prompts and assets.</p>
    ${user ? `<a class="btn" href="/dashboard">Open my dashboard</a>` : `<a class="btn" href="#join">Get my link</a> <a class="btn btn-ghost" href="/content">See what to post</a>`}
  </div>
  <div class="hero-phones">
    <img src="/img/app/store-03.webp" alt="Salah Alarm Fajr alarm screen" width="270" height="584">
    <img src="/img/app/store-04.webp" alt="SalahLock: apps blocked until you pray" width="270" height="584">
  </div>
</section>

${user ? '' : `<section class="join" id="join">
  <h2>Get your link in 10 seconds</h2>
  <p>Enter your email. No forms, no approval wait.</p>
  ${flash(msg && msg.startsWith('!') ? msg.slice(1) : '', 'bad')}
  ${signupForm(msg && !msg.startsWith('!') ? msg : '')}
</section>`}

<h2>What you earn</h2>
${termsBox()}
<p class="muted small">Full details in <a href="/terms">payout terms</a> and the <a href="/faq">FAQ</a>.</p>

<h2>How it works</h2>
<ol class="steps">
  <li><b>Join with your email.</b> You get your own Salah Alarm link straight away.</li>
  <li><b>Pick a content type.</b> Clips, slideshows, skits, AI story videos. Every type has hooks, CTAs, scripts and screenshots ready.</li>
  <li><b>Post on TikTok and Instagram.</b> Put your link in your bio. Run more than one page to multiply your reach.</li>
  <li><b>Get paid.</b> Every 15 days by Wise, PayPal or Payoneer once you pass $100.</li>
</ol>

<h2>What you're promoting</h2>
<div class="grid-2">
  <div class="card"><ul style="margin:0;padding-left:20px">${BENEFITS.map((b) => `<li>${esc(b)}</li>`).join('')}</ul></div>
  <div class="card">
    <p><b>Why it sells:</b> nearly every Muslim has struggled with Fajr or with praying on time. Salah Alarm is a simple, visual answer, so it's easy to show in a 10-second video.</p>
    <p class="muted small">Available on iPhone and Android. Your link sends people to salahalarm.com, which takes them through a short setup and on to the right store.</p>
  </div>
</div>

<h2>Content you can post today</h2>
<div class="grid">${TYPES.map(typeCard).join('')}</div>

<h2>Join the community</h2>
<div class="card">
  <p>Salah Alarm Affiliates have a Discord where Om shares new content, hooks that are working, and answers questions.</p>
  <a class="btn btn-ghost" href="${DISCORD}" rel="noopener">Join the Discord</a>
</div>`;
  return page({ title: 'Salah Alarm Affiliates: earn 50% promoting Salah Alarm', description: 'Join Salah Alarm Affiliates with just your email. Earn 50% of the revenue from users you bring in. Payouts every 15 days via Wise, PayPal or Payoneer.', body, user });
}

function typeCard(t) {
  return `<a class="card type-card" href="/content/${t.slug}">
    <span class="emoji" aria-hidden="true">${t.emoji}</span>
    <h3>${esc(t.title)}</h3>
    <p>${esc(t.short)}</p>
    <div class="meta">${t.tags.map((x) => `<span class="pill">${esc(x)}</span>`).join('')}</div>
  </a>`;
}

export function loginPage({ msg, kind = 'ok', email = '' }) {
  const body = `
<div style="max-width:480px;margin:48px auto">
  <h1>Log in</h1>
  <p class="muted">Enter the email you joined with. We'll email you a one-tap sign-in link.</p>
  ${flash(msg, kind)}
  <form method="post" action="/login" class="card">
    <div class="field"><label for="email">Email</label><input id="email" type="email" name="email" required value="${esc(email)}" autocomplete="email"></div>
    <button class="btn" type="submit" style="width:100%">Email me a sign-in link</button>
  </form>
  <p class="small muted" style="margin-top:14px">New here? <a href="/#join">Get your link</a>. Can't find the email? Check spam, or ask in <a href="${DISCORD}">Discord</a>.</p>
</div>`;
  return page({ title: 'Log in · Salah Alarm Affiliates', body });
}

export function contentIndex({ user, env }) {
  const L = linkCtx(env, user);
  const body = `
<h1 style="margin-top:32px">What to post</h1>
<p class="muted">Seven content types, each with real examples that hit 100K+ views, hooks, CTAs, scripts, app screenshots and AI voice settings. Start with one, post it every day for a week, then add a second.</p>
<div class="grid">${TYPES.map(typeCard).join('')}</div>

<h2>The playbook in 6 lines</h2>
<div class="card">
<ol style="margin:0;padding-left:20px">
  <li><b>Run several pages.</b> Make 2-3 TikTok accounts and 1-2 Instagram accounts, each with a clear theme (Fajr, Ramadan, reminders). More pages = more chances to go viral.</li>
  <li><b>Post the same video on TikTok and Instagram.</b> Reels and TikTok reward the same short videos. Add YouTube Shorts for free extra reach.</li>
  <li><b>Post 1-3 times a day per page.</b> Most views come from a few outliers, so volume matters more than polish.</li>
  <li><b>Put your link in every bio.</b> ${L.loggedIn ? `Yours is <code>${esc(L.link)}</code>.` : 'You get it when you join.'} Reels and TikToks can't have clickable links, so the bio is where people tap.</li>
  <li><b>Hook first.</b> The first line on screen decides everything. Test 2-3 hooks on the same video across your pages.</li>
  <li><b>Soft CTA.</b> 80% value, 20% app. "My friend built an app called Salah Alarm" beats "DOWNLOAD NOW".</li>
</ol>
</div>

<h2>Hooks that work for any type</h2>
${hookSection()}

<h2>CTAs</h2>
${ctaSection(L)}

<h2>Bio lines</h2>
${BIO_LINES(L).map((b, i) => copyBlock(`bio${i}`, b)).join('')}

<h2>App screenshots</h2>
${shotsSection()}`;
  return page({ title: 'What to post · Salah Alarm Affiliates', description: 'Content types, hooks, CTAs and assets for Salah Alarm affiliates.', body, user, active: '/content' });
}

function hookSection() {
  let i = 0;
  return Object.entries(HOOK_STYLES).map(([style, hooks]) => `<h3>${esc(style)} hooks</h3><ul class="hooks">${hooks.map((h) => {
    i += 1;
    return `<li><span id="hk${i}">${esc(h)}</span><button class="btn btn-small btn-ghost" data-copy="#hk${i}">Copy</button></li>`;
  }).join('')}</ul>`).join('');
}

function ctaSection(L) {
  return `<ul class="hooks">${CTAS(L).map((c, i) => `<li><span id="cta${i}">${esc(c)}</span><button class="btn btn-small btn-ghost" data-copy="#cta${i}">Copy</button></li>`).join('')}</ul>`;
}

function shotsSection() {
  return `<p class="muted small">Tap one to open it full size, or <a href="/downloads/salah-alarm-screenshots.zip">download all 8 (zip)</a>. Use them on the last slides of carousels or in app demo videos.</p>
<div class="shots">${SCREENSHOTS.map((s) => `<a href="${s.src}" target="_blank" rel="noopener" title="${esc(s.label)}"><img src="${s.src}" alt="${esc(s.label)}" loading="lazy" width="270" height="584"></a>`).join('')}</div>`;
}

export function contentType({ user, env, slug, now = new Date() }) {
  const t = findType(slug);
  if (!t) return null;
  const L = linkCtx(env, user, now);
  const sub = (s) => s.replace(/\{DAYS\}/g, String(L.daysToRamadan));
  const closed = t.slug === 'makkah-trip-story' && daysUntil(ENTRIES_CLOSE, now) <= 0;
  const sections = [
    ['why', 'Why it works'], ['refs', 'Examples (100K+)'], ...(t.hasPrompt ? [['prompt', 'The prompt']] : []),
    ...(t.layout ? [['layout', 'Layout']] : []), ['how', 'How to make it'], ...(t.templates ? [['templates', 'Scripts']] : []),
    ['hooks', 'Hooks'], ['ctas', 'CTAs'], ['voice', 'AI voice'], ['assets', 'Screenshots'], ['rules', 'Rules'],
  ];
  const body = `
<p style="margin-top:24px"><a href="/content">← All content types</a></p>
<h1><span aria-hidden="true">${t.emoji}</span> ${esc(t.title)}</h1>
<p class="lead muted">${esc(t.short)}</p>
<div class="meta" style="display:flex;gap:6px;flex-wrap:wrap">${t.tags.map((x) => `<span class="pill">${esc(x)}</span>`).join('')}<span class="pill">${esc(t.effort)}</span></div>
${L.loggedIn ? '' : `<div class="callout">Join to see this page with <b>your own link</b> filled into every CTA and prompt. <a href="/#join">Get my link</a></div>`}
${closed ? `<div class="callout"><b>Entries for the Makkah Trip draw closed on 9 January 2027.</b> Don't post this format any more; use the <a href="/content/ramadan-countdown">Ramadan countdown</a> instead.</div>` : ''}
<nav class="toc">${sections.map(([id, label]) => `<a href="#${id}">${label}</a>`).join('')}</nav>

<h2 id="why">Why it works</h2>
<ul>${t.why.map((w) => `<li>${esc(w)}</li>`).join('')}</ul>

<h2 id="refs">Examples to study (100K+)</h2>
<p class="muted small">Watch 3-4 of these before you make your first one. Copy the structure, not the video. Numbers are from our research library; open the post for today's count.</p>
<ul class="refs">${t.refs.map((r) => `<li><a href="${esc(r.url)}" target="_blank" rel="noopener nofollow">${esc(r.label)}</a> · <b>${esc(r.views)}</b><br><span class="muted small">${esc(r.note)}</span></li>`).join('')}</ul>

${t.hasPrompt ? `<h2 id="prompt">The full prompt (today: ${L.daysToRamadan} days to Ramadan)</h2>
<p class="muted small">Paste everything into your AI video tool. The day count and your link are already filled in. Come back each day for a fresh copy, or change the number yourself for the day you post.</p>
${copyBlock('prompt-text', makkahPrompt(L), 'Copy prompt')}` : ''}

${t.layout ? `<h2 id="layout">The layout</h2>
<div class="grid-2"><div class="mock">
  <div class="who"><img src="/img/icon.png" alt=""><div><b>Salah Alarm</b> ✓<small>@salah_alarm</small></div></div>
  <div>Someone made an alarm that won't stop until you're on your prayer mat...</div>
  <div class="vid">your clip here (15-45 s)</div>
</div>
<div><ul>
  <li>1080x1920, black background.</li>
  <li>Top block: app icon, "Salah Alarm", handle, and one hook line ending in "...". White text, 48-56 px.</li>
  <li>Middle: the clip, full width.</li>
  <li>Last 2-3 seconds: CTA text over the clip.</li>
  <li>The <a href="${CLIP_BUILDER}" target="_blank" rel="noopener">clip builder</a> in Resources adds hooks to many clips at once.</li>
</ul></div></div>` : ''}

<h2 id="how">How to make it</h2>
<ol>${t.steps.map((s) => `<li>${esc(sub(s))}</li>`).join('')}</ol>

${t.templates ? `<h2 id="templates">Scripts and templates</h2>
${t.templates.map((tp, i) => `<h3>${esc(tp.name)}</h3>${copyBlock(`tpl${i}`, tp.slides.map((s) => sub(s).replace(/X days/g, `${L.daysToRamadan} days`)).join('\n'))}`).join('')}` : ''}

<h2 id="hooks">Hooks</h2>
${hookSection()}

<h2 id="ctas">CTAs</h2>
${ctaSection(L)}

<h2 id="voice">AI voice (ElevenLabs)</h2>
<div class="card"><p>${esc(t.voice)}</p><p class="small muted" style="margin:0">Full guide: <a href="/resources#elevenlabs">ElevenLabs settings and pronunciation</a>.</p></div>

<h2 id="assets">App screenshots</h2>
${shotsSection()}
<h3>What the app does (say only these)</h3>
<ul>${BENEFITS.map((b) => `<li>${esc(b)}</li>`).join('')}</ul>

<h2 id="rules">Rules for this format</h2>
<ul>${t.rules.map((r) => `<li>${esc(r)}</li>`).join('')}</ul>
<p class="small muted">Always use your own link (in your bio or caption), never a direct App Store or Play Store link: only purchases on salahalarm.com through your link earn commission. Plus the general <a href="/faq#content-rules">content rules</a>.</p>`;
  return page({ title: `${t.title} · Salah Alarm Affiliates`, description: t.short, body, user, active: '/content' });
}

export function resources({ user }) {
  const body = `
<h1 style="margin-top:32px">Resources</h1>

<h2>Community: Discord</h2>
<div class="card">
  <p>Join as a Salah Alarm Affiliate. Om shares new content, the hooks that are working this week, and answers questions there.</p>
  <a class="btn" href="${DISCORD}" rel="noopener">Join the Discord</a>
</div>

<h2>Clip builder (build your own clipping setup)</h2>
<div class="card">
  <p>The clip builder downloads creators' videos in bulk and adds your hooks on top, so you can make dozens of clips in one sitting. The folder has the app (<code>clip-engine.zip</code>), a bulk clipping tool, and packs of Islamic source clips.</p>
  <ol>
    <li>Open the folder and download <code>clip-engine.zip</code>. Unzip it on your computer and follow the README inside.</li>
    <li>Add the source clips you want (the "islamic content" folder has packs to start with).</li>
    <li>Paste in hooks from the <a href="/content/clipping#hooks">clipping page</a>, export, post.</li>
  </ol>
  <a class="btn btn-ghost" href="${CLIP_BUILDER}" target="_blank" rel="noopener">Open the clip builder folder</a>
</div>

<h2>Clipping campaign reference</h2>
<div class="card">
  <p>This is the reference for the campaign style we want: speaker clips with a tweet-style hook card on top. Look at the hook folders (Concept Reveal, Receipt, Self-Trick, Guilt-Flip) to see how one clip gets many hooks. Our versions of those hook types are on the <a href="/content/clipping">clipping page</a>.</p>
  <a class="btn btn-ghost" href="${CLIP_REFERENCE}" target="_blank" rel="noopener">Open the reference folder</a>
</div>

<h2>Carousel inspiration</h2>
<div class="card">
  <p><a href="https://topcarousels.com/" target="_blank" rel="noopener">topcarousels.com</a> collects carousels that went viral. Filter for faith, self-improvement and habits, copy the layouts, and use our <a href="/content/slideshows">slideshow templates</a> for the words.</p>
</div>

<h2 id="elevenlabs">ElevenLabs: AI voice guide</h2>
<div class="card">
  <ol>
    <li>Create a free account at <a href="https://elevenlabs.io" target="_blank" rel="noopener">elevenlabs.io</a>. The free tier is enough to test; the Starter plan covers daily posting.</li>
    <li>Text to Speech → model <b>Eleven Multilingual v2</b> (best with Arabic words mixed into English).</li>
    <li>Pick a voice from the Voice Library: search "calm narrator", "warm storyteller" or "soft conversational". Use a different voice on each of your pages.</li>
    <li>Starting settings: <b>Stability 45</b>, <b>Similarity 75</b>, <b>Style 10-20</b>, <b>Speaker boost on</b>, speed 1.0-1.15. Lower stability = more emotion; raise it if the voice wobbles.</li>
    <li>Pronunciation: if a word comes out wrong, spell it the way it sounds. "Salah" → "Sa-laah", "Dhuhr" → "Zuhr", "Fajr" → "Fudger", "Isha" → "Ee-sha", "Umrah" → "Oom-rah", "Haram" (the mosque) → "Ha-raam". ElevenLabs also has a pronunciation dictionary for this.</li>
    <li>Add pauses with a full stop or a line break between sentences. Generate 2-3 takes and keep the best.</li>
    <li>Download as MP3 (44.1 kHz), drop it into CapCut, and use auto captions.</li>
  </ol>
  <p class="small muted" style="margin:0">Don't clone the voice of a real scholar, reciter or public figure. Don't use AI for Quran recitation; use a real recitation or none.</p>
</div>

<h2>Instagram</h2>
<div class="card"><p>Follow <a href="https://www.instagram.com/salah_alarm/" target="_blank" rel="noopener">@salah_alarm</a> for the official posts. You're welcome to reshare them with your link.</p></div>

<h2>App screenshots</h2>
${shotsSection()}`;
  return page({ title: 'Resources · Salah Alarm Affiliates', body, user, active: '/resources' });
}

// FAQ answers. Marked (assumed) in the source where Om hasn't decided yet; easy to edit here.
export const FAQ = [
  ['Getting paid', [
    ['How much do I earn?', 'You earn 50% of the revenue from the users you bring in. A sale counts when someone opens your link and buys Salah Alarm on salahalarm.com.'],
    ['When do I get paid?', 'Every 15 days: on the 1st and 16th of each month. Your approved balance is paid if it is at least $100 on that date.'],
    ['What is the minimum payout?', '$100. If your balance is below $100 on a payout date, it rolls over to the next one. Nothing expires.'],
    ['How do I get paid?', 'Wise, PayPal or Payoneer. Choose one and enter your account email in your dashboard under "Payout details". Payouts are sent manually by the Salah Alarm team.'],
    ['Which currency?', 'Earnings are tracked in US dollars and sent in USD. Your provider may convert it to your currency.'],
    ['Who pays transfer fees?', 'We send the full amount; any fee your provider charges to receive it is on their side. If a method doesn\'t work in your country, pick another one or ask us in Discord.'],
    ['Do I need to send an invoice?', 'No. We pay from what the dashboard shows. You are responsible for any taxes on your earnings where you live.'],
    ['What if someone asks for a refund?', 'Refunded payments are removed from your earnings. If a refund comes in after you were already paid, it is taken off your next payout.'],
  ]],
  ['Tracking', [
    ['How does tracking work?', 'Your link is unique to you. When someone opens it, we remember (for 60 days on that device) that they came from you. If they buy Salah Alarm on salahalarm.com within that time, the sale is yours.'],
    ['Do App Store or Google Play purchases count?', 'No. Only purchases made on salahalarm.com through your link earn commission. If someone finds the app in the App Store or Google Play on their own and buys inside the app, that sale isn\'t linked to you. Always share your own link, never a direct App Store or Play Store link.'],
    ['What if they click someone else\'s link after mine?', 'The last affiliate link they opened before signing up gets the sale.'],
    ['What do I see in my dashboard?', 'Clicks on your link, downloads, approved sales, your balance, what has been paid, and the next payout date.'],
    ['Why isn\'t a sale showing yet?', 'Every sale is reviewed before it appears in your dashboard, to filter out refunds, test purchases and fraud. Most are reviewed within a few days. Your dashboard only shows approved sales.'],
    ['What if they search "Salah Alarm" in the App Store instead of using my link?', 'Then we can\'t see that they came from you. Always point people to the link in your bio, and say "link in bio" in your videos.'],
    ['Can I change my username?', 'Once, from your dashboard. Your old link keeps working too.'],
    ['Does my link work on iPhone and Android?', 'Yes. It opens salahalarm.com, which guides people to the right app store.'],
  ]],
  ['Content', [
    ['What should I post?', 'Start with the content library: seven formats with examples, hooks, CTAs, scripts and screenshots. Clipping and reminder overlays are the fastest to start with.'],
    ['How often should I post?', '1-3 times a day per page. Volume wins: a few videos will do most of your views.'],
    ['Can I run more than one page?', 'Yes, and you should. Run 2-3 TikTok accounts and 1-2 Instagram accounts with different themes, and post on both platforms. Put your link in every bio.'],
    ['Can I use other creators\' videos?', 'Use clips the way clipping campaigns do: short cuts with your own hook, captions and CTA, never a whole video re-uploaded untouched. Credit the creator when you can, and take a clip down if the owner asks.'],
    ['Can I use the app screenshots and the Salah Alarm name?', 'Yes, for promoting Salah Alarm. Don\'t make accounts that pretend to be the official Salah Alarm account, and don\'t use "Salah Alarm" as your page name on its own; add your own twist (for example "fajr.with.sara").'],
    ['Can I run paid ads?', 'You can boost your own posts. Don\'t bid on "Salah Alarm" as a search keyword in Google or Apple Search Ads, and don\'t run ads that look like they come from Salah Alarm itself.'],
    ['Do I need to say it\'s an ad?', 'Yes. Follow your platform\'s rules: turn on the paid partnership / branded content label or add #ad or #affiliate to the caption.'],
    ['Can I talk about the Free Makkah Trip?', 'Yes, as long as you call it a free prize draw and "a chance". Never say anyone will win. Include the eligibility line (US, UK & Canada residents 18+, odds depend on entries) and point to the rules at salahalarm.com/ramadan-2027. Entries close on 9 January 2027.'],
  ]],
  ['Account', [
    ['Who can join?', 'Anyone with an email address who can receive Wise, PayPal or Payoneer payments. You must be old enough to have one of those accounts where you live.'],
    ['How do I log back in?', 'Go to the log-in page and enter your email. We\'ll send you a one-tap sign-in link (check spam if you don\'t see it).'],
    ['Can I buy Salah Alarm through my own link?', 'You can, but your own purchases don\'t earn commission. Self-referrals, fake accounts and paid-then-refunded purchases are removed.'],
    ['Can my account be closed?', 'Yes, if you break the content rules, spam, mislead people or try to fake sales. Approved earnings from genuine sales are still paid.'],
    ['I have a question that\'s not here.', 'Ask in the Discord. Om reads it.'],
  ]],
];

export const CONTENT_RULES = [
  'Be respectful of Islam and of all Muslims. Nothing sectarian, no mocking scholars or other groups.',
  'Quote Quran verses with a reference and hadith only with a source. If you\'re not sure, don\'t quote it.',
  'Only say what the app really does. No fake reviews, fake screenshots or made-up results.',
  'The Makkah Trip is a free prize draw: "a chance", never "you will win".',
  'No spam: no mass comments or DMs with your link, no fake engagement.',
  'Label your posts as ads where your platform requires it.',
];

export function faqPage({ user }) {
  const body = `
<h1 style="margin-top:32px">FAQ</h1>
<p class="muted">Everything about earning, tracking and content. Still stuck? Ask in <a href="${DISCORD}">Discord</a>.</p>
${FAQ.map(([group, items]) => `<h2>${esc(group)}</h2>${items.map(([q, a]) => `<details><summary>${esc(q)}</summary><div>${esc(a)}</div></details>`).join('')}`).join('')}
<h2 id="content-rules">Content rules</h2>
<div class="card"><ul style="margin:0;padding-left:20px">${CONTENT_RULES.map((r) => `<li>${esc(r)}</li>`).join('')}</ul></div>`;
  return page({ title: 'FAQ · Salah Alarm Affiliates', description: 'How Salah Alarm Affiliates get paid, how tracking works, and what content is allowed.', body, user, active: '/faq' });
}

export function termsPage({ user }) {
  const body = `
<h1 style="margin-top:32px">Payout terms</h1>
${termsBox()}
<div class="card">
<ul style="margin:0;padding-left:20px">
  <li>Affiliates earn <b>50% of the revenue</b> from users they bring in.</li>
  <li>Minimum payout: <b>$100</b>.</li>
  <li>Payouts every <b>15 days</b> (1st and 16th of each month).</li>
  <li>Payment methods: <b>Wise, PayPal or Payoneer</b>.</li>
  <li>Payouts are sent manually by the Salah Alarm team. The dashboard tracks and reports what you're owed.</li>
  <li>Only purchases made on <b>salahalarm.com</b> through your link earn commission. Purchases made directly in the App Store, Google Play or inside the app don't count.</li>
  <li>Every sale is reviewed before it is approved and added to your balance. Refunded, fraudulent or self-referred sales are not paid.</li>
  <li>We may update these terms; changes apply to sales after the change and will be announced in Discord.</li>
</ul>
</div>
<p class="small muted" style="margin-top:14px">Questions: see the <a href="/faq">FAQ</a> or ask in <a href="${DISCORD}">Discord</a>.</p>`;
  return page({ title: 'Payout terms · Salah Alarm Affiliates', body, user, active: '/terms' });
}

export function notFound({ user }) {
  return page({ title: 'Not found · Salah Alarm Affiliates', body: '<div style="margin:64px 0;text-align:center"><h1>Page not found</h1><p><a href="/">Back to Salah Alarm Affiliates</a></p></div>', user });
}
