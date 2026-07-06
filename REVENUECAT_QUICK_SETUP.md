# RevenueCat Quick Setup Guide

## Step-by-Step: What to Add in RevenueCat Dashboard

### Step 1: Create Products (3 products needed)

1. Go to https://app.revenuecat.com
2. Select your project
3. Click **"Products"** in the left menu
4. Click **"+ New"** or **"Add Product"**

**Create Product 1:**
- **Product ID**: `com.ramadanpro.weekly`
- **Type**: Subscription
- **Duration**: 1 week
- Click **Save**

**Create Product 2:**
- **Product ID**: `com.ramadanpro.monthly`
- **Type**: Subscription
- **Duration**: 1 month
- Click **Save**

**Create Product 3:**
- **Product ID**: `com.ramadanpro.yearly`
- **Type**: Subscription
- **Duration**: 1 year
- Click **Save**

### Step 2: Create an Offering (Required!)

1. Click **"Offerings"** in the left menu
2. Click **"+ New Offering"** or **"Create Offering"**
3. Name: `Default Offering`
4. Click **"Add Package"**

**Add Package 1:**
- **Package Identifier**: `$rc_weekly` (or `weekly`)
- **Product**: Select `com.ramadanpro.weekly` from dropdown
- Click **Save**

**Add Package 2:**
- **Package Identifier**: `$rc_monthly` (or `monthly`)
- **Product**: Select `com.ramadanpro.monthly` from dropdown
- Click **Save**

**Add Package 3:**
- **Package Identifier**: `$rc_yearly` (or `yearly`)
- **Product**: Select `com.ramadanpro.yearly` from dropdown
- Click **Save**

5. **IMPORTANT**: Click the **"Set as Current"** or **"Make Current"** button/toggle
   - This makes the app fetch this offering
   - Without this, the app won't find any packages!

### Step 3: Set Up Discount Offer (For $30 Yearly Plan)

**Your app shows a discounted yearly plan ($50 → $30, 80% off). Here's how to set it up:**

#### Option A: Create Separate Discounted Product (Recommended)

1. In RevenueCat Dashboard → **"Products"**
2. Create a **4th product**:
   - **Product ID**: `com.ramadanpro.yearly.discount`
   - **Type**: Subscription
   - **Duration**: 1 year
   - **Price**: $30.00
   - Click **Save**

3. In **"Offerings"** → Edit "Default Offering"
4. Add **Package 4**:
   - **Package Identifier**: `$rc_yearly_discount`
   - **Product**: Select `com.ramadanpro.yearly.discount`
   - Click **Save**

5. In App Store Connect:
   - Create subscription: `com.ramadanpro.yearly.discount`
   - Price: $30.00
   - Duration: 1 year
   - Add to same subscription group

**The app will automatically use this discounted product when user clicks "Unlock for $30"**

#### Option B: Use Promotional Offer (More Flexible)

1. In App Store Connect → Your yearly product (`com.ramadanpro.yearly`)
2. Go to **"Subscription Offers"** → **"Promotional Offers"**
3. Click **"+ Create Promotional Offer"**
4. Fill in:
   - **Reference Name**: "Ramadan 80% Off"
   - **Offer Code**: `RAMADAN80` (or let Apple generate)
   - **Duration**: 1 year
   - **Price**: $30.00
   - **Eligibility**: New subscribers only (or your preference)
5. Save and submit for review

**Note**: Promotional offers require code implementation changes. Option A is simpler.

### Step 4: Link App Store Connect (Optional but Recommended)

1. Go to **"Project Settings"** → **"Integrations"**
2. Click **"Connect"** next to App Store Connect
3. Follow the authentication flow
4. RevenueCat will sync your products automatically

### Step 4: Create Products in App Store Connect

**You also need to create these in App Store Connect:**

1. Go to https://appstoreconnect.apple.com
2. Select your app → **"Features"** → **"In-App Purchases"**
3. Click **"+ Create"** → **"Auto-Renewable Subscription"**

**Create Subscription Group:**
- Name: "Ramadan Pro Subscriptions" (or any name)
- Reference Name: "Ramadan Pro"

**Create Product 1:**
- **Product ID**: `com.ramadanpro.weekly`
- **Subscription Duration**: 1 week
- **Price**: Set your price (e.g., $2.99)
- **Localizations**: Add display name and description
- Save

**Create Product 2:**
- **Product ID**: `com.ramadanpro.monthly`
- **Subscription Duration**: 1 month
- **Price**: Set your price (e.g., $5.99)
- Save

**Create Product 3:**
- **Product ID**: `com.ramadanpro.yearly`
- **Subscription Duration**: 1 year
- **Price**: Set your price (e.g., $50.00)
- Save

**Add all 3 products to the same subscription group**

### Step 5: Create Products in App Store Connect

**You also need to create these in App Store Connect:**

1. Go to https://appstoreconnect.apple.com
2. Select your app → **"Features"** → **"In-App Purchases"**
3. Click **"+ Create"** → **"Auto-Renewable Subscription"**

**Create Subscription Group:**
- Name: "Ramadan Pro Subscriptions" (or any name)
- Reference Name: "Ramadan Pro"

**Create Product 1:**
- **Product ID**: `com.ramadanpro.weekly`
- **Subscription Duration**: 1 week
- **Price**: Set your price (e.g., $2.99)
- **Localizations**: Add display name and description
- Save

**Create Product 2:**
- **Product ID**: `com.ramadanpro.monthly`
- **Subscription Duration**: 1 month
- **Price**: Set your price (e.g., $5.99)
- Save

**Create Product 3:**
- **Product ID**: `com.ramadanpro.yearly`
- **Subscription Duration**: 1 year
- **Price**: Set your price (e.g., $50.00)
- Save

**Create Product 4 (If using Option A for discount):**
- **Product ID**: `com.ramadanpro.yearly.discount`
- **Subscription Duration**: 1 year
- **Price**: $30.00
- Save

**Add all products to the same subscription group**

### Step 6: Test

After setting up:
1. Run your app
2. Check console logs - you should see:
   - `✅ RevenueCatService: Fetched 3 packages` (or 4 if discount product added)
   - `✅ SubscriptionViewModel: Loaded 3 plans: ["weekly", "monthly", "yearly"]`
3. Try purchasing a plan from main paywall
4. Try purchasing discounted plan from delayed discount paywall

## Troubleshooting

**If you see "Plan not found":**
- ✅ Check that products are created with EXACT Product IDs: `com.ramadanpro.weekly`, `com.ramadanpro.monthly`, `com.ramadanpro.yearly`
- ✅ Check that an offering is created and set as "Current Offering"
- ✅ Check that packages in the offering are linked to the correct products
- ✅ Check console logs to see what product IDs are being fetched

**If you see "No packages found":**
- ✅ Make sure an offering is set as "Current Offering"
- ✅ Make sure packages are added to the offering
- ✅ Make sure products exist and are linked to packages

**Product IDs MUST match exactly:**
- RevenueCat: `com.ramadanpro.weekly`
- App Store Connect: `com.ramadanpro.weekly`
- Code expects: `com.ramadanpro.weekly`

All three must be identical!
