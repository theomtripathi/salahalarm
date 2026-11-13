import { esc, money, fmtDate, nextPayoutDate } from '../util.js';
import { page, flash } from './layout.js';
import { linkCtx, DISCORD } from './public.js';
import { TYPES } from '../content-data.js';
import { MIN_PAYOUT_USD } from '../commission.js';

const METHODS = [['wise', 'Wise'], ['paypal', 'PayPal'], ['payoneer', 'Payoneer']];

export function dashboard({ env, aff, stats, sales, payouts, posts, msg, kind, welcome }) {
  const L = linkCtx(env, aff);
  const pct = Math.max(0, Math.min(100, (stats.balance / MIN_PAYOUT_USD) * 100));
  const next = fmtDate(nextPayoutDate().toISOString());
  const checks = [
    [true, 'Get your link'],
    [Boolean(aff.payout_method && aff.payout_details), 'Add your payout details'],
    [posts.length > 0, 'Post your first video and log it below'],
    [stats.visits > 0, 'Get your first click'],
    [stats.sales > 0, 'Make your first sale'],
  ];
  const body = `
<div style="margin-top:28px">
${welcome ? flash('Welcome to Salah Alarm Affiliates! Your link is ready. Bookmark this page; you can always log back in with your email.') : ''}
${flash(msg, kind)}
<h1>Assalamu alaikum 👋</h1>
<p class="muted">Signed in as ${esc(aff.email)}</p>

<h2 style="margin-top:12px">Your link</h2>
<div class="link-card">
  <code id="my-link">${esc(L.link)}</code>
  <button class="btn btn-small" data-copy="${esc(L.linkUrl)}">Copy link</button>
</div>
<p class="small muted" style="margin-top:8px">Put it in the bio of every TikTok and Instagram page you post on.</p>

<div class="stats">
  <div class="stat"><div class="v">${stats.visits}</div><div class="k">Clicks</div></div>
  <div class="stat"><div class="v">${stats.downloads}</div><div class="k">Downloads</div></div>
  <div class="stat"><div class="v">${stats.sales}</div><div class="k">Approved sales</div></div>
  <div class="stat"><div class="v">${money(stats.earned)}</div><div class="k">Earned</div></div>
  <div class="stat"><div class="v">${money(stats.paid)}</div><div class="k">Paid out</div></div>
  <div class="stat"><div class="v">${money(stats.balance)}</div><div class="k">Balance</div></div>
</div>

<div class="card">
  <div style="display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap"><b>${stats.payable ? 'You\'re over the $100 minimum 🎉' : `${money(Math.max(0, MIN_PAYOUT_USD - stats.balance))} to go until your first payout`}</b><span class="muted small">Next payout date: ${next}</span></div>
  <div class="progress" style="margin-top:10px"><i style="width:${pct}%"></i></div>
  <p class="small muted" style="margin:10px 0 0">Sales show here once they're reviewed and approved. Payouts every 15 days once your balance is $100 or more.</p>
</div>

<div class="grid-2" style="margin-top:14px">
  <div class="card">
    <h3 style="margin-top:0">Getting started</h3>
    <ul class="checklist">${checks.map(([done, label]) => `<li class="${done ? 'done' : ''}"><span class="tick">${done ? '✓' : ''}</span>${esc(label)}</li>`).join('')}</ul>
    <p style="margin:12px 0 0"><a class="btn btn-small" href="/content">What to post</a> <a class="btn btn-small btn-ghost" href="${DISCORD}">Join Discord</a></p>
  </div>
  <div class="card">
    <h3 style="margin-top:0">Payout details</h3>
    <form method="post" action="/dashboard/payout">
      <div class="field"><label for="pm">Method</label><select id="pm" name="method" required>
        <option value="">Choose…</option>
        ${METHODS.map(([v, l]) => `<option value="${v}"${aff.payout_method === v ? ' selected' : ''}>${l}</option>`).join('')}
      </select></div>
      <div class="field"><label for="pd">Account email or ID</label><input id="pd" type="text" name="details" required maxlength="200" value="${esc(aff.payout_details || '')}" placeholder="The email on your Wise / PayPal / Payoneer account"></div>
      <button class="btn btn-small" type="submit">Save payout details</button>
    </form>
  </div>
</div>

<h2>Log a post</h2>
<div class="card">
  <p class="small muted">Paste the link to each video or slideshow you post. It helps us see what's working and share winning formats in Discord.</p>
  <form method="post" action="/dashboard/post" class="row">
    <div><label for="pu">Post URL</label><input id="pu" type="url" name="url" required placeholder="https://www.tiktok.com/@you/video/…"></div>
    <div><label for="pt">Content type</label><select id="pt" name="content_type"><option value="">Other</option>${TYPES.map((t) => `<option value="${t.slug}">${esc(t.title)}</option>`).join('')}</select></div>
    <div style="flex:0 0 auto;align-self:end"><button class="btn" type="submit">Log post</button></div>
  </form>
  ${posts.length ? `<div class="table-wrap" style="margin-top:14px"><table><thead><tr><th>Date</th><th>Post</th><th>Type</th></tr></thead><tbody>
  ${posts.map((p) => `<tr><td>${fmtDate(p.created_at)}</td><td><a href="${esc(p.url)}" target="_blank" rel="noopener nofollow">${esc(p.url.replace(/^https?:\/\/(www\.)?/, '').slice(0, 60))}</a></td><td>${esc(p.content_type || '')}</td></tr>`).join('')}
  </tbody></table></div>` : ''}
</div>

<h2>Approved sales</h2>
${sales.length ? `<div class="table-wrap"><table><thead><tr><th>Date</th><th>Platform</th><th class="num">You earn</th></tr></thead><tbody>
${sales.map((s) => `<tr><td>${fmtDate(s.created_at)}</td><td>${esc(s.platform || 'web')}</td><td class="num">${money(s.commission_usd)}</td></tr>`).join('')}
</tbody></table></div>` : '<p class="muted">No approved sales yet. Keep posting: most affiliates see their first sale after their first video that takes off.</p>'}

<h2>Payouts</h2>
${payouts.length ? `<div class="table-wrap"><table><thead><tr><th>Date</th><th>Method</th><th class="num">Amount</th></tr></thead><tbody>
${payouts.map((p) => `<tr><td>${fmtDate(p.created_at)}</td><td>${esc(p.method || '')}</td><td class="num">${money(p.amount_usd)}</td></tr>`).join('')}
</tbody></table></div>` : '<p class="muted">No payouts yet.</p>'}

<h2>Your username</h2>
<div class="card">
  ${aff.username_changed ? `<p class="muted" style="margin:0">Your username is <b>${esc(aff.username)}</b>. You've already used your one change; old links keep working.</p>` : `
  <p class="small muted">Your username is <b>${esc(aff.username)}</b>. You can change it once. Your current link keeps working after the change.</p>
  <form method="post" action="/dashboard/username" class="inline-form">
    <input type="text" name="username" required minlength="3" maxlength="24" pattern="[A-Za-z0-9_]{3,24}" placeholder="new username" aria-label="New username">
    <button class="btn btn-ghost" type="submit">Change username</button>
  </form>`}
</div>

<form method="post" action="/logout" style="margin-top:24px"><button class="link-btn">Log out</button></form>
</div>`;
  return page({ title: 'Dashboard · Salah Alarm Affiliates', body, user: aff });
}
