# RevenueCat Payment Flow Setup

This guide explains how to set up and use the RevenueCat payment integration in Ramadan Pro.

## ✅ What's Been Implemented

1. **RevenueCatService** (`Services/RevenueCatService.swift`)
   - Handles all RevenueCat operations (purchases, restore, status checks)
   - Syncs subscription status with Firebase
   - Converts RevenueCat packages to app's subscription models

2. **SubscriptionViewModel** (`ViewModels/SubscriptionViewModel.swift`)
   - Updated to use RevenueCatService
   - Loads available plans from RevenueCat
   - Processes purchases via RevenueCat
   - Restores previous purchases

3. **Paywall Views**
   - `MainPaywallScreenView.swift` - Main paywall with plan selection
   - `DelayedDiscountPaywallScreenView.swift` - Discounted yearly plan offer
   - Both views now use RevenueCat for purchases

4. **App Initialization**
   - RevenueCat is initialized in `Ramadan_ProApp.swift`
   - User ID is set when user logs in
   - Subscription status is checked and synced with Firebase

## 🔧 Setup Steps

### 1. Get Your RevenueCat API Key

1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Create a new project or select your existing project
3. Navigate to **Project Settings** → **API Keys**
4. Copy your **Public API Key** (starts with `rcbw_` or `appl_`)

### 2. Add API Key to Info.plist

1. Open `Ramadan-Pro-Info.plist` in Xcode
2. Add a new key-value pair:
   - **Key**: `RevenueCatAPIKey`
   - **Type**: String
   - **Value**: Your RevenueCat API key (e.g., `appl_xxxxxxxxxxxxx`)

### 3. Configure Products in RevenueCat Dashboard

**IMPORTANT: You MUST create products in RevenueCat with these exact Product IDs:**

1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Navigate to **Products** in the left sidebar
3. Click **+ New** or **Add Product**
4. Create **3 products** with these **exact Product IDs**:

   **Product 1: Weekly Subscription**
   - **Product ID**: `com.ramadanpro.weekly`
   - **Type**: Subscription
   - **Duration**: 1 week
   - **Price**: Set to match your App Store Connect price (e.g., $2.99)

   **Product 2: Monthly Subscription**
   - **Product ID**: `com.ramadanpro.monthly`
   - **Type**: Subscription
   - **Duration**: 1 month
   - **Price**: Set to match your App Store Connect price (e.g., $5.99)

   **Product 3: Yearly Subscription**
   - **Product ID**: `com.ramadanpro.yearly`
   - **Type**: Subscription
   - **Duration**: 1 year
   - **Price**: Set to match your App Store Connect price (e.g., $50.00)

5. **Save each product** after creating it

### 4. Create Offerings in RevenueCat

**This is CRITICAL - the app fetches offerings, not individual products:**

1. In RevenueCat Dashboard, go to **Offerings** in the left sidebar
2. Click **+ New Offering** or **Create Offering**
3. Name it: **"Default Offering"** (or any name you prefer)
4. **Add Packages** to this offering:
   - Click **+ Add Package**
   - For each package:
     - **Package Identifier**: You can use `$rc_weekly`, `$rc_monthly`, `$rc_yearly` (or any identifier)
     - **Product**: Select the corresponding product you created:
       - `$rc_weekly` → Select `com.ramadanpro.weekly`
       - `$rc_monthly` → Select `com.ramadanpro.monthly`
       - `$rc_yearly` → Select `com.ramadanpro.yearly`
   - Click **Save Package**
5. **Set as Current Offering**:
   - After creating the offering, find the toggle/button that says **"Set as Current"** or **"Make Current"**
   - Click it to make this offering the active one
   - **This is essential** - the app only fetches the "Current Offering"

### 5. Verify Your Setup

After creating products and offerings, verify:
- ✅ 3 products created with correct Product IDs
- ✅ 1 offering created with all 3 packages
- ✅ Offering is set as "Current Offering"
- ✅ Each package is linked to the correct product

### 5. Set Up App Store Connect Products

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your app → **Features** → **In-App Purchases**
3. Create three auto-renewable subscriptions:
   - Product ID: `com.ramadanpro.weekly`
   - Product ID: `com.ramadanpro.monthly`
   - Product ID: `com.ramadanpro.yearly`
