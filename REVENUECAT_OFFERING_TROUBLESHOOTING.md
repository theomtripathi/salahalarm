# RevenueCat Offering Troubleshooting

## Problem: App is Getting Old Offering Instead of New One

If you've created a new offering in RevenueCat but the app is still showing the old offering, follow these steps:

## ✅ Step 1: Set New Offering as "Current Offering"

**This is the most common issue!**

### Method 1: Using RevenueCat Dashboard (Recommended)

1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Navigate to **Offerings** in the left sidebar
3. You should see a list of all offerings
4. Look for your **new offering** in the list
5. **Check the "Current" column** - there should be a checkmark or star next to one offering
6. To set a new offering as current:
   - **Option A**: Click the **three dots (⋯)** or **menu icon** next to your offering
   - **Option B**: Click directly on your offering to open it, then look for:
     - A **"Set as Current"** button at the top
     - A **toggle switch** labeled "Current Offering"
     - A **star icon** or **checkmark** you can click
   - **Option C**: In the offerings list, there might be a **radio button** or **checkbox** in a "Current" column
7. **Wait 1-2 minutes** for the change to propagate

### Method 2: If "Set as Current" Option is Not Visible

If you can't find the "Set as Current" option, try these:

1. **Check if you have the right permissions:**
   - Make sure you're logged in as an admin/owner of the RevenueCat project
   - Only admins can set offerings as current

2. **Look in Project Settings:**
   - Go to **Project Settings** → **Offerings**
   - There might be a dropdown to select the current offering

3. **Use the Offering Identifier:**
   - Note down your new offering's **identifier** (e.g., "default", "new_offering", etc.)
   - The app can be configured to fetch a specific offering by identifier
   - See "Method 3" below for code changes

### Method 3: Fetch Specific Offering by Identifier (Code Solution)

If you can't set it as current in the dashboard, you can modify the app to fetch your specific offering:

1. Note your new offering's **identifier** from RevenueCat Dashboard
2. Update the code to fetch that specific offering (see code changes below)

## ✅ Step 2: Verify Product IDs in RevenueCat

The app expects these exact product IDs:

- `com.ramadanpro.weekly` - Weekly subscription
- `com.ramadanpro.monthly` - Monthly subscription  
- `com.ramadanpro.yearly` - Yearly subscription

**Check your products:**

1. Go to **Products** in RevenueCat Dashboard
2. Verify each product has the correct Product ID:
   - Should be `com.ramadanpro.weekly` (not just "weekly")
   - Should be `com.ramadanpro.monthly` (not just "monthly")
   - Should be `com.ramadanpro.yearly` (not just "yearly")

**If product IDs are wrong:**
- Edit each product
- Update the Product ID to match the expected format
- Save changes

## ✅ Step 3: Verify Packages in Offering

1. Open your **new offering** in RevenueCat Dashboard
2. Check that it has **3 packages**:
   - One for weekly
   - One for monthly
   - One for yearly
3. Each package should be linked to the correct product:
   - Package → Product: `com.ramadanpro.weekly`
   - Package → Product: `com.ramadanpro.monthly`
   - Package → Product: `com.ramadanpro.yearly`

## ✅ Step 4: Clear App Cache and Restart

After making changes in RevenueCat:

1. **Force close the app** completely
2. **Restart the app**
3. The app will fetch fresh offerings from RevenueCat

## ✅ Step 5: Check App Logs

When the app loads the paywall, check the console logs. You should see:

```
📡 RevenueCatService: Fetching offerings...
📡 RevenueCatService: Total offerings found: X
   - Offering ID: [your offering identifier]
✅ RevenueCatService: Current offering found - ID: [your offering identifier]
✅ RevenueCatService: Fetched 3 packages from current offering:
   - Package ID: $rc_weekly, Product ID: com.ramadanpro.weekly
   - Package ID: $rc_monthly, Product ID: com.ramadanpro.monthly
   - Package ID: $rc_yearly, Product ID: com.ramadanpro.yearly
```

**If you see:**
- `⚠️ RevenueCatService: No current offering found!` → Go back to Step 1
- Only 2 packages instead of 3 → Check your offering has all 3 packages
- Wrong product IDs → Go back to Step 2

## ✅ Step 6: Verify App Store Connect Products

Make sure products exist in App Store Connect with matching IDs:

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your app → **Features** → **In-App Purchases**
3. Verify these products exist:
   - `com.ramadanpro.weekly`
   - `com.ramadanpro.monthly`
   - `com.ramadanpro.yearly`
4. All should be **Auto-Renewable Subscriptions**

## 🔍 Common Issues

### Issue 1: Product IDs Show as "monthly" Instead of "com.ramadanpro.monthly"

**Cause:** Product IDs in RevenueCat are set incorrectly

**Fix:**
1. Go to RevenueCat → Products
2. Edit each product
3. Change Product ID from "monthly" to "com.ramadanpro.monthly"
4. Save and wait for sync

### Issue 2: Only 2 Plans Showing (Missing Weekly)

**Cause:** Weekly package/product not added to offering

**Fix:**
1. Go to RevenueCat → Products
2. Verify `com.ramadanpro.weekly` product exists
3. Go to your Offering
4. Add a package for weekly subscription
5. Link it to `com.ramadanpro.weekly` product
6. Set offering as current

### Issue 3: App Still Shows Old Offering After Changes

**Cause:** Offering not set as current, or app cache

**Fix:**
1. Verify new offering is set as "Current Offering" (Step 1)
2. Wait 2-3 minutes for propagation
3. Force close and restart app
4. Check logs to see which offering is being fetched

## 📝 Quick Checklist

Before testing, verify:

- [ ] New offering is set as "Current Offering" in RevenueCat
- [ ] All 3 products exist with correct IDs: `com.ramadanpro.weekly`, `com.ramadanpro.monthly`, `com.ramadanpro.yearly`
- [ ] All 3 packages are added to the offering
- [ ] Each package is linked to the correct product
- [ ] Products exist in App Store Connect with matching IDs
- [ ] App has been restarted after making changes
- [ ] Check console logs to verify correct offering is being fetched

## 🆘 Still Not Working?

1. **Check RevenueCat Dashboard → Project Settings → API Keys**
   - Verify you're using the correct API key
   - Make sure it's the public key (starts with `appl_` or `rcbw_`)

2. **Check RevenueCat Dashboard → Project Settings → Integrations**
   - Verify App Store Connect is connected
   - Products should sync automatically

3. **Test with RevenueCat Debug Mode:**
   - Enable debug logging in the app
   - Check detailed logs for what's being fetched

4. **Contact RevenueCat Support:**
   - If offerings are still not updating after 5+ minutes
   - RevenueCat support can check server-side caching
