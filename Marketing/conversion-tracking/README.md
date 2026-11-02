# Per-video conversion tracking

Goal: within 3–4 days of posting, know which content **format** turns views into
App Store page views, installs and trials, across 2 Instagram pages and 10 TikTok
accounts (posted via Zernio).

## The one constraint that shapes everything

Reels and TikToks can't carry a clickable link in the caption. The only links that
get tapped are the **profile bio link**, plus on Instagram **story link stickers**
and **comment-to-DM** replies. So a click can be tied to an *account* exactly, but
to a *video* only by inference.

The answer is to make the experiment design do the work:

1. **During the test, each TikTok account posts one format only** (2 accounts per
   format, see `data/accounts.json`). Then account-level numbers *are*
   format-level numbers, and Apple's own campaign data gives exact installs per
   format with no guessing.
2. Inside an account, installs for a day are split across that day's videos in
   proportion to their profile visits (views if none logged). Good enough to rank hooks.
3. On Instagram, run comment-to-DM ("comment FAJR and I'll send the link", e.g.
   ManyChat) with a **per-video link**, which gives exact per-video clicks.

## Funnel and where each number comes from

| Step | Old app (live now) | New build (once approved) |
|---|---|---|
| Views, likes, shares, profile visits | TikTok / IG analytics, Zernio | same |
| Link clicks | PostHog `link_clicked` from the redirect | same |
| App Store page views | App Store Connect › App Analytics › Campaigns (by `ct`) | same |
| Installs (first-time downloads) | App Analytics › Campaigns (by `ct`) | same + AppsFlyer (already in the new build) |
| Trials / purchases | App Analytics proceeds by campaign, ASC Sales | RevenueCat, joined to AppsFlyer attribution |

Notes:
- Apple attributes page views and installs to a campaign when the user lands via
  `apps.apple.com/app/apple-store/id…?pt=…&ct=…`. Data shows up after roughly a day
  and very small counts are hidden for privacy, so judge formats on totals of a few
  days, not single videos.
- The new build already ships AppsFlyer (+ RevenueCat link) and PostHog. When it is
  live, switching the redirect target to an AppsFlyer OneLink carrying the same
  `ct` adds install → trial → paid per link inside RevenueCat/AppsFlyer.

## Search uplift and early scores

Most TikTok-driven installs come through App Store Search (people close TikTok and
search), not the bio link. The sheet's **Search** tab logs App Store Search installs
per territory against a 14-day pre-test **Baseline**; uplift ÷ views gives installs
per 1k views the bio links miss. Keep all format-test accounts on the same
language and markets so the uplift is comparable, and have each video's end card
say "search Salah Alarm on the App Store".

Early scores, available within hours: **profile-view rate** (profile visits ÷ views)
first, **(shares + saves) per 1k views** second. Likes are ignored. After ~4 days,
check on the Formats tab that they rank formats the same way installs do.

## Link naming scheme

```
account ids   ig1 ig2 tt01 … tt10
format keys   whatif anim alarm pov ramadan mixed
video_id      <account>-<MMDD>-<n>             tt03-1024-2
bio link      salahalarm.com/go/<account>       salahalarm.com/go/tt03
video link    salahalarm.com/go/v/<video_id>    salahalarm.com/go/v/ig1-1024-1
Apple ct      <account>-<format>-bio            tt03-anim-bio
              <account>-<format>-<MMDD>-<n>     ig1-alarm-1024-1   (≤ 40 chars)
```

Every `ct` starts with the account id and carries the format, so App Analytics
can be filtered by either. If an account changes format after the test, change
`testFormat` and the bio `ct` changes with it, so old and new data stay separate.

## What's here

- `data/accounts.json`: App Store id, Apple provider token (`pt`), accounts and formats. SEO articles use one account per language (`seo-en` … `seo-ur`); article ids are `seo-<lang>-<short-slug>`, giving `ct` like `seo-en-fajr-tips` and links like `salahalarm.com/go/v/seo-en-fajr-tips`.
- `data/videos.csv`: one row per post (only needed for videos that get their own link).
- `scripts/gen-links.mjs`: builds `data/links.json` (read by the redirect) and
  `data/links.csv` (every short link with its Apple URL).
- `src/worker.js`: Cloudflare Worker for `salahalarm.com/go/*`. Logs a
  `link_clicked` event to PostHog (account, format, video, ct, country, in-app
  browser, bot flag) and 302s to the App Store campaign link. Unknown slugs go to
  the plain App Store page.
- `sheet/conversion-tracker.xlsx`: Accounts, Videos, Daily and a Formats scoreboard.
  Yellow cells are inputs; the rest are formulas. Import into Google Sheets if preferred.

## Setup

1. App Store Connect › App Analytics › Acquisition › Campaigns › *Generate a campaign
   link*: copy the `pt` value into `data/accounts.json`. Fill in the real handles.
2. `npm run links` then `npm test`.
3. Deploy the worker on the domain's Cloudflare zone with route `salahalarm.com/go/*`
   (`wrangler secret put POSTHOG_KEY` with the app's public PostHog project token),
   then `npm run deploy`. If the domain is not on Cloudflare, the same logic fits a
   Vercel/Netlify function.
4. Put each account's `salahalarm.com/go/<account>` in its bio.

## Daily routine (10 minutes)

1. Paste 48h views per video into **Videos**.
2. PostHog: `link_clicked` count broken down by `account` (and `video`) for
   yesterday → **Daily** clicks.
3. App Analytics › Campaigns, yesterday: page views, first-time downloads,
   proceeds per `ct` → **Daily**.
4. RevenueCat / ASC: trials and purchases → **Daily**.
5. Read **Formats**: rank by installs per 10k views and trials per 10k views.
   Call a winner only after ~30 installs per format.
