// Om's admin dashboard: totals, per-affiliate numbers, the approval queue, payouts.
import { esc, money, fmtDate, nextPayoutDate } from '../util.js';
import { page, flash } from './layout.js';
import { MIN_PAYOUT_USD } from '../commission.js';

const statusPill = (s) => {
  const cls = { approved: 'pill-ok', pending: 'pill-warn', rejected: 'pill-bad', refunded: 'pill-bad' }[s] || '';
  return `<span class="pill ${cls}">${esc(s.replace('_', ' '))}</span>`;
};

export function adminLogin({ msg }) {
  const body = `<div style="max-width:420px;margin:56px auto">
  <h1>Admin</h1>
  ${flash(msg, 'bad')}
  <form method="post" action="/admin/login" class="card">
    <div class="field"><label for="pw">Password</label><input id="pw" type="password" name="password" required autocomplete="current-password"></div>
    <button class="btn" type="submit" style="width:100%">Log in</button>
  </form></div>`;
  return page({ title: 'Admin · Salah Alarm Affiliates', body, admin: true });
}

export function adminOverview({ totals, rows, msg, range }) {
  const ranges = [['7', 'Last 7 days'], ['30', 'Last 30 days'], ['all', 'All time']];
  const body = `
<div style="margin-top:24px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px">
  <h1 style="margin:0">Affiliates</h1>
  <div class="toc" style="margin:0">${ranges.map(([v, l]) => `<a href="/admin?range=${v}"${range === v ? ' style="border-color:var(--gold)"' : ''}>${l}</a>`).join('')}<a href="/admin/export.csv">Export CSV</a></div>
</div>
${flash(msg)}
<div class="stats">
  <div class="stat"><div class="v">${totals.affiliates}</div><div class="k">Affiliates</div></div>
  <div class="stat"><div class="v">${totals.visits}</div><div class="k">Clicks</div></div>
  <div class="stat"><div class="v">${totals.checkouts}</div><div class="k">Checkouts started</div></div>
  <div class="stat"><div class="v">${totals.downloads}</div><div class="k">Downloads</div></div>
  <div class="stat"><div class="v">${totals.charges}</div><div class="k">Charges</div></div>
  <div class="stat"><div class="v">${money(totals.revenue)}</div><div class="k">Revenue (USD)</div></div>
  <div class="stat"><div class="v">${money(totals.pending)}</div><div class="k">Commission waiting for you</div></div>
  <div class="stat"><div class="v">${money(totals.owed)}</div><div class="k">Approved, unpaid</div></div>
  <div class="stat"><div class="v">${money(totals.paid)}</div><div class="k">Paid out</div></div>
</div>
${totals.pendingCount ? `<div class="callout"><b>${totals.pendingCount} conversion${totals.pendingCount === 1 ? '' : 's'} waiting for approval.</b> Affiliates only see sales you approve. <a href="/admin/review">Review now</a></div>` : ''}
<p class="small muted">Clicks, checkouts, downloads, charges and revenue are for the selected range. Money owed and paid is all time. Next payout date: ${fmtDate(nextPayoutDate().toISOString())}.</p>
<div class="table-wrap"><table>
<thead><tr><th>Affiliate</th><th>Joined</th><th class="num">Clicks</th><th class="num">Checkouts</th><th class="num">Downloads</th><th class="num">Charges</th><th class="num">Revenue</th><th class="num">Pending</th><th class="num">Balance</th><th class="num">Paid</th><th>Posts</th><th>Payout</th></tr></thead>
<tbody>
${rows.length ? rows.map((r) => `<tr>
  <td><a href="/admin/affiliates/${r.id}"><b>${esc(r.username)}</b></a><br><span class="small muted">${esc(r.email)}</span>${r.status !== 'active' ? ` ${statusPill(r.status)}` : ''}</td>
  <td>${fmtDate(r.created_at)}</td>
  <td class="num">${r.visits}</td><td class="num">${r.checkouts}</td><td class="num">${r.downloads}</td><td class="num">${r.charges}</td>
  <td class="num">${money(r.revenue)}</td><td class="num">${money(r.pending)}</td>
  <td class="num">${r.balance >= MIN_PAYOUT_USD ? `<b>${money(r.balance)}</b>` : money(r.balance)}</td><td class="num">${money(r.paid)}</td>
  <td>${r.posts}</td><td>${esc(r.payout_method || '')}</td>
</tr>`).join('') : '<tr><td colspan="12" class="muted">No affiliates yet. Share affiliate.salahalarm.com.</td></tr>'}
</tbody></table></div>`;
  return page({ title: 'Admin · Salah Alarm Affiliates', body, admin: true, active: 'admin', wide: true });
}