4. Set pricing and subscription groups
5. Submit for review

### 6. Set Up Discount/Promotional Offers

**For the discounted yearly plan ($50 → $30, 80% off):**

You have two approaches:

#### Option A: Create a Separate Discounted Product (Simpler)

1. **In RevenueCat Dashboard:**
   - Go to **Products** → Create new product
   - **Product ID**: `com.ramadanpro.yearly.discount`
   - **Type**: Subscription
   - **Duration**: 1 year
   - **Price**: $30.00

2. **In Offerings:**
   - Edit your "Default Offering"
   - Add package: `$rc_yearly_discount` → Link to `com.ramadanpro.yearly.discount`

3. **In App Store Connect:**
   - Create subscription product: `com.ramadanpro.yearly.discount`
   - Set price to $30.00
   - Add to same subscription group

#### Option B: Use App Store Promotional Offers (More Flexible)

1. **In App Store Connect:**
   - Go to your yearly product (`com.ramadanpro.yearly`)
   - Click **"Subscription Offers"** → **"Promotional Offers"**
   - Create offer:
     - **Reference Name**: "Ramadan 80% Off"
     - **Offer Code**: `RAMADAN80` (or generate one)
     - **Price**: $30.00
     - **Duration**: 1 year
     - **Eligibility**: Set criteria (e.g., new subscribers only)
   - Submit for review

2. **In RevenueCat:**
   - If linked to App Store Connect, promotional offers sync automatically
   - You can present them using RevenueCat's promotional offer methods

**Note**: Update `DelayedDiscountPaywallScreenView` to use the discounted product ID or promotional offer code when implementing purchases.

### 7. Link RevenueCat with App Store Connect

1. In RevenueCat Dashboard, go to **Project Settings** → **Integrations**
2. Click **Connect** next to App Store Connect
3. Follow the authentication flow
4. RevenueCat will automatically sync your products and promotional offers

## 📱 How It Works

### Purchase Flow

1. User selects a plan on the paywall
2. App calls `SubscriptionViewModel.purchasePlan()`
3. RevenueCatService processes the purchase via RevenueCat
4. RevenueCat handles the StoreKit purchase flow
5. On success:
   - Subscription status is updated locally
   - Subscription is synced to Firebase
   - User is granted access to premium features

### Restore Purchases

- Users can restore purchases via `SubscriptionViewModel.restorePurchases()`
- This checks RevenueCat for active subscriptions
- Updates local status and syncs with Firebase

### Subscription Status Sync

- When user logs in, RevenueCat user ID is set
- Subscription status is checked and synced to Firebase
- Firebase stores subscription status in the `users` collection under `subscriptionStatus`

## 🔍 Testing

### Sandbox Testing

1. Create a sandbox tester account in App Store Connect
2. Sign out of App Store on your device
3. Run the app and attempt a purchase
4. Sign in with the sandbox tester account when prompted
5. Complete the purchase flow

### Debug Logging

RevenueCat logging is enabled in debug mode. Check the console for:
- `🔧 RevenueCatService:` - Configuration and initialization
- `📡 RevenueCatService:` - API calls
- `✅ RevenueCatService:` - Success messages
- `❌ RevenueCatService:` - Error messages
- `⚠️ RevenueCatService:` - Warnings

## 📝 Important Notes

1. **Product IDs**: Must match exactly between App Store Connect, RevenueCat, and the code
2. **User ID**: RevenueCat user ID should match Firebase Auth user ID for proper sync
3. **API Key**: Keep your API key secure - never commit it to version control
4. **Testing**: Always test purchases in sandbox mode before going live
5. **Firebase Sync**: Subscription status is automatically synced to Firebase after purchase/restore

## 🐛 Troubleshooting

### "No packages found"
- Check that offerings are configured in RevenueCat Dashboard
- Ensure "Current Offering" is set
- Verify product IDs match exactly

### "Purchase failed"
- Check RevenueCat dashboard for error logs
- Verify products are configured in App Store Connect
- Ensure sandbox tester account is set up correctly

### "User ID not set"
- Check that Firebase Auth is working
- Verify user is logged in before attempting purchase
- Check console logs for RevenueCat user ID errors

