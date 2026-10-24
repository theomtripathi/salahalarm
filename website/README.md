# salahalarm.com website and daily SEO pipeline

A static site (no dependencies, Node 20+) with a blog in English, Arabic, Turkish,
Indonesian and Urdu, plus a keyword pipeline modelled on how
[gum](https://github.com/ehmo/gum) is used for SEO: pull keyword data from Google
Keyword Planner, write one article a day for the best open keyword, then read
Search Console positions back and refresh what is close to page one.

```
content/<lang>/<slug>.md     articles (frontmatter + Markdown)
site.config.json             languages, UI strings, App Store id, CTA link pattern
static/                      css, icons (copied to dist/)
scripts/build.mjs            builds dist/: home, /blog/<lang>/, articles, sitemap.xml, robots.txt
seo/data/keywords.csv        the keyword plan: one row per target keyword
seo/data/ideas.csv           new ideas from Keyword Planner (created by the import)
seo/gum/*.sh                 gum calls: keyword metrics, rankings, sitemap submit
seo/scripts/                 pick-next, import-keyword-metrics, rank-report
seo/ARTICLE_BRIEF.md         how every article is written
```

## Commands

```bash
npm run build          # published articles only -> dist/
npm run build:drafts   # include drafts, for preview
npm test
npm run next           # which keyword to write today (also syncs status from content/)
npx serve dist         # or: python3 -m http.server -d dist
```

The build fails if an article breaks the rules in `scripts/build.mjs`
(`validate`): missing fields, title over 70 chars, description outside
70-165 chars, title not containing the keyword, under 600 words.

## Every article page gets

- A CTA block after the first section and at the end, linking to
  `salahalarm.com/go/seo-<lang>?from=<slug>`. The `/go/*` Worker (owned by the
  conversion tracking setup in `Marketing/conversion-tracking`) logs the click to
  PostHog and redirects to the App Store with campaign token `ct=seo-<lang>-bio`,
  so App Store Connect shows installs per language.
- Apple's Smart App Banner (`apple-itunes-app` meta), so Safari on iPhone shows an
  "Open / Get" bar at the top of every page.
- `Article`, `MobileApplication` and `FAQPage` JSON-LD, canonical URL, Open Graph,
  `hreflang` alternates for translations (`translationKey` in frontmatter), and an
  entry in `sitemap.xml`.
- Correct `dir="rtl"` for Arabic and Urdu.

## Daily routine (about 20 minutes with Claude writing the draft)

1. `npm run next` picks the keyword. It scores manual priority, Keyword Planner
   volume and competition (once pulled), and urgency for seasonal keywords:
   Ramadan 2027 is expected to start on 8 February 2027, so Ramadan pages carry a
   `deadline` in December and climb the list as it approaches.
2. Write `content/<lang>/<slug>.md` following `seo/ARTICLE_BRIEF.md`.
3. Checks before publishing (Om chose auto-publish, no manual review):
   `npm test` and `npm run build` pass; every hadith reference is one we are sure
   of; Ramadan/Eid dates say "expected"; app claims match real features; the
   non-English text reads natively. If any check is in doubt, leave
   `status: draft` and flag it to Om instead of publishing.
4. Set `status: published`, commit and push. Cloudflare Pages rebuilds on push.
5. `seo/gum/submit-sitemap.sh`.

Weekly: `seo/gum/pull-rankings.sh` (Search Console positions written back into
`keywords.csv`, plus a list of page-two queries worth refreshing) and, monthly,
`seo/gum/pull-keyword-metrics.sh` (volumes and new ideas).

## One-time setup

### Cloudflare Pages

Create a Pages project from this repo: root directory `website`, build command
`npm run build`, output directory `dist`, Node 20. Attach `salahalarm.com`. The
`/go/*` Worker route takes precedence over Pages for those paths, so the two
coexist on one domain.

### Google Search Console

Add a **Domain** property for `salahalarm.com` (DNS TXT record in Cloudflare),
then submit `https://salahalarm.com/sitemap.xml` once by hand.

### gum

```bash
curl -fsSL https://raw.githubusercontent.com/ehmo/gum/main/install.sh | bash
# Google Cloud project -> enable Search Console API and Google Ads API ->
# OAuth consent screen (add yourself as test user) -> OAuth client "Desktop app"
printf '%s' "$CLIENT_SECRET" | gum auth use-oauth-client --client-id "$CLIENT_ID" --secret-stdin
gum login --service searchconsole
# Keyword Planner needs a Google Ads account (no spend required) and a developer token
printf '%s' "$ADS_DEV_TOKEN" | gum auth use-ads-developer-token --stdin
gum login --service googleads
export GOOGLE_ADS_CUSTOMER_ID=1234567890
gum doctor
```

All pipeline calls are read-only except `submit-sitemap.sh` (a write gated by
`--allow-write`).
