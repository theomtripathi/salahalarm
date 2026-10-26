# Salah Alarm daily analytics

One run a day answers three questions:

1. **Is the app turning installs into money?** Onboarding, paywall and offer,
   from PostHog, plus revenue from RevenueCat. A content win is wasted if
   this funnel leaks, so it comes first in the brief.
2. **Which channel is working?** Instagram, TikTok, X, SEO, then clipping and
   ads, each from views to clicks to installs, per 1K views.
3. **What should we clip next?** A growing library of top Muslim-niche and
   faith-app posts (goal: 1,000+), scored and ranked, with our own posts
   scored the same way and joined to real clicks and installs.

Output each day: `reports/<date>.md` (the brief), `reports/dashboard.html`
(same brief as a page), `data/library.csv` (the ranked library, opens in
Sheets), `data/library.json`, `data/latest.json` and `data/channels-history.csv`.

The live funnel is also on the PostHog dashboard
[Daily funnel watch](https://us.posthog.com/project/572656/dashboard/2255900).

## Sources and keys

Every source is optional. A missing key skips that source and the brief lists
it under "Data gaps". Use read-only keys everywhere.

| Source | Gives | Env var | Where to get it |
|---|---|---|---|
| Apify | Other accounts' top posts on TikTok, Instagram, X | `APIFY_TOKEN` | apify.com > Settings > API & Integrations |
| Zernio | Our own posts' views, shares, saves, profile visits | `ZERNIO_API_KEY` | Zernio dashboard > API keys (read-only) |
| PostHog | Funnel, onboarding screens, `/go/` link clicks | `POSTHOG_PERSONAL_API_KEY` | PostHog > Settings > Personal API keys, scope `query:read`, project 572656 |
| Search Console | SEO clicks and impressions per blog language | `GSC_SERVICE_ACCOUNT_JSON` | Google Cloud service account JSON, added as a user on the salahalarm.com property |
| RevenueCat | MRR, revenue, trials, subscriptions | `REVENUECAT_API_KEY`, `REVENUECAT_PROJECT_ID` | RevenueCat > Project settings > API keys > v2 secret key, read-only |
| App Store Connect | Page views and installs per `ct` campaign | CSV in `data/inbox/asc-campaigns.csv` | App Analytics > Acquisition > Campaigns, export |
| ChatGPT / Muse / by hand | Extra posts to check | CSV in `data/inbox/manual.csv`, or a whole batch folder with `npm run import -- <folder>` | See `prompts/discovery.md` |

To make posts map to accounts (tt01, ig1…), put each account's real handle in
`config/accounts.json` (same file as the conversion tracker), or add
`"zernioAccountId"`.

## Research batches from ChatGPT or Muse

ChatGPT saves batches on Om's Mac under `~/Documents/Salah Alarm/Content Library/<date>/`
(a `manifest.json` per folder, plus the downloaded media). Import one with:

```
npm run import -- "<batch folder>" --mac-root "/Users/pc/Documents/Salah Alarm/Content Library/<date>"
```

Every post comes in as `unverified` (its counts were read off the app by an
assistant), keeps the path to its downloaded file and ChatGPT's adaptation
note, and is re-read by the scraper on the next discovery run. The downloaded
media are research references: rights to repost aren't established, so we
remake the idea rather than reupload.

## How posts are scored

Per post, in order of weight:

- **Outlier:** views ÷ followers. A 2K-follower account getting 438K views
  (qadajourney) is a better template than a 4M-follower account getting 3M.
- **Pass-on rate:** (shares + saves) ÷ views. Likes are cheap; shares and saves
  are what the algorithm rewards and what predicts a format will travel.
- **Reach:** log of views.
- **App promo bonus:** the post sells an app (ours, Just Pray, Prayr, Muslim
  Pro…). These are the closest templates for converting content.
- A small bonus for posts under 14 days old.

A post enters the library if it has 50K+ views on TikTok (30K on Instagram
and X), or 10K+ views with 20× its followers, or 10K+ views and promotes an
app. Posts older than 180 days are left out. Each post gets format tags
(whatif, pov, dayx, alarm, hadith, quran, dua, list, ramadan, skit, carousel,
reminder) from its caption, so the library can be filtered by the formats in
the content plan.

Statuses in `library.json`: `new` → set to `queued`, `clipped` or `rejected`
by hand (or by the clipping workflow later). The "Clip next" list only shows
`new` posts.

## Funnel alerts

Last 7 full days against the 7 before, raised only with 15+ people in a step:

- Onboarding completion under 60%, reaching the paywall under 55%, tapping buy
  under 15% of paywall views, finishing checkout under 35% of buy taps,
  install-to-paid under 2%, or any of these falling 25%+ week on week.
- More than 60% of buy taps cancelled on Apple's payment sheet.
- 3+ real purchase errors (not cancels).
- No purchases at all from 30+ installs.
- The final discount offer never shown.
- An onboarding screen losing 8%+ (amber) or 15%+ (red) of people.

## Run it

```
npm test
APIFY_TOKEN=… ZERNIO_API_KEY=… POSTHOG_PERSONAL_API_KEY=… npm run daily
npm run daily -- --no-discovery   # skip Apify for a cheap run
```

Node 20+, no dependencies.

`.github/workflows/daily-analytics.yml` runs it every day at 05:00 UTC on
GitHub Actions, expecting this folder at `growth/analytics/` in the repo and
the keys as repository secrets. It saves the library and briefs to a separate
`analytics-data` branch.

## Cost and pace

At the default settings (40 results per hashtag, search and profile) a day is
roughly 1,800 scraped posts. On Apify's pay-per-result scrapers that should
be a few dollars a day; check the actor pricing pages before turning it on, and
lower `perQuery` in `config/sources.json` to spend less. If 15–25% of scraped
posts clear the bar, the library passes 1,000 within the first week. Both
numbers are estimates until the first real runs.

## Extending to clipping and ads

- **Clipping accounts:** give them ids starting with `cl` (cl01, cl02…) in
  `config/accounts.json` and connect them in Zernio. They appear as the
  clipping channel automatically.
- **Ads:** Zernio marks paid posts (`isAd`), and ad account ids starting with
  `ad-` count as ads. Zernio's ads endpoints (Meta, TikTok) can be added as
  another collector for spend, giving cost per install next to organic.
