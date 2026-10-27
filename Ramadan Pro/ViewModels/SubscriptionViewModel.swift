//
//  SubscriptionViewModel.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import Combine
import SwiftUI
import RevenueCat
import StoreKit

// PURCHASE_ERROR_CLASSIFIER_BEGIN
#if PURCHASE_CLASSIFIER_STANDALONE
import Foundation
import StoreKit
#endif

enum PurchaseErrorClassifier {
    enum Result: Equatable {
        case cancelled
        case pending
        case notAllowed
        case failed
    }

    struct RevenueCatCodes {
        let cancelled: Int
        let pending: Int
        let purchaseNotAllowed: Int
        let insufficientPermissions: Int
    }

    static func classify(
        _ error: NSError,
        revenueCatErrorDomain: String,
        revenueCatCodes: RevenueCatCodes
    ) -> Result {
        var currentError: NSError? = error
        var visited = Set<ObjectIdentifier>()
        var depth = 0

        while let candidate = currentError, depth <= 8 {
            let identity = ObjectIdentifier(candidate)
            guard visited.insert(identity).inserted else { return .failed }

            if matches(candidate, domain: revenueCatErrorDomain, codes: [revenueCatCodes.cancelled]) ||
                matches(candidate, domain: SKErrorDomain, codes: [SKError.paymentCancelled.rawValue]) {
                return .cancelled
            }
            if matches(candidate, domain: revenueCatErrorDomain, codes: [revenueCatCodes.pending]) {
                return .pending
            }
            if matches(candidate, domain: revenueCatErrorDomain, codes: [revenueCatCodes.purchaseNotAllowed, revenueCatCodes.insufficientPermissions]) ||
                matches(candidate, domain: SKErrorDomain, codes: [SKError.paymentNotAllowed.rawValue]) {
                return .notAllowed
            }

            currentError = candidate.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }
        return .failed
    }

    private static func matches(_ error: NSError, domain: String, codes: [Int]) -> Bool {
        error.domain == domain && codes.contains(error.code)
    }
}
// PURCHASE_ERROR_CLASSIFIER_END

/// ViewModel for managing subscriptions
@MainActor
class SubscriptionViewModel: ObservableObject {
    enum PurchaseOutcome: String {
        case idle
        case completed
        case cancelled
        case pending
        case notAllowed = "not_allowed"
        case failed
    }

    // MARK: - Published Properties
    
    @Published var subscriptionStatus: SubscriptionStatus = SubscriptionStatus()
    @Published var availablePlans: [SubscriptionPlanDetails] = []
    @Published var receipts: [PurchaseReceipt] = []
    
    @Published var isLoading: Bool = false
    @Published var isProcessingPurchase: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var purchaseErrorProperties: [String: String] = [:]
    @Published private(set) var lastPurchaseOutcome: PurchaseOutcome = .idle

