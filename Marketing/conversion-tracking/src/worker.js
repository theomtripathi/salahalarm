// Cloudflare Worker for salahalarm.com/go/* (or a go.salahalarm.com subdomain).
// Logs every click to PostHog as `link_clicked`, then 302s to the iOS/Android
// chooser at /get/?a=<slug>. The chooser's iOS button comes back here with
// ?to=ios (logged as `link_ios_store`), which 302s to the App Store campaign
// link so App Analytics still attributes page views and installs to the same ct.
import links from "../data/links.json";
import { classifyAgent, chooserUrl, campaignUrl } from "./links.js";
import { parseChallengePath, challengeTarget } from "./invite.js";

const COOKIE = "sa_vid";

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname === "/c" || url.pathname.startsWith("/c/")) return challenge(request, env, ctx, url);
    const slug = url.pathname.replace(/^\/(go\/)?/, "").replace(/\/+$/, "").toLowerCase();
    const link = links[slug];
    const toStore = url.searchParams.get("to") === "ios";
    const appStore = link ? link.target : env.FALLBACK_URL || "https://apps.apple.com/app/id6758457826";
    const ua = request.headers.get("user-agent") || "";
    const campaign = campaignUrl(url, slug, classifyAgent(ua).os);
    const target = campaign || (toStore ? appStore : chooserUrl(url, link ? slug : null));

    const cookie = request.headers.get("cookie") || "";
    const existing = cookie.match(new RegExp(`${COOKIE}=([\\w-]+)`));
    const visitorId = existing ? existing[1] : crypto.randomUUID();

    if (env.POSTHOG_KEY) {
      const agent = classifyAgent(ua);
      const event = {
        api_key: env.POSTHOG_KEY,
        event: campaign ? "campaign_link_clicked" : toStore ? "link_ios_store" : link ? "link_clicked" : "link_unknown",
        distinct_id: visitorId,
        timestamp: new Date().toISOString(),
        properties: {
          slug,
          ...(link && { kind: link.kind, account: link.account, platform: link.platform,
            format: link.format, video: link.video, hook: link.hook, ct: link.ct }),
          ...agent,
          country: request.cf?.country || null,
          referrer: request.headers.get("referer") || null,
          repeat_visitor: Boolean(existing),
          $process_person_profile: false,
        },
      };
      ctx.waitUntil(fetch(`${env.POSTHOG_HOST || "https://us.i.posthog.com"}/capture/`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(event),
      }).catch(() => {}));
    }

    return new Response(null, {
      status: 302,
      headers: {
        location: target,
        "cache-control": "no-store",
        "set-cookie": `${COOKIE}=${visitorId}; Max-Age=31536000; Path=/; Secure; HttpOnly; SameSite=Lax`,
      },
    });
  },
};

// salahalarm.com/c/* : Ramadan Ready challenge invites (see invite.js).
function challenge(request, env, ctx, url) {
  const ua = request.headers.get("user-agent") || "";
  const agent = classifyAgent(ua);
  const link = parseChallengePath(url.pathname);
  const { target, destination, src } = challengeTarget(url, link, agent.os, env);

  const cookie = request.headers.get("cookie") || "";
  const existing = cookie.match(new RegExp(`${COOKIE}=([\\w-]+)`));
  const visitorId = existing ? existing[1] : crypto.randomUUID();

  if (env.POSTHOG_KEY) {
    const event = {
      api_key: env.POSTHOG_KEY,
      event: link.kind === "invite" ? "challenge_invite_clicked"
        : link.kind === "join" ? "challenge_join_clicked"
        : link.kind === "invite_link" ? "challenge_get_invite_clicked" : "challenge_link_unknown",
      distinct_id: visitorId,
      timestamp: new Date().toISOString(),
      properties: {
        link_kind: link.kind,
        invite_code: link.code || null,
        raw: link.raw || null,
        src,
        destination,
        ...agent,
        country: request.cf?.country || null,
        referrer: request.headers.get("referer") || null,
        repeat_visitor: Boolean(existing),
        $process_person_profile: false,
      },
    };
    ctx.waitUntil(fetch(`${env.POSTHOG_HOST || "https://us.i.posthog.com"}/capture/`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(event),
    }).catch(() => {}));
  }

  return new Response(null, {
    status: 302,
    headers: {
      location: target,
      "cache-control": "no-store",
      "set-cookie": `${COOKIE}=${visitorId}; Max-Age=31536000; Path=/; Secure; HttpOnly; SameSite=Lax`,
    },
  });
}
