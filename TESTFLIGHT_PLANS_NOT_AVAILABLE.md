# TestFlight: "Plans Not Available" / "Package not found" – Troubleshooting Guide

## Why This Happens

RevenueCat **configures** packages in its dashboard, but **products are fetched from Apple** at runtime. When your app calls `Purchases.shared.offerings()`, RevenueCat returns the offering structure, then the SDK asks Apple (StoreKit) for each product. **If Apple can't return a product**, that package is excluded from `availablePackages` — so you get "Package not found for Monthly" even though the Default offering is correct in RevenueCat.

**Root cause:** Products in App Store Connect are missing, incomplete, or misconfigured.

---

## Why It Works on Simulator But Not TestFlight

| Environment | How Products Load | What Can Go Wrong |
|-------------|-------------------|-------------------|
| **Simulator** | StoreKit Configuration file (local) or RevenueCat **sandbox/test** key | Products work immediately – no App Store needed |
| **TestFlight** | Real App Store Connect + RevenueCat **production** key | Products must exist in App Store Connect and be properly configured |

---

## Checklist: Fix "Package not found" on TestFlight

### 1. App Store Connect – In-App Purchases **(Most common fix)**

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → **Your App** (Ramadan Pro) → **Features** → **In-App Purchases** (and **Subscriptions** for the subscription group).
2. Ensure these products exist with **exact** IDs:
   - **Subscriptions:** `com.ramadanpro.weekly`, `com.ramadanpro.monthly`, `com.ramadanpro.yearly`, `com.ramadanpro.yearly.discount`
   - **Sadaq (donations):** `com.ramadanpro.donation.100`, `com.ramadanpro.donation.200`, `com.ramadanpro.donation.500`, `com.ramadanpro.donation.1000`
3. Each product must be:
   - **Auto-Renewable Subscription**
   - Status: **Ready to Submit** (not "Missing Metadata", "Rejected", or "Waiting for Review")
   - In the correct **Subscription Group**
   - Pricing configured
   - **Subscription Duration** set (e.g. 1 week, 1 month, 1 year)
4. **First-time IAPs:** If this is the first time adding IAPs, products must be **submitted with your app version** for review. Add them to the app version in App Store Connect before submitting.

### 2. Paid Applications Agreement

- Go to **Agreements, Tax, and Banking**
- **Paid Applications** agreement must be **Active**
- Banking and tax info must be complete

### 3. RevenueCat – Production Setup

1. **API key**
   - TestFlight uses the **production** key: `appl_BaJqBFgIklXdLcCsXETrogJkcUQ`
   - Ensure this key is correct in your RevenueCat project

2. **App Store Connect integration**
   - RevenueCat Dashboard → **Project Settings** → **Integrations**
   - App Store Connect must be **connected**
   - Shared Secret (or App-Specific Shared Secret) configured

3. **Products in RevenueCat**
   - **Products** tab: `com.ramadanpro.weekly`, `com.ramadanpro.monthly`, `com.ramadanpro.yearly`
   - Product IDs must match App Store Connect exactly

4. **Offerings**
   - An offering named **"Default"** must exist (the app requests `offeringIdentifier: "Default"`)
   - It must be set as **Current Offering**
   - All 3 packages must be added and linked to the correct products

### 4. Bundle ID

- In-App Purchases in App Store Connect are tied to the app’s **Bundle ID**
- Your app uses: `com.Ramadan-Pro`. Confirm the same app in App Store Connect has these In-App Purchases

### 5. Propagation Delay

- New or changed IAPs can take **15–60 minutes** (sometimes longer) to propagate
- After changes, wait and try again

### 6. Sandbox Tester for TestFlight

- Create a **Sandbox Tester** in App Store Connect → **Users and Access** → **Sandbox** → **Testers**
- On the TestFlight device: **Settings → App Store → Sandbox Account** – sign in with the sandbox tester
- TestFlight uses **sandbox** for purchases, but products must still exist in App Store Connect

---

## Quick Debug: Check What’s Failing

1. **RevenueCat logs** (connect device to Mac, run TestFlight build, open Console.app)
   - Look for `Package count: X` — if 0 for Default offering, products failed to load from Apple
   - Look for `Fetched X packages from offering` — if 0, packages are empty (App Store Connect issue)
   - **If Package count is 0:** Products are not loading from App Store → fix App Store Connect

