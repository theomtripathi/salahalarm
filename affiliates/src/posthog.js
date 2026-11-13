// Server-side PostHog events. Affiliate events use the affiliate's email as distinct_id
// so the lifecycle emails (PostHog Workflows) can reach them.
export function capture(env, ctx, event, distinctId, properties = {}, set = null) {
  if (!env.POSTHOG_KEY || !distinctId) return;
  const body = {
    api_key: env.POSTHOG_KEY,
    event,
    distinct_id: distinctId,
    timestamp: new Date().toISOString(),
    properties: { ...properties, ...(set ? { $set: set } : {}), source: 'affiliate-portal' },
  };
  const p = fetch(`${env.POSTHOG_HOST || 'https://us.i.posthog.com'}/capture/`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  }).catch(() => {});
  if (ctx?.waitUntil) ctx.waitUntil(p);
}

export function affiliateSet(env, aff) {
  const base = env.PORTAL_URL || 'https://affiliate.salahalarm.com';
  return {
    email: aff.email,
    affiliate_username: aff.username,
    is_affiliate: true,
    affiliate_dashboard_url: `${base}/dashboard`,
    affiliate_link: `${env.MAIN_SITE || 'https://salahalarm.com'}/${aff.username}`,
    last_activity_at: new Date().toISOString(),
  };
}

// Optional direct email for sign-in links when RESEND_API_KEY is set. Otherwise the
// PostHog event affiliate_login_requested carries the link for the email workflow.
export async function sendLoginEmail(env, to, loginUrl) {
  if (!env.RESEND_API_KEY) return false;
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      from: env.EMAIL_FROM || 'Salah Alarm Affiliates <affiliates@salahalarm.com>',
      to: [to],
      subject: 'Your Salah Alarm Affiliates sign-in link',
      text: `Assalamu alaikum,\n\nTap to sign in to your Salah Alarm Affiliates dashboard:\n${loginUrl}\n\nThe link works once and expires in 30 minutes. If you didn't ask for it, ignore this email.`,
    }),
  }).catch(() => null);
  return Boolean(res?.ok);
}
