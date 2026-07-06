# How to Use a Specific Offering (When "Set as Current" is Not Available)

## Quick Fix: Fetch Your New Offering by Identifier

Since you can't find the "Set as Current" option, we'll fetch your new offering directly by its identifier.

## Step 1: Find Your Offering Identifier

1. Go to **RevenueCat Dashboard** → **Offerings**
2. Click on your **new offering**
3. Look at the **URL** in your browser - it will look like:
   ```
   https://app.revenuecat.com/projects/[project-id]/offerings/[OFFERING_IDENTIFIER]
   ```
4. The `[OFFERING_IDENTIFIER]` is what you need (e.g., `default`, `new_offering`, `offering_1`)

**OR**

Look at the offering details page - the identifier is usually shown at the top or in the settings.

## Step 2: Update SubscriptionViewModel.swift

Open: `Ramadan Pro/ViewModels/SubscriptionViewModel.swift`

Find this line (around line 71):
```swift
await revenueCatService.fetchOfferings()
```

**Replace it with:**
```swift
// Replace "YOUR_OFFERING_IDENTIFIER" with your actual offering identifier
await revenueCatService.fetchOfferings(offeringIdentifier: "YOUR_OFFERING_IDENTIFIER")
```

### Examples:

If your offering identifier is `default`:
```swift
await revenueCatService.fetchOfferings(offeringIdentifier: "default")
```

If your offering identifier is `new_offering`:
```swift
await revenueCatService.fetchOfferings(offeringIdentifier: "new_offering")
```

If your offering identifier is `offering_1`:
```swift
await revenueCatService.fetchOfferings(offeringIdentifier: "offering_1")
```

## Step 3: Test

1. **Build and run the app**
2. **Check the console logs** - you should see:
   ```
   📡 RevenueCatService: Looking for specific offering: YOUR_OFFERING_IDENTIFIER
   ✅ RevenueCatService: Found specific offering: YOUR_OFFERING_IDENTIFIER
   ✅ RevenueCatService: Fetched 3 packages from offering:
      - Package ID: $rc_weekly, Product ID: com.ramadanpro.weekly
      - Package ID: $rc_monthly, Product ID: com.ramadanpro.monthly
      - Package ID: $rc_yearly, Product ID: com.ramadanpro.yearly
   ```

## Alternative: Use App Constants

For a cleaner solution, you can add the offering identifier to your app constants:

1. Open `AppConstants.swift` (or create it if it doesn't exist)
2. Add:
   ```swift
   struct RevenueCatConfig {
       static let defaultOfferingIdentifier = "YOUR_OFFERING_IDENTIFIER"
   }
   ```

3. Then in `SubscriptionViewModel.swift`:
   ```swift
   await revenueCatService.fetchOfferings(offeringIdentifier: AppConstants.RevenueCatConfig.defaultOfferingIdentifier)
   ```

This way you can easily change it later without searching through code.

## Still Can't Find Your Offering Identifier?

1. **Check the console logs** when the app runs - it will list all available offerings:
   ```
   📡 RevenueCatService: Total offerings found: 2
      - Offering ID: default, Identifier: default, Package count: 3
      - Offering ID: new_offering, Identifier: new_offering, Package count: 3
   ```

2. Use one of the identifiers shown in the logs

3. **Common identifiers:**
   - `default` (most common)
   - `$default` (with dollar sign)
   - The name you gave it when creating the offering

## Important Notes

- The offering identifier is **case-sensitive**
- Make sure there are **no extra spaces** in the identifier
- After updating the code, **restart the app** completely
- The app will now fetch your specific offering instead of the "current" one
