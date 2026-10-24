//
//  RevenueCatService.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import Combine
import RevenueCat
import FirebaseAuth
import FirebaseFirestore

/// Service for managing subscriptions via RevenueCat
@MainActor
class RevenueCatService: ObservableObject {
    static let shared = RevenueCatService()
    static let annualTrialOfferingIdentifier = "yearly-trial"
    static let annualTrialProductIdentifier = "yearlydiscountedtrial"
    
    @Published var customerInfo: CustomerInfo?
    @Published var availablePackages: [Package] = []
    @Published private(set) var annualTrialPlan: SubscriptionPlanDetails?
    @Published private(set) var annualTrialUnavailableReason = "Trial offer has not been checked."
    @Published var subscriptionStatus: SubscriptionStatus = SubscriptionStatus()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    // Product IDs mapping
    private let productIds: [SubscriptionPlanType: String] = [
        .weekly: "com.ramadanpro.weekly",
        .monthly: "com.ramadanpro.monthly",
        .yearly: "com.ramadanpro.yearly",
        .lifetime: "com.ramadanpro.lifetime"
    ]
    
    private init() {
        print("🔧 RevenueCatService: Initialized")
    }
    
    // MARK: - Configuration
    
    /// Configure RevenueCat with API key
    /// Call this in app initialization
    /// Debug: uses Test Store key from Info.plist. Release/TestFlight: uses production key.
    static func configure(apiKey: String? = nil) {
        print("🔧 RevenueCatService: Configuring RevenueCat")
        
        let finalAPIKey: String
        if let apiKey = apiKey {
            finalAPIKey = apiKey
        } else {
            #if DEBUG
            // Debug: Test Store key (from Info.plist or fallback)
            if let plistKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String, !plistKey.isEmpty {
                finalAPIKey = plistKey
            } else {
                finalAPIKey = "test_tajeOGblNDJrBdEESJrRzsLNVDS"
            }
            #else
            // Release/TestFlight/App Store: Production key (required - Test key crashes in Release)
            finalAPIKey = "appl_BaJqBFgIklXdLcCsXETrogJkcUQ"
            #endif
        }
        
        Purchases.logLevel = .debug // Use .info or .warn in production
        Purchases.configure(withAPIKey: finalAPIKey)
        
        print("✅ RevenueCatService: RevenueCat configured successfully")
    }

    /// Clear local subscription state (e.g. on logout). Does not call Purchases.logOut.
    func clearSubscriptionState() {
        customerInfo = nil
        subscriptionStatus = SubscriptionStatus(isActive: false)
        availablePackages = []
        annualTrialPlan = nil
        annualTrialUnavailableReason = "Sign in and check trial availability again."
            // Clear subscription status from UserDefaults and App Group (widget)
            UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
            WidgetConfig.saveIsSubscribed(false)
            print("🧹 RevenueCatService: Cleared subscription state from UserDefaults")
    }
    
    /// Set user ID for RevenueCat (should match Firebase Auth user ID)
    func setUserID(_ userID: String) async throws {
        print("👤 RevenueCatService: Setting user ID: \(userID)")
        try await Purchases.shared.logIn(userID)
        print("✅ RevenueCatService: User ID set successfully")
    }
    
    // MARK: - Fetch Offerings
    
