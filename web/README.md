# salahalarm.com Android funnel

Cloudflare Worker + static pages for selling the Android app on the web.

| Path | What it is |
|---|---|
| `/get/` | Bio link: Android (web funnel) or iPhone (App Store). Use `salahalarm.com/get/?a=<account>` per social account. |
| `/android/` | Onboarding (same steps as iOS quick start) → Google/email sign-in → paywall → Dodo checkout |
| `/android/welcome/` | Return page after checkout: confirms payment, starts the APK download, install guide |
| `/android/install/` | Install guide for reinstalls |
| `/api/*` | config, profile, checkout, entitlement, portal, Dodo webhook, latest APK |
| `/download/salahalarm.apk` | APK from the `salahalarm-apks` R2 bucket |

Entitlements live in Firestore `entitlements/{uid}` (written only by the Worker with a service
account). The Android app asks `/api/entitlement` with its Firebase ID token.

## Pricing
Country → tier in `src/pricing.js` (t1 $4.99/mo · $29.99/yr, t2 $2.99 · $17.99, t3 $1.99 · $9.99).
Each tier has its own Dodo products, listed in `PRODUCTS` in `wrangler.toml`.

## Setup
1. Firebase console › Authentication › Settings › Authorized domains: add `salahalarm.com`.
   Make sure Google and Email/Password providers are on.
2. Firebase console › Project settings › Service accounts › Generate new private key →
   `wrangler secret put FIREBASE_SERVICE_ACCOUNT` (paste the whole JSON).
3. Dodo: create the products (`DODO_PAYMENTS_API_KEY=... npm run dodo:setup`), put the ids in
   `PRODUCTS`, `wrangler secret put DODO_PAYMENTS_API_KEY`.
4. Dodo › Webhooks: add `https://salahalarm.com/api/webhooks/dodo` (subscription events) →
   `wrangler secret put DODO_WEBHOOK_SECRET`.
5. `wrangler r2 bucket create salahalarm-apks`, then `npm run deploy`.

## Develop
```
npm install
npm test                    # worker unit tests
node test/dev-server.mjs    # whole funnel with fake Firebase/Dodo: http://localhost:8788/get/
node test/e2e.mjs en shots  # click through it in a phone-sized browser
npm run i18n                # rebuild translations (iOS catalogs + i18n/web.json)
```