function convTable(convs, { selectable = false, showAff = true } = {}) {
  return `<div class="table-wrap"><table>
<thead><tr>${selectable ? '<th><input type="checkbox" data-check-all aria-label="Select all"></th>' : ''}<th>Date</th>${showAff ? '<th>Affiliate</th>' : ''}<th>Source</th><th>Type</th><th>Plan</th><th class="num">Charge</th><th class="num">Commission</th><th>Rule</th><th>Customer</th><th>Status</th>${selectable ? '' : '<th></th>'}</tr></thead>
<tbody>${convs.length ? convs.map((c) => `<tr>
  ${selectable ? `<td><input type="checkbox" name="ids" value="${c.id}" aria-label="Select #${c.id}"></td>` : ''}
  <td>${fmtDate(c.created_at)}</td>
  ${showAff ? `<td><a href="/admin/affiliates/${c.affiliate_id}">${esc(c.username || c.affiliate_id)}</a></td>` : ''}
  <td>${esc(c.source)} ${esc(c.platform || '')}</td><td>${esc(c.kind)}</td><td>${esc(c.interval)}</td>
  <td class="num">${c.currency !== 'USD' ? `${esc(c.amount)} ${esc(c.currency)} ≈ ` : ''}${money(c.amount_usd)}${c.fx_estimated ? ' <span class="pill pill-warn">FX est.</span>' : ''}</td>
  <td class="num"><b>${money(c.commission_usd)}</b></td>
  <td class="small muted">${esc(c.rule || '')}</td>
  <td class="small"><code>${esc((c.app_user_id || '').slice(0, 14))}</code></td>
  <td>${statusPill(c.status)}${c.payout_id ? ' <span class="pill">paid</span>' : ''}</td>
  ${selectable ? '' : `<td>${c.status === 'pending' ? decisionButtons(c.id) : c.status === 'approved' && !c.payout_id && c.kind !== 'refund' ? `<form method="post" action="/admin/conversions/decide"><input type="hidden" name="ids" value="${c.id}"><input type="hidden" name="decision" value="rejected"><button class="link-btn">Undo approval</button></form>` : ''}</td>`}
</tr>`).join('') : `<tr><td colspan="12" class="muted">Nothing here.</td></tr>`}</tbody></table></div>`;
}

const decisionButtons = (id) => `<form method="post" action="/admin/conversions/decide"><input type="hidden" name="ids" value="${id}"><input type="hidden" name="decision" value="approved"><button class="btn btn-small">Approve</button></form>
<form method="post" action="/admin/conversions/decide"><input type="hidden" name="ids" value="${id}"><input type="hidden" name="decision" value="rejected"><button class="btn btn-small btn-ghost">Reject</button></form>`;

export function adminReview({ pending, recent, msg }) {
  const body = `
<h1 style="margin-top:24px">Review conversions</h1>
${flash(msg)}
<p class="muted">Every attributed payment that earns a commission lands here first. Affiliates only see it after you approve. Reject test purchases, self-referrals and anything that looks fake. Refunds of pending sales are removed automatically.</p>
<form method="post" action="/admin/conversions/decide">
${convTable(pending, { selectable: true })}
${pending.length ? `<div style="display:flex;gap:10px;margin-top:12px;flex-wrap:wrap">
  <button class="btn" name="decision" value="approved">Approve selected</button>
  <button class="btn btn-ghost" name="decision" value="rejected">Reject selected</button>
</div>` : ''}
</form>
<h2>Recently decided</h2>
${convTable(recent)}`;
  return page({ title: 'Review · Admin', body, admin: true, active: 'review', wide: true });
}