    /// Fetch available subscription packages
    /// - Parameter offeringIdentifier: Optional specific offering identifier to fetch. If nil, fetches current offering.
    func fetchOfferings(offeringIdentifier: String? = nil) async {
        isLoading = true
        errorMessage = nil
        annualTrialPlan = nil
        annualTrialUnavailableReason = "Checking trial eligibility…"
        
        do {
            print("📡 RevenueCatService: Fetching offerings...")
            let offerings = try await Purchases.shared.offerings()
            
            // Log all available offerings
            print("📡 RevenueCatService: Total offerings found: \(offerings.all.count)")
            for (key, offering) in offerings.all {
                print("   - Offering ID: \(key), Identifier: \(offering.identifier), Package count: \(offering.availablePackages.count)")
                for package in offering.availablePackages {
                    print("     Package: \(package.identifier) → Product: \(package.storeProduct.productIdentifier)")
                }
            }
            
            var selectedOffering: Offering?
            
            // If specific offering identifier provided, use that
            if let identifier = offeringIdentifier {
                print("📡 RevenueCatService: Looking for specific offering: \(identifier)")
                selectedOffering = offerings.all[identifier] ?? offerings.all.values.first(where: { $0.identifier == identifier })
                
                if let offering = selectedOffering {
                    print("✅ RevenueCatService: Found specific offering: \(offering.identifier)")
                } else {
                    print("⚠️ RevenueCatService: Specific offering '\(identifier)' not found, falling back to current offering")
                }
            }
            
            // If no specific offering or not found, use current offering
            if selectedOffering == nil {
                selectedOffering = offerings.current
            }
            
            if let offering = selectedOffering {
                print("✅ RevenueCatService: Using offering - ID: \(offering.identifier)")
                self.availablePackages = offering.availablePackages.filter {
                    offeringIdentifier != nil
                        || $0.storeProduct.productIdentifier != Self.annualTrialProductIdentifier
                }
                print("✅ RevenueCatService: Fetched \(availablePackages.count) packages from offering:")
                for package in availablePackages {
                    print("   - Package ID: \(package.identifier), Product ID: \(package.storeProduct.productIdentifier), Price: \(package.localizedPriceString)")
                }
            } else {
                print("⚠️ RevenueCatService: No offering found!")
                print("⚠️ RevenueCatService: Available offerings: \(offerings.all.keys.joined(separator: ", "))")
                print("⚠️ RevenueCatService: Make sure you set an offering as 'Current Offering' in RevenueCat Dashboard")
                
                // Never substitute an arbitrary offering (e.g. donations or the
                // discounted annual offer) for the main subscription paywall.
                self.availablePackages = []
            }

            // The final offer is intentionally a separate RevenueCat offering.
            // Keep its package/StoreProduct intact so localized App Store pricing
            // and RevenueCat's presented-offering attribution remain authoritative.
            if offeringIdentifier == nil {
                if !availablePackages.isEmpty,
                   !availablePackages.contains(where: { $0.storeProduct.productIdentifier == "yearlydiscounted" }),
                   let finalOffering = offerings.all["yearly-discounted"],
                   let finalPackage = finalOffering.availablePackages.first(where: {
                       $0.storeProduct.productIdentifier == "yearlydiscounted"
                   }) {
                    availablePackages.append(finalPackage)
                }
                // Append only the exact product from its dedicated offering. Never
                // search another offering or substitute a similarly named SKU.
                if let trialOffering = offerings.all[Self.annualTrialOfferingIdentifier],
                   let trialPackage = trialOffering.availablePackages.first(where: {
                       $0.storeProduct.productIdentifier == Self.annualTrialProductIdentifier
                   }),
                   !availablePackages.contains(where: {
                       $0.storeProduct.productIdentifier == Self.annualTrialProductIdentifier
                   }) {
                    availablePackages.append(trialPackage)
                }
            }

            _ = await refreshAnnualTrialEligibility()
            isLoading = false
        } catch {
            availablePackages = []
            annualTrialPlan = nil
            annualTrialUnavailableReason = "Trial offer could not be loaded."
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ RevenueCatService: Error fetching offerings: \(error.localizedDescription)")
        }
    }