## 💰 Custom Donation Amounts Setup

The app supports custom donation amounts through RevenueCat consumable products. Users can donate any amount ($100, $500, $1000, or a custom amount).

### Setting Up Donation Products

1. **In RevenueCat Dashboard:**
   - Go to **Products** → Click **+ New** or **Add Product**
   - Create **consumable products** (not subscriptions) for common donation amounts:
   
   **Product IDs Pattern:**
   - `com.ramadanpro.donation.100` - $100 donation
   - `com.ramadanpro.donation.500` - $500 donation
   - `com.ramadanpro.donation.1000` - $1000 donation
   - `com.ramadanpro.donation.2500` - $2500 donation
   - `com.ramadanpro.donation.5000` - $5000 donation
   - `com.ramadanpro.donation.10000` - $10000 donation
   
   **For each product:**
   - **Type**: Consumable
   - **Price**: Set to match the donation amount (e.g., $100.00)
   - **Product ID**: Must follow pattern `com.ramadanpro.donation.{amount}`

2. **In App Store Connect:**
   - Go to your app → **Features** → **In-App Purchases**
   - Create **Consumable** products (not subscriptions)
   - Product IDs must match exactly: `com.ramadanpro.donation.100`, `com.ramadanpro.donation.500`, etc.
   - Set prices to match the donation amounts
   - Submit for review

3. **Add Donation Products to RevenueCat Offering:**
   - Go to **Offerings** in RevenueCat Dashboard
   - Edit your "Default Offering" (or create a "Donations Offering")
   - Click **+ Add Package**
   - For each donation amount:
     - **Package Identifier**: `$rc_donation_{amount}` (e.g., `$rc_donation_100`)
     - **Product**: Select the corresponding consumable product (e.g., `com.ramadanpro.donation.100`)
   - Click **Save Package** for each
   - **Set as Current Offering** if using a separate donations offering

### How Custom Amounts Work

1. **Predefined Amounts ($100, $500, $1000):**
   - These use existing consumable products in RevenueCat
   - Payment is processed immediately via RevenueCat/StoreKit
   - Transaction is recorded in Firebase

2. **Custom Amounts:**
   - When a user enters a custom amount, the app looks for a product ID: `com.ramadanpro.donation.{amount}`
   - If the product exists in RevenueCat, it processes the payment
   - If the product doesn't exist, it falls back to direct Firebase donation (for testing/development)
   - **Note**: For production, you should create products for common custom amounts (e.g., $50, $200, $250, $750, etc.)

### Recommended Donation Products

Create consumable products for these common amounts to support most user donations:

- $50 - `com.ramadanpro.donation.50`
- $100 - `com.ramadanpro.donation.100`
- $200 - `com.ramadanpro.donation.200`
- $250 - `com.ramadanpro.donation.250`
- $500 - `com.ramadanpro.donation.500`
- $750 - `com.ramadanpro.donation.750`
- $1000 - `com.ramadanpro.donation.1000`
- $2500 - `com.ramadanpro.donation.2500`
- $5000 - `com.ramadanpro.donation.5000`
- $10000 - `com.ramadanpro.donation.10000`

### Testing Donations

1. Create sandbox tester accounts in App Store Connect
2. Sign out of App Store on your device
3. Run the app and attempt a donation
4. Sign in with the sandbox tester account when prompted
5. Complete the purchase flow
6. Verify the donation appears in Firebase

### Important Notes

- **Consumable Products**: Donations use consumable products, not subscriptions
- **Product ID Pattern**: Must follow `com.ramadanpro.donation.{amount}` format
- **Fallback Behavior**: If a product doesn't exist, the app falls back to direct Firebase donation (useful for testing)
- **Transaction IDs**: RevenueCat provides transaction IDs for successful purchases
- **Firebase Sync**: All donations are saved to Firebase regardless of payment method

## 📚 Resources

- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [RevenueCat iOS SDK](https://github.com/RevenueCat/purchases-ios)
- [App Store Connect Guide](https://developer.apple.com/app-store-connect/)
- [RevenueCat Consumable Products](https://docs.revenuecat.com/docs/entitlements#consumables)