export function adminAffiliate({ aff, stats, convs, payouts, posts, events, msg }) {
  const body = `
<p style="margin-top:20px"><a href="/admin">← All affiliates</a></p>
<h1>${esc(aff.username)} ${aff.status !== 'active' ? statusPill(aff.status) : ''}</h1>
<p class="muted">${esc(aff.email)} · joined ${fmtDate(aff.created_at)} · last active ${fmtDate(aff.last_active_at)} · link <code>salahalarm.com/${esc(aff.username)}</code></p>
${flash(msg)}
<div class="stats">
  <div class="stat"><div class="v">${stats.visits}</div><div class="k">Clicks</div></div>
  <div class="stat"><div class="v">${stats.uniqueVisitors}</div><div class="k">Unique visitors</div></div>
  <div class="stat"><div class="v">${events.checkouts}</div><div class="k">Checkouts</div></div>
  <div class="stat"><div class="v">${stats.downloads}</div><div class="k">Downloads</div></div>
  <div class="stat"><div class="v">${money(stats.earned)}</div><div class="k">Approved commission</div></div>
  <div class="stat"><div class="v">${money(stats.balance)}</div><div class="k">Balance owed</div></div>
</div>
<div class="grid-2">
  <div class="card">
    <h3 style="margin-top:0">Pay this affiliate</h3>
    <p class="small">Method: <b>${esc(aff.payout_method || 'not set')}</b><br>Details: <code>${esc(aff.payout_details || 'not set')}</code></p>
    ${stats.balance > 0 ? `<form method="post" action="/admin/affiliates/${aff.id}/payout">
      <div class="row"><div><label>Amount (USD)</label><input type="number" name="amount" step="0.01" min="0.01" value="${stats.balance.toFixed(2)}" required></div>
      <div><label>Reference</label><input type="text" name="reference" maxlength="120" placeholder="Wise / PayPal transaction ID"></div></div>
      <button class="btn btn-small" style="margin-top:10px">Mark as paid</button>
      ${stats.balance < MIN_PAYOUT_USD ? '<p class="small muted" style="margin:8px 0 0">Below the $100 minimum.</p>' : ''}
    </form>` : '<p class="muted small">Nothing owed.</p>'}
  </div>
  <div class="card">
    <h3 style="margin-top:0">Add a conversion by hand</h3>
    <p class="small muted">For a sale you know came from this affiliate but wasn't tracked (e.g. an App Store purchase). It's added as approved.</p>
    <form method="post" action="/admin/affiliates/${aff.id}/manual">
      <div class="row"><div><label>Charge (USD)</label><input type="number" name="amount" step="0.01" min="0" required></div>
      <div><label>Plan</label><select name="interval"><option value="year">Yearly</option><option value="week">Weekly</option><option value="lifetime">Lifetime</option></select></div></div>
      <div class="field" style="margin-top:10px"><label>Note</label><input type="text" name="note" maxlength="200"></div>
      <button class="btn btn-small btn-ghost">Add (commission is calculated)</button>
    </form>
  </div>
</div>
<div class="card" style="margin-top:14px">
  <form method="post" action="/admin/affiliates/${aff.id}/status" class="inline-form">
    <input type="text" name="note" value="${esc(aff.note || '')}" placeholder="Private note about this affiliate" maxlength="300">
    <button class="btn btn-small btn-ghost" name="status" value="${aff.status}">Save note</button>
    ${aff.status === 'active' ? '<button class="btn btn-small btn-bad" name="status" value="blocked">Block (link stops working)</button>' : '<button class="btn btn-small" name="status" value="active">Unblock</button>'}
  </form>
</div>
<h2>Conversions</h2>
${convTable(convs, { showAff: false })}
<h2>Payouts</h2>
<div class="table-wrap"><table><thead><tr><th>Date</th><th>Method</th><th>Reference</th><th class="num">Amount</th></tr></thead><tbody>
${payouts.length ? payouts.map((p) => `<tr><td>${fmtDate(p.created_at)}</td><td>${esc(p.method || '')}</td><td>${esc(p.reference || '')}</td><td class="num">${money(p.amount_usd)}</td></tr>`).join('') : '<tr><td colspan="4" class="muted">None yet.</td></tr>'}
</tbody></table></div>
<h2>Posts they logged</h2>
<div class="table-wrap"><table><thead><tr><th>Date</th><th>URL</th><th>Type</th></tr></thead><tbody>
${posts.length ? posts.map((p) => `<tr><td>${fmtDate(p.created_at)}</td><td><a href="${esc(p.url)}" target="_blank" rel="noopener nofollow">${esc(p.url.slice(0, 80))}</a></td><td>${esc(p.content_type || '')}</td></tr>`).join('') : '<tr><td colspan="3" class="muted">None yet.</td></tr>'}
</tbody></table></div>`;
  return page({ title: `${aff.username} · Admin`, body, admin: true, wide: true });
}