    /// Re-checks the dedicated annual trial. Any missing/ambiguous store or
    /// RevenueCat eligibility information fails closed and clears prior approval.
    @discardableResult
    func refreshAnnualTrialEligibility() async -> SubscriptionPlanDetails? {
        let checkedUserID = Purchases.shared.appUserID
        annualTrialPlan = nil
        annualTrialUnavailableReason = "Checking trial eligibility…"

        guard !subscriptionStatus.isActive else {
            annualTrialUnavailableReason = "An active subscription already exists."
            return nil
        }

        do {
            let latestCustomerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = latestCustomerInfo
            guard latestCustomerInfo.entitlements.active.isEmpty else {
                annualTrialUnavailableReason = "An active subscription already exists."
                return nil
            }

            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.all[Self.annualTrialOfferingIdentifier],
                  let package = offering.availablePackages.first(where: {
                      $0.storeProduct.productIdentifier == Self.annualTrialProductIdentifier
                  }) else {
                annualTrialUnavailableReason = "The annual trial offer is unavailable."
                return nil
            }

            let product = package.storeProduct
            guard let annualPeriod = product.subscriptionPeriod,
                  AnnualTrialOfferPolicy.isAnnual(unit: trialPolicyUnit(annualPeriod.unit), value: annualPeriod.value) else {
                annualTrialUnavailableReason = "The trial product is not billed annually."
                return nil
            }

            let price = NSDecimalNumber(decimal: product.price).doubleValue
            guard AnnualTrialOfferPolicy.hasRenewalPrice(price, currency: product.currencyCode) else {
                annualTrialUnavailableReason = "The annual renewal price is unavailable."
                return nil
            }

            guard let intro = product.introductoryDiscount,
                  AnnualTrialOfferPolicy.isSevenDayFreeTrial(
                    unit: trialPolicyUnit(intro.subscriptionPeriod.unit), value: intro.subscriptionPeriod.value,
                    periods: intro.numberOfPeriods, isFreeTrial: intro.paymentMode == .freeTrial,
                    introductoryPrice: intro.price) else {
                annualTrialUnavailableReason = "The product does not have an exact 7-day free trial."
                return nil
            }

            guard await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product) == .eligible else {
                annualTrialUnavailableReason = "This Apple ID is not confirmed eligible for the free trial."
                return nil
            }

            // Eligibility belongs to this customer, not whichever account may
            // have signed in while the network checks were in flight.
            guard Purchases.shared.appUserID == checkedUserID,
                  !subscriptionStatus.isActive else {
                annualTrialUnavailableReason = "Your account changed. Please check trial availability again."
                return nil
            }
            availablePackages.removeAll { $0.storeProduct.productIdentifier == Self.annualTrialProductIdentifier }
            availablePackages.append(package)

            let billingPeriodLabel = formatSubscriptionPeriod(annualPeriod)
            let priceString = product.localizedPriceString
            let plan = SubscriptionPlanDetails(
                type: .yearly,
                price: price,
                priceString: priceString,
                currencyCode: product.currencyCode,
                productId: product.productIdentifier,
                billingPeriodLabel: billingPeriodLabel,
                pricePerPeriodText: "\(priceString) / \(billingPeriodLabel)",
                introductoryTrialDays: 7
            )
            annualTrialPlan = plan
            annualTrialUnavailableReason = ""
            return plan
        } catch {
            annualTrialUnavailableReason = "Trial eligibility could not be verified."
            print("⚠️ RevenueCatService: Annual trial check failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func trialPolicyUnit(_ unit: SubscriptionPeriod.Unit) -> AnnualTrialOfferPolicy.Unit {
        switch unit {
        case .day: return .day
        case .week: return .week
        case .month: return .month
        case .year: return .year
        @unknown default: return .unknown
        }
    }
    
    /// Donation product ID prefix used in Sadaq
    private static let donationProductIdPrefix = "com.ramadanpro.donation."
    
    /// Fetches donation packages from ALL offerings. Use this for Sadaq so donation products
    /// are found even when they're in a different offering than the current (subscription) one.
    /// Does not change `availablePackages` (subscription packages).
    func fetchDonationProductPackages(offeringIdentifier: String? = nil) async -> [Package] {
        do {
            let offerings = try await Purchases.shared.offerings()

            let offeringsToSearch: [Offering]
            if let offeringIdentifier {
                let selectedOffering = offerings.all[offeringIdentifier]
                    ?? offerings.all.values.first(where: { $0.identifier == offeringIdentifier })

                if let selectedOffering {
                    offeringsToSearch = [selectedOffering]
                    print("📡 RevenueCatService: Searching donation products in offering: \(selectedOffering.identifier)")
                } else {
                    offeringsToSearch = Array(offerings.all.values)
                    print("⚠️ RevenueCatService: Offering '\(offeringIdentifier)' not found. Searching donation products across ALL offerings.")
                }
            } else {
                offeringsToSearch = Array(offerings.all.values)
                print("📡 RevenueCatService: Searching donation products across ALL offerings.")
            }

            var found: [Package] = []
            for offering in offeringsToSearch {
                for package in offering.availablePackages {
                    if package.storeProduct.productIdentifier.hasPrefix(Self.donationProductIdPrefix) {
                        found.append(package)
                    }
                }
            }

            found.sort { (a, b) in
                let amtA = Int(a.storeProduct.productIdentifier.split(separator: ".").last ?? "0") ?? 0
                let amtB = Int(b.storeProduct.productIdentifier.split(separator: ".").last ?? "0") ?? 0
                return amtA < amtB
            }
            print("📦 RevenueCatService: Found \(found.count) donation packages: \(found.map { $0.storeProduct.productIdentifier })")
            return found
        } catch {
            print("❌ RevenueCatService: Error fetching donation packages: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Purchase
    
    /// Purchase a subscription package
    func purchasePackage(_ package: Package) async throws -> Bool {
        print("💳 RevenueCatService: Purchasing package: \(package.storeProduct.productIdentifier)")
        
        isLoading = true
        errorMessage = nil
        
        do {
            let (transaction, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
            
            if userCancelled {
                print("⚠️ RevenueCatService: User cancelled purchase")
                isLoading = false
                return false
            }
            
            self.customerInfo = customerInfo
            
            // A completed App Store purchase is successful even if the optional
            // Firebase mirror is temporarily unavailable. Do not tell a charged
            // customer that payment failed or leave them stranded on the paywall.
            await updateSubscriptionStatus(from: customerInfo)

            if let userId = Auth.auth().currentUser?.uid {
                do {
                    try await syncSubscriptionToFirebase(userId: userId, customerInfo: customerInfo)
                } catch {
                    print("⚠️ RevenueCatService: Purchase succeeded; Firebase subscription sync will retry on the next status refresh: \(error.localizedDescription)")
                }
            }
            
            isLoading = false
            print("✅ RevenueCatService: Purchase successful - Transaction: \(transaction?.transactionIdentifier ?? "N/A")")
            if subscriptionStatus.isInTrial {
                TikTokAdsService.shared.trackTrialStarted(productId: package.storeProduct.productIdentifier)
            } else if subscriptionStatus.isActive {
                TikTokAdsService.shared.trackPurchase(
                    productId: package.storeProduct.productIdentifier,
                    value: NSDecimalNumber(decimal: package.storeProduct.price).doubleValue,
                    currency: package.storeProduct.currencyCode
                )
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ RevenueCatService: Purchase failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Purchases a consumable donation without changing the user's subscription
    /// entitlement. Returns the StoreKit transaction ID for the donation record.
    func purchaseDonationPackage(_ package: Package) async throws -> (transactionIdentifier: String?, userCancelled: Bool) {
        print("💳 RevenueCatService: Purchasing donation: \(package.storeProduct.productIdentifier)")
        isLoading = true
        errorMessage = nil

        do {
            let (transaction, _, userCancelled) = try await Purchases.shared.purchase(package: package)
            isLoading = false

            guard !userCancelled else {
                print("⚠️ RevenueCatService: Donation purchase cancelled")
                return (nil, true)
            }

            let transactionIdentifier = transaction?.transactionIdentifier
            TikTokAdsService.shared.trackPurchase(
                productId: package.storeProduct.productIdentifier,
                value: NSDecimalNumber(decimal: package.storeProduct.price).doubleValue,
                currency: package.storeProduct.currencyCode
            )
            print("✅ RevenueCatService: Donation purchase completed - Transaction: \(transactionIdentifier ?? "N/A")")
            return (transactionIdentifier, false)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ RevenueCatService: Donation purchase failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Purchase by product ID (for compatibility with existing code)
    func purchasePlan(_ planType: SubscriptionPlanType) async throws -> Bool {
        guard let productId = productIds[planType] else {
            throw NSError(domain: "RevenueCatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid plan type"])
        }
        
        // Find package with matching product ID
        guard let package = availablePackages.first(where: { $0.storeProduct.productIdentifier == productId }) else {
            throw NSError(domain: "RevenueCatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Package not found for product ID: \(productId)"])
        }
        
        return try await purchasePackage(package)
    }
    
    // MARK: - Restore Purchases
    
    /// Restore previous purchases
    func restorePurchases() async throws -> Bool {
        print("🔄 RevenueCatService: Restoring purchases...")
        
        isLoading = true
        errorMessage = nil
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            
            // Update subscription status
            await updateSubscriptionStatus(from: customerInfo)
            
            if let userId = Auth.auth().currentUser?.uid {
                do {
                    try await syncSubscriptionToFirebase(userId: userId, customerInfo: customerInfo)
                } catch {
                    // StoreKit/RevenueCat restore already succeeded. A mirror
                    // outage must not turn a valid entitlement into a restore failure.
                    print("⚠️ RevenueCatService: Restore succeeded; Firebase sync failed: \(error.localizedDescription)")
                }
            }
            
            isLoading = false
            
            let hasActiveSubscription = customerInfo.entitlements.active.count > 0
            print("✅ RevenueCatService: Restore completed - Has active subscription: \(hasActiveSubscription)")
            return hasActiveSubscription
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ RevenueCatService: Restore failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Check Subscription Status
    
    /// Check current subscription status
    func checkSubscriptionStatus() async {
        print("🔍 RevenueCatService: Checking subscription status...")
        
        isLoading = true
        errorMessage = nil
        
        // ADMIN BYPASS
        if checkAdminAccess() {
            isLoading = false
            return
        }
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
            
            // Update subscription status
            await updateSubscriptionStatus(from: customerInfo)
            
            isLoading = false
            print("✅ RevenueCatService: Subscription status checked")
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ RevenueCatService: Error checking subscription status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Subscription Status
    
    /// Update subscription status from RevenueCat CustomerInfo
    private func updateSubscriptionStatus(from customerInfo: CustomerInfo) async {
        print("🔄 RevenueCatService: Updating subscription status from CustomerInfo")
        
        // ADMIN BYPASS
        if checkAdminAccess() { return }
        
        // Check if user has active entitlements
        let activeEntitlements = customerInfo.entitlements.active
        
        if activeEntitlements.isEmpty {
            // No active subscription
            self.subscriptionStatus = SubscriptionStatus(isActive: false)
            subscriptionStatus.save()
            // Clear subscription status from UserDefaults
            UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
            WidgetConfig.saveIsSubscribed(false)
            print("ℹ️ RevenueCatService: No active subscription")
            return
        }
        
        // Get the first active entitlement (assuming one subscription at a time)
        guard let activeEntitlement = activeEntitlements.values.first else {
            self.subscriptionStatus = SubscriptionStatus(isActive: false)
            subscriptionStatus.save()
            // Clear subscription status from UserDefaults
            UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
            WidgetConfig.saveIsSubscribed(false)
            return
        }
        
        // Determine plan type from product identifier
        let productId = activeEntitlement.productIdentifier
        let planType: SubscriptionPlanType?
        
        if productId.contains("weekly") {
            planType = .weekly
        } else if productId.contains("monthly") {
            planType = .monthly
        } else if productId.contains("yearly") {
            planType = .yearly
        } else if productId.contains("lifetime") {
            planType = .lifetime
        } else {
            planType = nil
        }
        
        // Get dates
        let startDate = activeEntitlement.latestPurchaseDate
        let expiryDate = activeEntitlement.expirationDate
        let isInTrial = activeEntitlement.periodType == .trial
        let willRenew = activeEntitlement.willRenew
        
        // Check if cancelled
        let cancelledDate: Date? = willRenew ? nil : expiryDate
        
        self.subscriptionStatus = SubscriptionStatus(
            isActive: true,
            planType: planType,
            startDate: startDate,
            expiryDate: expiryDate,
            autoRenew: willRenew,
            cancelledDate: cancelledDate,
            trialEndDate: isInTrial ? expiryDate : nil,
            isInTrial: isInTrial
        )
        
        subscriptionStatus.save()
        // Save subscription status to UserDefaults and App Group (widget)
        UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
        WidgetConfig.saveIsSubscribed(true)
        print("✅ RevenueCatService: Subscription status updated - Active: true, Plan: \(planType?.rawValue ?? "unknown")")
        print("✅ RevenueCatService: Saved subscription status to UserDefaults")
    }

    // MARK: - Admin Access
    
    /// Account granted full access without a purchase (marketing/demo + App Review).
    private static let adminEmails: Set<String> = [
        "marketing@salahalarm.com"
    ]

    /// Checks if the current user is the admin. If so, automatically grants lifetime access.
    private func checkAdminAccess() -> Bool {
        let email = Auth.auth().currentUser?.email?
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let email, Self.adminEmails.contains(email) {
            print("👑 RevenueCatService: Admin user detected (\(email)), granting full lifetime access")
            self.subscriptionStatus = SubscriptionStatus(
                isActive: true,
                planType: .yearly,
                startDate: Date(),
                expiryDate: Date.distantFuture,
                autoRenew: true,
                cancelledDate: nil,
                trialEndDate: nil,
                isInTrial: false
            )
            subscriptionStatus.save()
            UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
            WidgetConfig.saveIsSubscribed(true)
            return true
        }
        return false
    }
    
    // MARK: - Firebase Sync
    
    /// Sync subscription status to Firebase and update User model
    private func syncSubscriptionToFirebase(userId: String, customerInfo: CustomerInfo) async throws {
        print("💾 RevenueCatService: Syncing subscription to Firebase for user \(userId)")
        
        let activeEntitlements = customerInfo.entitlements.active
        
        if activeEntitlements.isEmpty {
            // No active subscription - clear Firebase
            try await db.collection("users").document(userId).setData([
                "subscriptionStatus": false,
                "subscriptionDetails": NSNull()
            ], merge: true)
            print("✅ RevenueCatService: Cleared subscription status in Firebase")
            
            // Update User model in FirebaseAuthService
            await updateUserModelInAuthService(userId: userId)
            return
        }
        
        guard let activeEntitlement = activeEntitlements.values.first else { return }
        
        // Determine plan type
        let productId = activeEntitlement.productIdentifier
        let planTypeString: String?
        
        if productId.contains("weekly") {
            planTypeString = "weekly"
        } else if productId.contains("monthly") {
            planTypeString = "monthly"
        } else if productId.contains("yearly") {
            planTypeString = "yearly"
        } else if productId.contains("lifetime") {
            planTypeString = "lifetime"
        } else {
            planTypeString = nil
        }
        
        // Prepare subscriptionDetails object (new structure)
        var subscriptionDetails: [String: Any] = [:]
        
        if let planType = planTypeString {
            subscriptionDetails["planType"] = planType
        }
        
        if let startDate = activeEntitlement.latestPurchaseDate {
            subscriptionDetails["startDate"] = Timestamp(date: startDate)
        }
        
        if let expiryDate = activeEntitlement.expirationDate {
            subscriptionDetails["endDate"] = Timestamp(date: expiryDate)
        }
        
        subscriptionDetails["autoRenew"] = activeEntitlement.willRenew
        let isInTrial = activeEntitlement.periodType == .trial
        subscriptionDetails["isInTrial"] = isInTrial
        
        if !activeEntitlement.willRenew, let expiryDate = activeEntitlement.expirationDate {
            subscriptionDetails["cancelledDate"] = Timestamp(date: expiryDate)
        }
        
        if isInTrial, let trialEndDate = activeEntitlement.expirationDate {
            subscriptionDetails["trialEndDate"] = Timestamp(date: trialEndDate)
        } else {
            subscriptionDetails["trialEndDate"] = NSNull()
        }
        
        // Update subscription status in Firebase (new structure: subscriptionStatus boolean + subscriptionDetails object)
        try await db.collection("users").document(userId).setData([
            "subscriptionStatus": true,
            "subscriptionDetails": subscriptionDetails
        ], merge: true)
        
        print("✅ RevenueCatService: Subscription synced to Firebase (new format: subscriptionStatus=true, subscriptionDetails=\(subscriptionDetails))")
        
        // Update User model in FirebaseAuthService to reflect the change
        await updateUserModelInAuthService(userId: userId)
    }
    
    /// Update User model in FirebaseAuthService after subscription change
    private func updateUserModelInAuthService(userId: String) async {
        print("🔄 RevenueCatService: Updating User model in FirebaseAuthService")
        
        // Reload user data in FirebaseAuthService to get updated subscription status
        // This ensures the User model has the latest subscription data
        await FirebaseAuthService.shared.reloadUserData()
        
        print("✅ RevenueCatService: User model updated with subscription status")
    }
    
    // MARK: - Helper Methods
    
    /// Get package for a plan type
    func getPackage(for planType: SubscriptionPlanType) -> Package? {
        guard let productId = productIds[planType] else { return nil }
        return availablePackages.first(where: { $0.storeProduct.productIdentifier == productId })
    }
    
    /// Convert RevenueCat Package to SubscriptionPlanDetails
    func convertPackageToPlanDetails(_ package: Package) -> SubscriptionPlanDetails? {
        let productId = package.storeProduct.productIdentifier
        let livePrice = NSDecimalNumber(decimal: package.storeProduct.price).doubleValue

        print("🔍 RevenueCatService: Converting package - Package ID: \(package.identifier), Product ID: \(productId), Price: \(livePrice)")
        
        // Determine plan type - check both exact match and contains
        let planType: SubscriptionPlanType?
        
        // First check exact product ID matches
        if productId == productIds[.weekly] {
            planType = .weekly
        } else if productId == productIds[.monthly] {
            planType = .monthly
        } else if productId == productIds[.yearly] {
            planType = .yearly
        } else if productId == productIds[.lifetime] || package.packageType == .lifetime {
            planType = .lifetime
        } else if productId.lowercased().contains("weekly") || package.identifier.lowercased().contains("weekly") {
            planType = .weekly
        } else if productId.lowercased().contains("monthly") || package.identifier.lowercased().contains("monthly") {
            planType = .monthly
        } else if productId.lowercased().contains("yearly") || package.identifier.lowercased().contains("yearly") {
            planType = .yearly
        } else {
            planType = nil
        }
        
        guard let type = planType else {
            print("❌ RevenueCatService: Could not determine plan type for product ID: \(productId), Package ID: \(package.identifier)")
            print("❌ RevenueCatService: Expected product IDs: \(productIds.values.joined(separator: ", "))")
            return nil
        }

        // A SKU's name is not proof of its billing interval. In particular, a
        // monthly product must never be advertised as an annual charge / 12.
        let period = package.storeProduct.subscriptionPeriod
        let periodMatchesPlan: Bool
        switch type {
        case .weekly:
            periodMatchesPlan = period.map { ($0.unit == .week && $0.value == 1) || ($0.unit == .day && $0.value == 7) } ?? false
        case .monthly:
            periodMatchesPlan = period.map { $0.unit == .month && $0.value == 1 } ?? false
        case .yearly:
            periodMatchesPlan = period.map { ($0.unit == .year && $0.value == 1) || ($0.unit == .month && $0.value == 12) } ?? false
        case .lifetime:
            // A lifetime unlock is a non-consumable, so it must not have a billing period
            periodMatchesPlan = period == nil
        }
        guard periodMatchesPlan else {
            FunnelAnalytics.shared.track(.paywallProductRejected, [
                "plan_id": productId,
                "expected_plan_type": type.rawValue,
                "actual_billing_period": period.map { formatSubscriptionPeriod($0) } ?? "missing",
                "rejection_reason": "billing_period_mismatch"
            ])
            return nil
        }

        print("✅ RevenueCatService: Converted package to plan type: \(type.rawValue)")

        let billingPeriodLabel = package.storeProduct.subscriptionPeriod.map { formatSubscriptionPeriod($0) } ?? (type == .lifetime ? "one-time" : type.rawValue)

        // A paywall must only display a real App Store price, localized by the
        // storefront. Do not substitute a hardcoded amount for an invalid product.
        guard livePrice > 0 else {
            print("❌ RevenueCatService: Ignoring product with no live store price: \(productId)")
            return nil
        }

        let displayPriceString = package.storeProduct.localizedPriceString
        let displayPriceValue = livePrice

        let pricePerPeriodText = "\(displayPriceString) / \(billingPeriodLabel)"
        
        return SubscriptionPlanDetails(
            type: type,
            price: displayPriceValue,
            priceString: displayPriceString,
            currencyCode: package.storeProduct.currencyCode,
            features: [], // Add features if needed
            isBestValue: type == .yearly,
            productId: productId,
            billingPeriodLabel: billingPeriodLabel,
            pricePerPeriodText: pricePerPeriodText
        )
    }

    private func formatSubscriptionPeriod(_ period: SubscriptionPeriod) -> String {
        let unit: String
        switch period.unit {
        case .day:
            unit = period.value == 1 ? "day" : "days"
        case .week:
            unit = period.value == 1 ? "week" : "weeks"
        case .month:
            unit = period.value == 1 ? "month" : "months"
        case .year:
            unit = period.value == 1 ? "year" : "years"
        @unknown default:
            unit = "period"
        }

        if period.value == 1 {
            return unit
        }

        return "\(period.value) \(unit)"
    }

    private func formatTrialPeriod(_ period: SubscriptionPeriod) -> String {
        switch period.unit {
        case .week:
            let days = period.value * 7
            return days == 1 ? "1-day" : "\(days)-day"
        case .month:
            return period.value == 1 ? "1-month" : "\(period.value)-month"
        case .year:
            return period.value == 1 ? "1-year" : "\(period.value)-year"
        case .day:
            return period.value == 1 ? "1-day" : "\(period.value)-day"
        @unknown default:
            return formatSubscriptionPeriod(period)
        }
    }
}
