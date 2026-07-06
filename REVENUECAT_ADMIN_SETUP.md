# RevenueCat Setup Instructions for Ramadan Pro

**Please follow these steps exactly to set up the subscription products for Ramadan Pro.**

---

## Step 1: Create Products (4 Products Required)

Go to **Products** section in RevenueCat Dashboard and create the following products:

### Product 1: Weekly Subscription
- **Product ID**: `com.ramadanpro.weekly`
- **Type**: Subscription
- **Duration**: 1 week
- **Price**: Will be synced from App Store Connect (or set manually: $2.99)
- **Status**: Active

### Product 2: Monthly Subscription
- **Product ID**: `com.ramadanpro.monthly`
- **Type**: Subscription
- **Duration**: 1 month
- **Price**: Will be synced from App Store Connect (or set manually: $5.99)
- **Status**: Active

### Product 3: Yearly Subscription
- **Product ID**: `com.ramadanpro.yearly`
- **Type**: Subscription
- **Duration**: 1 year
- **Price**: Will be synced from App Store Connect (or set manually: $50.00)
- **Status**: Active

### Product 4: Discounted Yearly Subscription (Optional - for promotional offers)
- **Product ID**: `com.ramadanpro.yearly.discount`
- **Type**: Subscription
- **Duration**: 1 year
- **Price**: Will be synced from App Store Connect (or set manually: $30.00)
- **Status**: Active
- **Note**: This is used for the "80% off" promotional offer shown in the app

---

## Step 2: Create Offering (REQUIRED)

Go to **Offerings** section in RevenueCat Dashboard:

1. Click **"+ New Offering"** or **"Create Offering"**
2. **Offering Name**: `Default Offering`
3. **Offering Identifier**: `default` (or leave default)

### Add Packages to the Offering:

Click **"+ Add Package"** for each package below:

#### Package 1: Weekly
- **Package Identifier**: `$rc_weekly` (or `weekly`)
- **Product**: Select `com.ramadanpro.weekly` from dropdown
- Click **Save**

#### Package 2: Monthly
- **Package Identifier**: `$rc_monthly` (or `monthly`)
- **Product**: Select `com.ramadanpro.monthly` from dropdown
- Click **Save**

#### Package 3: Yearly
- **Package Identifier**: `$rc_yearly` (or `yearly`)
- **Product**: Select `com.ramadanpro.yearly` from dropdown
- Click **Save**

#### Package 4: Discounted Yearly (If discount product was created)
- **Package Identifier**: `$rc_yearly_discount` (or `yearly_discount`)
- **Product**: Select `com.ramadanpro.yearly.discount` from dropdown
- Click **Save**

---

## Step 3: Set Offering as Current (CRITICAL!)

**This is the most important step - without this, the app won't work!**

1. After creating the offering and adding all packages
2. Find the **"Set as Current"** button/toggle (usually at the top of the offering page)
3. Click it to make this offering the **active/current offering**
4. Verify it shows as "Current Offering" or has a checkmark/indicator

**The app only fetches the "Current Offering", so this step is mandatory.**

---

## Step 4: Link App Store Connect (Recommended)

1. Go to **Project Settings** → **Integrations**
2. Find **App Store Connect** in the list
3. Click **"Connect"** or **"Link"** button
4. Follow the authentication flow to connect your Apple Developer account
5. RevenueCat will automatically sync products from App Store Connect

**Note**: Make sure the Product IDs in App Store Connect match exactly:
- `com.ramadanpro.weekly`
- `com.ramadanpro.monthly`
- `com.ramadanpro.yearly`
- `com.ramadanpro.yearly.discount` (if using discount product)

---

## Verification Checklist

After setup, please verify:

- [ ] All 4 products created with exact Product IDs listed above
- [ ] 1 offering created named "Default Offering"
- [ ] All packages added to the offering
- [ ] Each package is linked to the correct product
- [ ] Offering is set as "Current Offering"
- [ ] App Store Connect is linked (if applicable)

---

## Product ID Reference (Copy-Paste Ready)

```
com.ramadanpro.weekly
com.ramadanpro.monthly
com.ramadanpro.yearly
com.ramadanpro.yearly.discount
```

**Important**: Product IDs must match EXACTLY (case-sensitive, no spaces, no typos)

---

## Testing

After setup is complete, the app should be able to:
1. Fetch the offering and see all packages
2. Display subscription plans to users
3. Process purchases successfully

If there are any issues, check:
- Offering is set as "Current"
- Product IDs match exactly
- Packages are linked to correct products
- App Store Connect products exist (if linked)

---

## Contact

If you have any questions or need clarification, please contact the development team.

**API Key**: `test_tajeOGblNDJrBdEESJrRzsLNVDS` (already configured in app)

---

## Additional Notes

- The app uses RevenueCat SDK to fetch offerings and process purchases
- Subscription status is automatically synced to Firebase
- The discount product (`com.ramadanpro.yearly.discount`) is optional but recommended for promotional offers
- All products should be active and available for purchase