export function adminPayouts({ due, history, msg }) {
  const body = `
<h1 style="margin-top:24px">Payouts</h1>
${flash(msg)}
<p class="muted">Next payout date: <b>${fmtDate(nextPayoutDate().toISOString())}</b>. Affiliates with an approved balance of $100 or more are due. Send the money in Wise, PayPal or Payoneer, then mark it paid here.</p>
<h2>Due now</h2>
<div class="table-wrap"><table><thead><tr><th>Affiliate</th><th>Method</th><th>Details</th><th class="num">Balance</th><th></th></tr></thead><tbody>
${due.length ? due.map((r) => `<tr><td><a href="/admin/affiliates/${r.id}">${esc(r.username)}</a><br><span class="small muted">${esc(r.email)}</span></td><td>${esc(r.payout_method || 'not set')}</td><td><code>${esc(r.payout_details || '')}</code></td><td class="num"><b>${money(r.balance)}</b></td>
<td><form method="post" action="/admin/affiliates/${r.id}/payout" class="inline-form"><input type="hidden" name="amount" value="${r.balance.toFixed(2)}"><input type="text" name="reference" placeholder="Transaction ID" maxlength="120" style="min-width:160px"><button class="btn btn-small">Mark paid</button></form></td></tr>`).join('') : '<tr><td colspan="5" class="muted">No one is over $100 yet.</td></tr>'}
</tbody></table></div>
<h2>History</h2>
<div class="table-wrap"><table><thead><tr><th>Date</th><th>Affiliate</th><th>Method</th><th>Reference</th><th class="num">Amount</th></tr></thead><tbody>
${history.length ? history.map((p) => `<tr><td>${fmtDate(p.created_at)}</td><td><a href="/admin/affiliates/${p.affiliate_id}">${esc(p.username)}</a></td><td>${esc(p.method || '')}</td><td>${esc(p.reference || '')}</td><td class="num">${money(p.amount_usd)}</td></tr>`).join('') : '<tr><td colspan="5" class="muted">No payouts yet.</td></tr>'}
</tbody></table></div>`;
  return page({ title: 'Payouts · Admin', body, admin: true, active: 'payouts', wide: true });
}

export function adminSettings({ msg, kind }) {
  const body = `
<h1 style="margin-top:24px">Settings</h1>
${flash(msg, kind)}
<p class="muted">Affiliates are credited only for purchases made on salahalarm.com (Dodo checkout), which are tracked automatically. App Store, Google Play and in-app purchases never count.</p>
<h2>Change admin password</h2>
<form method="post" action="/admin/settings/password" class="card">
  <div class="row"><div><label>Current password</label><input type="password" name="current" required></div><div><label>New password (12+ characters)</label><input type="password" name="next" required minlength="12"></div></div>
  <button class="btn btn-small" style="margin-top:10px">Change password</button>
</form>`;
  return page({ title: 'Settings · Admin', body, admin: true, active: 'settings', wide: true });
}
