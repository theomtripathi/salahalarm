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
    
    @Published var customerInfo: CustomerInfo?
    @Published var availablePackages: [Package] = []
    @Published var subscriptionStatus: SubscriptionStatus = SubscriptionStatus()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    // Product IDs mapping
    private let productIds: [SubscriptionPlanType: String] = [
        .weekly: "com.ramadanpro.weekly",
        .monthly: "com.ramadanpro.monthly",
        .yearly: "com.ramadanpro.yearly"
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
                self.availablePackages = offering.availablePackages
                print("✅ RevenueCatService: Fetched \(availablePackages.count) packages from offering:")
                for package in availablePackages {
                    print("   - Package ID: \(package.identifier), Product ID: \(package.storeProduct.productIdentifier), Price: \(package.localizedPriceString)")
                }
            } else {
                print("⚠️ RevenueCatService: No offering found!")
                print("⚠️ RevenueCatService: Available offerings: \(offerings.all.keys.joined(separator: ", "))")
                print("⚠️ RevenueCatService: Make sure you set an offering as 'Current Offering' in RevenueCat Dashboard")
                
                // Try to use the first available offering as fallback
                if let firstOffering = offerings.all.values.first {
                    print("⚠️ RevenueCatService: Using first available offering as fallback: \(firstOffering.identifier)")
                    self.availablePackages = firstOffering.availablePackages
                } else {
                    self.availablePackages = []
                }
            }
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ RevenueCatService: Error fetching offerings: \(error.localizedDescription)")
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
            
            // Update subscription status
            await updateSubscriptionStatus(from: customerInfo)

            
            // Sync with Firebase
            if let userId = Auth.auth().currentUser?.uid {
                try await syncSubscriptionToFirebase(userId: userId, customerInfo: customerInfo)
            }
            
            isLoading = false
            print("✅ RevenueCatService: Purchase successful - Transaction: \(transaction?.transactionIdentifier ?? "N/A")")
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ RevenueCatService: Purchase failed: \(error.localizedDescription)")
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
            
            // Sync with Firebase
            if let userId = Auth.auth().currentUser?.uid {
                try await syncSubscriptionToFirebase(userId: userId, customerInfo: customerInfo)
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
        } else {
            planType = nil
        }
        
        // Get dates
        let startDate = activeEntitlement.latestPurchaseDate
        let expiryDate = activeEntitlement.expirationDate
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
            trialEndDate: nil,
            isInTrial: false
        )
        
        subscriptionStatus.save()
        // Save subscription status to UserDefaults and App Group (widget)
        UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
        WidgetConfig.saveIsSubscribed(true)
        print("✅ RevenueCatService: Subscription status updated - Active: true, Plan: \(planType?.rawValue ?? "unknown")")
        print("✅ RevenueCatService: Saved subscription status to UserDefaults")
    }

    // MARK: - Admin Access
    
    /// Checks if the current user is the admin. If so, automatically grants lifetime access.
    private func checkAdminAccess() -> Bool {
        if let email = Auth.auth().currentUser?.email, email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "marketing@salahalarm.co" {
            print("👑 RevenueCatService: Admin user detected, granting full lifetime access")
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
        subscriptionDetails["isInTrial"] = false
        
        if !activeEntitlement.willRenew, let expiryDate = activeEntitlement.expirationDate {
            subscriptionDetails["cancelledDate"] = Timestamp(date: expiryDate)
        }
        
        subscriptionDetails["trialEndDate"] = NSNull()
        
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
        
        print("✅ RevenueCatService: Converted package to plan type: \(type.rawValue)")
        
        let billingPeriodLabel = package.storeProduct.subscriptionPeriod.map { formatSubscriptionPeriod($0) } ?? type.rawValue
        let displayPriceString: String
        let displayPriceValue: Double

        switch type {
        case .weekly:
            displayPriceString = AppConstants.Pricing.weekly
            displayPriceValue = 6.99
        case .monthly:
            displayPriceString = "$0.00"
            displayPriceValue = 0.0
        case .yearly:
            displayPriceString = AppConstants.Pricing.yearly
            displayPriceValue = 29.99
        }

        let pricePerPeriodText = "\(displayPriceString) / \(billingPeriodLabel)"
        
        let trialLabel: String? = nil
        let renewalDescription = "\(pricePerPeriodText). Cancel anytime."
        
        return SubscriptionPlanDetails(
            type: type,
            price: displayPriceValue,
            priceString: displayPriceString,
            features: [], // Add features if needed
            isBestValue: type == .yearly,
            productId: productId,
            billingPeriodLabel: billingPeriodLabel,
            pricePerPeriodText: pricePerPeriodText,
            trialLabel: trialLabel,
            renewalDescription: renewalDescription
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