    var purchaseErrorTitle: String {
        switch lastPurchaseOutcome {
        case .pending: return "Purchase pending"
        case .notAllowed: return "Purchases not allowed"
        case .idle, .completed, .cancelled, .failed: return "Purchase failed"
        }
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let revenueCatService = RevenueCatService.shared
    private let supportedPlanTypes: [SubscriptionPlanType] = [.weekly, .yearly]
    
    init() {
        loadSubscriptionStatus()
        // loadAvailablePlans() is async - call it from view's .task modifier
        
        // Observe RevenueCat service subscription status
        revenueCatService.$subscriptionStatus
            .assign(to: &$subscriptionStatus)
    }
    
    // MARK: - Public Methods
    
    /// Load subscription status from RevenueCat (with local fallback)
    func loadSubscriptionStatus() async {
        isLoading = true
        errorMessage = nil
        
        do {
            await revenueCatService.checkSubscriptionStatus()
            // Subscription status is automatically updated via @Published property observation
            isLoading = false
        } catch {
            // Fallback to local storage
            self.subscriptionStatus = SubscriptionStatus.load()
            isLoading = false
            print("⚠️ SubscriptionViewModel: Error checking subscription status, using local: \(error.localizedDescription)")
        }
    }
    
    /// Load subscription status from local storage (synchronous version for init)
    private func loadSubscriptionStatus() {
        self.subscriptionStatus = SubscriptionStatus.load()
    }
    
    /// Load available subscription plans from RevenueCat
    func loadAvailablePlans() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch offerings from RevenueCat - use Current Offering (avoids ambiguity when multiple "default" offerings exist)
            await revenueCatService.fetchOfferings(offeringIdentifier: nil)
            
            // Convert RevenueCat packages to SubscriptionPlanDetails
            var plans: [SubscriptionPlanDetails] = []
            print("📦 SubscriptionViewModel: Converting \(revenueCatService.availablePackages.count) packages to plans")
            
            for package in revenueCatService.availablePackages {
                print("📦 SubscriptionViewModel: Processing package - ID: \(package.storeProduct.productIdentifier)")
                if let planDetails = revenueCatService.convertPackageToPlanDetails(package) {
                    plans.append(planDetails)
                    print("✅ SubscriptionViewModel: Added plan: \(planDetails.type.rawValue)")
                } else {
                    print("❌ SubscriptionViewModel: Failed to convert package: \(package.storeProduct.productIdentifier)")
                }
            }
            
            // The last-chance trial is a separate stage, never a main/legacy plan.
            plans = plans.filter {
                supportedPlanTypes.contains($0.type)
                    && $0.productId != RevenueCatService.annualTrialProductIdentifier
            }
            print("📦 SubscriptionViewModel: Converted \(plans.count) supported plans from \(revenueCatService.availablePackages.count) packages")
            
            // Never show sample prices in a real paywall. If RevenueCat has no
            // purchasable plans, let the view present a retry state instead.
            if plans.isEmpty {
                self.availablePlans = []
                self.errorMessage = "Plans are temporarily unavailable. Please try again."
                print("⚠️ SubscriptionViewModel: No supported packages returned from RevenueCat")
            } else {
                // Sort plans: weekly, yearly
                self.availablePlans = plans.sorted { plan1, plan2 in
                    let order: [SubscriptionPlanType] = [.weekly, .yearly]
                    let index1 = order.firstIndex(of: plan1.type) ?? Int.max
                    let index2 = order.firstIndex(of: plan2.type) ?? Int.max
                    return index1 < index2
                }
                print("✅ SubscriptionViewModel: Loaded \(self.availablePlans.count) plans: \(self.availablePlans.map { $0.type.rawValue })")
            }
            
            isLoading = false
        } catch {
            self.availablePlans = []
            self.errorMessage = "Plans are temporarily unavailable. Please try again."
            isLoading = false
            print("⚠️ SubscriptionViewModel: Error loading plans: \(error.localizedDescription)")
        }
    }
    
    /// Purchase a subscription plan via RevenueCat
    func purchasePlan(_ plan: SubscriptionPlanDetails, analyticsContext: [String: Any] = [:]) async -> Bool {
        // This is @MainActor-isolated; the flag is set before the first await,
        // so a second tap cannot launch another StoreKit purchase.
        guard !isProcessingPurchase else { return false }
        isProcessingPurchase = true
        errorMessage = nil
        purchaseErrorProperties = [:]
        lastPurchaseOutcome = .idle
        
        do {
            // Recheck just before checkout: never silently charge the annual
            // amount when the screen promised a trial that is no longer eligible.
            if plan.productId == RevenueCatService.annualTrialProductIdentifier {
                guard let liveTrial = await revenueCatService.refreshAnnualTrialEligibility(),
                      liveTrial.productId == plan.productId,
                      liveTrial.price == plan.price,
                      liveTrial.currencyCode == plan.currencyCode else {
                    lastPurchaseOutcome = .failed
                    errorMessage = "This free trial is no longer available, or its terms have changed. Please close this offer and try again. No checkout was started."
                    recordPurchaseDiagnostics(category: "trial_offer_unavailable", reason: "Trial eligibility or terms changed before checkout.", chargeStatus: "not_attempted")
                    purchaseErrorProperties["failure_stage"] = "offer_validation"
                    purchaseErrorProperties["checkout_status"] = "not_started"
                    isProcessingPurchase = false
                    return false
                }
            }
            // An explicit product ID identifies the selected SKU; never substitute another SKU.
            var package: Package?
            
            if let productId = plan.productId {
                package = revenueCatService.availablePackages.first(where: { 
                    $0.storeProduct.productIdentifier == productId 
                })
                print("🔍 SubscriptionViewModel: Looking for package with product ID: \(productId)")
                if package == nil {
                    errorMessage = productId == "yearlydiscounted"
                        ? "This offer is not available yet. Please try again shortly."
                        : "Package not found for \(plan.type.displayName) (\(productId))"
                }
            } else {
                // Type fallback is safe only when the caller did not select a specific SKU.
                package = revenueCatService.getPackage(for: plan.type)
                print("🔍 SubscriptionViewModel: Fallback - looking for package by plan type: \(plan.type.rawValue)")
            }
            
            guard let packageToPurchase = package else {
                errorMessage = errorMessage ?? "Package not found for \(plan.type.displayName)"
                lastPurchaseOutcome = .failed
                recordPurchaseDiagnostics(category: "package_unavailable", reason: errorMessage ?? "Package unavailable", chargeStatus: "not_attempted")
                isProcessingPurchase = false
                print("❌ SubscriptionViewModel: Package not found for plan: \(plan.type.rawValue) - productId: \(plan.productId ?? "none"). Available package count: \(revenueCatService.availablePackages.count)")
                return false
            }
            
            print("✅ SubscriptionViewModel: Found package - Product ID: \(packageToPurchase.storeProduct.productIdentifier), Price: \(packageToPurchase.localizedPriceString)")

            purchaseErrorProperties = [
                "checkout_status": "checkout_started",
                "failure_stage": "checkout",
                "charge_status": "unknown",
                "decline_status": "not_reported"
            ]

            var checkoutProperties = analyticsContext
            checkoutProperties["plan_id"] = plan.productId ?? packageToPurchase.storeProduct.productIdentifier
            checkoutProperties["checkout_started"] = true
            // This records that RevenueCat was invoked, not that Apple's sheet appeared.
            FunnelAnalytics.shared.track(.purchaseCheckoutStarted, checkoutProperties)
            
            // Purchase via RevenueCat
            let success = try await revenueCatService.purchasePackage(packageToPurchase)
            
            if success {
                guard revenueCatService.subscriptionStatus.isActive,
                      !revenueCatService.subscriptionStatus.isExpired else {
                    // A transaction can finish before a misconfigured/delayed
                    // entitlement is available. Do not fake access or call this
                    // a payment failure; offer restore/support instead of retrying payment.
                    lastPurchaseOutcome = .pending
                    errorMessage = "Your purchase was received, but access is still being verified. Please use Restore or contact support; you don't need to purchase again."
                    recordPurchaseDiagnostics(category: "entitlement_pending", reason: "Purchase received; entitlement verification pending.")
                    purchaseErrorProperties["failure_stage"] = "entitlement_verification"
                    purchaseErrorProperties["checkout_status"] = "completed"
                    isProcessingPurchase = false
                    return false
                }
                // Subscription status is automatically updated by RevenueCatService
                // and synced to Firebase
                lastPurchaseOutcome = .completed
                isProcessingPurchase = false
                return true
            } else {
                lastPurchaseOutcome = .cancelled
                errorMessage = nil
                recordPurchaseDiagnostics(category: "cancelled", reason: "User cancelled the purchase.", chargeStatus: "not_attempted")
                isProcessingPurchase = false
                return false
            }
        } catch {
            let nsError = error as NSError
            let classification = PurchaseErrorClassifier.classify(
                nsError,
                revenueCatErrorDomain: ErrorCode.errorDomain,
                revenueCatCodes: PurchaseErrorClassifier.RevenueCatCodes(
                    cancelled: ErrorCode.purchaseCancelledError.rawValue,
                    pending: ErrorCode.paymentPendingError.rawValue,
                    purchaseNotAllowed: ErrorCode.purchaseNotAllowedError.rawValue,
                    insufficientPermissions: ErrorCode.insufficientPermissionsError.rawValue
                )
            )
            if classification == .cancelled {
                lastPurchaseOutcome = .cancelled
                errorMessage = nil
                recordPurchaseDiagnostics(category: "cancelled", reason: "User cancelled the purchase.", error: error, chargeStatus: "not_attempted")
            } else if classification == .pending {
                lastPurchaseOutcome = .pending
                errorMessage = "Your purchase is pending approval. Access will be available after it is approved."
                recordPurchaseDiagnostics(category: "pending", reason: "Your purchase is pending approval.", error: error)
            } else if classification == .notAllowed {
                lastPurchaseOutcome = .notAllowed
                errorMessage = "Purchases are not allowed on this device or account."
                recordPurchaseDiagnostics(category: "purchase_not_allowed", reason: "Purchases are not allowed on this device or account.", error: error, chargeStatus: "not_attempted")
            } else {
                lastPurchaseOutcome = .failed
                errorMessage = "We couldn’t complete your purchase. Please try again."
                recordPurchaseDiagnostics(category: purchaseFailureCategory(for: nsError), reason: "We couldn’t complete your purchase.", error: error)
            }
            isProcessingPurchase = false
            print("❌ SubscriptionViewModel: Purchase outcome: \(lastPurchaseOutcome.rawValue)")
            return false
        }
    }

    private func recordPurchaseDiagnostics(category: String, reason: String, error: Error? = nil, chargeStatus: String = "unknown") {
        var properties = [
            "error_category": category,
            "error_reason": reason,
            "purchase_outcome": lastPurchaseOutcome.rawValue,
            "failure_stage": category == "package_unavailable" ? "product_lookup" : "checkout",
            "checkout_status": category == "package_unavailable" ? "not_started" : "checkout_started",
            "charge_status": chargeStatus,
            // A StoreKit/RevenueCat error is not an explicit bank-decline verdict.
            "decline_status": "not_reported"
        ]
        if let error {
            let nsError = error as NSError
            properties["error_domain"] = nsError.domain
            properties["error_code"] = String(nsError.code)
            if let codeName = nsError.userInfo["rc_code_name"] as? String {
                properties["error_code_name"] = codeName
            }
            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                properties["underlying_error_domain"] = underlyingError.domain
                properties["underlying_error_code"] = String(underlyingError.code)
            }
        }
        purchaseErrorProperties = properties
    }

    private func purchaseFailureCategory(for error: NSError) -> String {
        guard error.domain == ErrorCode.errorDomain,
              let code = ErrorCode(rawValue: error.code) else {
            return error.domain == NSURLErrorDomain ? "network" : "unknown"
        }
        switch code {
        case .networkError, .offlineConnectionError, .apiEndpointBlockedError, .productRequestTimedOut:
            return "network"
        case .storeProblemError:
            // Store problems can have an uncertain charge outcome; they do not
            // establish a card decline or even prove that no charge occurred.
            return "store_problem"
        case .purchaseNotAllowedError, .insufficientPermissionsError:
            return "purchase_not_allowed"
        case .purchaseInvalidError:
            return "purchase_invalid"
        case .productNotAvailableForPurchaseError:
            return "product_unavailable"
        case .configurationError, .invalidCredentialsError, .invalidAppleSubscriptionKeyError:
            return "configuration"
        case .invalidReceiptError, .missingReceiptFileError, .receiptAlreadyInUseError, .receiptInUseByOtherSubscriberError:
            return "receipt"
        case .productAlreadyPurchasedError:
            return "already_purchased"
        default:
            return "unknown"
        }
    }
    
    /// Restore previous purchases via RevenueCat
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let success = try await revenueCatService.restorePurchases()
            isLoading = false
            return success
        } catch {
            errorMessage = "We couldn’t restore purchases. Please try again."
            isLoading = false
            print("❌ SubscriptionViewModel: Restore failed")
            return false
        }
    }
    
    /// Cancel subscription
    func cancelSubscription() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        // TODO: Replace with API call
        // do {
        //     let response = try await apiService.cancelSubscription()
        //     if response.success {
        //         var updatedStatus = subscriptionStatus
        //         updatedStatus.autoRenew = false
        //         updatedStatus.cancelledDate = Date()
        //         self.subscriptionStatus = updatedStatus
        //         updatedStatus.save()
        //         isLoading = false
        //         return true
        //     } else {
        //         errorMessage = response.error ?? "Failed to cancel subscription"
        //         isLoading = false
        //         return false
        //     }
        // } catch {
        //     errorMessage = error.localizedDescription
        //     isLoading = false
        //     return false
        // }
        
        // Temporary: Update local status
        var updatedStatus = subscriptionStatus
        updatedStatus = SubscriptionStatus(
            isActive: subscriptionStatus.isActive,
            planType: subscriptionStatus.planType,
            startDate: subscriptionStatus.startDate,
            expiryDate: subscriptionStatus.expiryDate,
            autoRenew: false,
            cancelledDate: Date()
        )
        self.subscriptionStatus = updatedStatus
        updatedStatus.save()
        isLoading = false
        return true
    }
    
    /// Load purchase receipts
    func loadReceipts() async {
        isLoading = true
        
        // TODO: Replace with API call
        // do {
        //     let receipts = try await apiService.fetchReceipts()
        //     self.receipts = receipts
        //     isLoading = false
        // } catch {
        //     errorMessage = error.localizedDescription
        //     isLoading = false
        // }
        
        isLoading = false
    }
    
    // MARK: - Private Methods (Sample Data - Remove when backend is ready)
    
    private func loadSamplePlans() {
        // Sample subscription plans
        availablePlans = [
            SubscriptionPlanDetails(
                type: .weekly,
                price: AppConstants.Pricing.weeklyValue,
                features: ["All prayer times", "Ad-free experience", "Widget support"],
                isBestValue: false,
                productId: "com.ramadanpro.weekly",
                billingPeriodLabel: "week",
                pricePerPeriodText: "\(AppConstants.Pricing.weekly) / week",
                trialLabel: nil,
                renewalDescription: "\(AppConstants.Pricing.weekly) / week. Cancel anytime."
            ),
            SubscriptionPlanDetails(
                type: .yearly,
                price: AppConstants.Pricing.yearlyValue,
                features: ["All weekly features", "Priority support", "Advanced analytics"],
                isBestValue: true,
                productId: "com.ramadanpro.yearly",
                billingPeriodLabel: "year",
                pricePerPeriodText: "\(AppConstants.Pricing.yearly) / year",
                trialLabel: nil,
                renewalDescription: "\(AppConstants.Pricing.yearly) / year. Cancel anytime."
            )
        ]
    }
}
