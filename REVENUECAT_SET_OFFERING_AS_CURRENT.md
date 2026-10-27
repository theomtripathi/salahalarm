# How to Set an Offering as Current in RevenueCat

## Problem: Can't Find "Set as Current" Option

If you don't see the "Set as Current" option in RevenueCat Dashboard, here are alternative methods:

## Method 1: Check Offering List View

1. Go to **RevenueCat Dashboard** → **Offerings**
2. Look at the offerings list/table
3. There should be a **"Current"** column with a checkmark (✓) or star (⭐)
4. Click on the **empty checkbox/star** next to your new offering to make it current
5. Or click the **checkmark** next to the old offering to deselect it first

## Method 2: Edit Offering Details

1. Click on your **new offering** to open its details page
2. Look at the **top of the page** for:
   - A **"Set as Current"** button
   - A **toggle switch** or **checkbox** labeled "Current Offering"
   - A **star icon** (⭐) you can click
3. If you see a **"Settings"** or **"Edit"** button, click it - the option might be there

## Method 3: Project Settings

1. Go to **Project Settings** (gear icon in top right)
2. Look for **"Offerings"** or **"Default Offering"** section
3. There might be a **dropdown** to select the current offering
4. Select your new offering from the dropdown

## Method 4: Use Offering Identifier in Code

If you can't set it as current in the dashboard, you can fetch a specific offering by its identifier:

### Step 1: Find Your Offering Identifier

1. Go to RevenueCat Dashboard → **Offerings**
2. Click on your new offering
3. Look at the URL or the offering details
4. The identifier is usually shown as:
   - **"Offering Identifier"**: `default`, `new_offering`, `offering_1`, etc.
   - Or check the URL: `.../offerings/[IDENTIFIER]`

### Step 2: Update Code to Use Specific Offering

Open `SubscriptionViewModel.swift` and find the `loadAvailablePlans()` method:

**Current code:**
```swift
await revenueCatService.fetchOfferings()
```

**Change to:**
```swift
// Replace "your_offering_identifier" with your actual offering identifier
await revenueCatService.fetchOfferings(offeringIdentifier: "your_offering_identifier")
```

**Example:**
```swift
// If your offering identifier is "default"
await revenueCatService.fetchOfferings(offeringIdentifier: "default")

// Or if it's "new_offering"
await revenueCatService.fetchOfferings(offeringIdentifier: "new_offering")
```

### Step 3: Test

1. Restart the app
2. Check console logs - you should see:
   ```
   📡 RevenueCatService: Looking for specific offering: your_offering_identifier
   ✅ RevenueCatService: Found specific offering: your_offering_identifier
   ```

## Method 5: Contact RevenueCat Support

If none of the above work:

1. The UI might have changed in a recent RevenueCat update
2. Your account might not have permissions to set offerings as current
3. Contact RevenueCat support and ask:
   - "How do I set an offering as the current offering?"
   - "I don't see the 'Set as Current' option in my dashboard"

## Quick Check: Verify Current Offering

To see which offering is currently set as current:

1. Go to RevenueCat Dashboard → **Offerings**
2. Look for an offering with:
   - A **checkmark** (✓)
   - A **star** (⭐)
   - Text saying **"Current"**
   - Highlighted/different background color
3. If your new offering doesn't have any of these, it's not set as current

## Alternative: Delete Old Offering

If you can't set the new offering as current, you can:

1. **Delete or archive the old offering** (if you don't need it)
2. RevenueCat will automatically use the remaining offering
3. **Warning**: Only do this if you're sure you don't need the old offering!

## Still Stuck?

1. **Check RevenueCat Documentation:**
   - [RevenueCat Offerings Guide](https://docs.revenuecat.com/docs/entitlements#offerings)
   - Search for "set current offering" or "make offering current"

2. **Check Your RevenueCat Version:**
   - The UI might look different in newer versions
   - Try updating your browser or clearing cache

3. **Use Code Method (Method 4):**
   - This is the most reliable way if dashboard UI is unclear
   - Just use the offering identifier in code