2. **RevenueCat Dashboard – Products tab**
   - If products show **"Could not check"** → see section below

3. **App Store Connect**
   - **Your App** → **In-App Purchases** → each product must be **Ready to Submit**
   - **Agreements, Tax, and Banking** → Paid Applications must be **Active**

---

## Most Common Causes (TestFlight)

1. **Products not in App Store Connect** – Create them under Your App → Features → In-App Purchases
2. **Products not "Ready to Submit"** – Complete all metadata, pricing, subscription group
3. **Paid Applications Agreement** not signed or expired
4. **Products in wrong app** – Ensure IAPs are under the app with Bundle ID `com.Ramadan-Pro`
5. **First-time IAPs not submitted** – Must submit IAPs with the app version for first review
6. **"Default" offering not set as Current** in RevenueCat (you have this)
7. **Product ID mismatch** – Must be exactly `com.ramadanpro.weekly`, `com.ramadanpro.monthly`, `com.ramadanpro.yearly`

---

## Why RevenueCat Shows "Could not check" for All Products

When **every** product (subscriptions and Sadaq donations) shows **"Could not check"** in RevenueCat’s Product catalog, RevenueCat **cannot verify** those products with Apple. That usually means one of the following.

### 1. App Store Connect is not connected to RevenueCat (most common)

RevenueCat needs a live link to App Store Connect to check product status.

- **RevenueCat Dashboard** → **Project settings** (or **Apps & providers**) → select your **iOS app** (e.g. "sonn apps (App Store)").
- Ensure **App Store Connect** is **connected**:
  - You must add an **App Store Connect API key** (e.g. **App Store Connect API** → **Keys** → create a key with **App Manager** or **Admin**, download the **.p8** file once).
  - In RevenueCat: **Apps & providers** → your app → **App Store Connect** → upload the **.p8** file and enter **Key ID**, **Issuer ID**, **Bundle ID**.
- If this integration is missing or the key is expired/revoked, RevenueCat cannot talk to Apple → **"Could not check"** for all products.

### 2. Paid Applications Agreement not active

- **App Store Connect** → **Agreements, Tax, and Banking**.
- **Paid Applications** must be **Active** (banking and tax complete).
- If it’s not, Apple does not expose IAPs properly → RevenueCat cannot check them.

### 3. Products missing or wrong app in App Store Connect

- Products must exist under the **same app** (same Bundle ID) as the one linked in RevenueCat.
- **Subscriptions:** App Store Connect → Your app → **Subscriptions** (subscription group) → `com.ramadanpro.weekly`, `.monthly`, `.yearly`, `.yearly.discount` — each **Ready to Submit**, in a subscription group, with pricing.
- **Sadaq (donations):** Same app → **In-App Purchases** (or **Subscriptions** if you use consumables/non-renewables) → `com.ramadanpro.donation.100`, `.200`, `.500`, `.1000` — each **Ready to Submit** and linked to the app version you use for TestFlight.

### 4. First-time IAPs not submitted with the app version

- The first time you add IAPs, they must be **included in an app version** you submit (and that has a build on TestFlight).
- App Store Connect → Your app → **App Store** tab → select the version (e.g. 1.0) → **In-App Purchases** section → add all subscription and donation products to that version.

### 5. Bundle ID mismatch

- RevenueCat app must use the **exact same Bundle ID** as in App Store Connect (e.g. `com.Ramadan-Pro` or whatever your app uses). If they differ, RevenueCat is checking the wrong app → "Could not check".

---

**Summary:** Fix the **App Store Connect ↔ RevenueCat** connection (API key + correct app/Bundle ID), ensure **Paid Applications** is active, and that all subscription and donation products exist and are **Ready to Submit** and linked to your TestFlight app version. After that, "Could not check" should clear and "product not found" on TestFlight should stop once propagation completes.

---

## If You Use a StoreKit Configuration File

- StoreKit Configuration files are **only used in Xcode/simulator**
- TestFlight and App Store builds **always** use App Store Connect
- You cannot rely on a local StoreKit config for TestFlight
