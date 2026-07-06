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

/// ViewModel for managing subscriptions
@MainActor
class SubscriptionViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var subscriptionStatus: SubscriptionStatus = SubscriptionStatus()
    @Published var availablePlans: [SubscriptionPlanDetails] = []
    @Published var receipts: [PurchaseReceipt] = []
    
    @Published var isLoading: Bool = false
    @Published var isProcessingPurchase: Bool = false
    @Published var errorMessage: String?
    
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
            
            plans = plans.filter { supportedPlanTypes.contains($0.type) }
            print("📦 SubscriptionViewModel: Converted \(plans.count) supported plans from \(revenueCatService.availablePackages.count) packages")
            
            // If no plans from RevenueCat, use sample plans as fallback
            if plans.isEmpty {
                print("⚠️ SubscriptionViewModel: No packages from RevenueCat, using sample plans")
                loadSamplePlans()
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
            // Fallback to sample plans on error
            loadSamplePlans()
            isLoading = false
            print("⚠️ SubscriptionViewModel: Error loading plans, using sample: \(error.localizedDescription)")
        }
    }
    
    /// Purchase a subscription plan via RevenueCat
    func purchasePlan(_ plan: SubscriptionPlanDetails) async -> Bool {
        isProcessingPurchase = true
        errorMessage = nil
        
        do {
            // Find the package for this plan - prefer by product ID if available, otherwise by type
            var package: Package?
            
            if let productId = plan.productId {
                // First try to find by exact product ID (important for discounted products)
                package = revenueCatService.availablePackages.first(where: { 
                    $0.storeProduct.productIdentifier == productId 
                })
                print("🔍 SubscriptionViewModel: Looking for package with product ID: \(productId)")
            }
            
            // Fallback to finding by plan type if not found by product ID
            if package == nil {
                package = revenueCatService.getPackage(for: plan.type)
                print("🔍 SubscriptionViewModel: Fallback - looking for package by plan type: \(plan.type.rawValue)")
            }
            
            guard let packageToPurchase = package else {
                errorMessage = "Package not found for \(plan.type.displayName)"
                if let pid = plan.productId {
                    errorMessage! += " (\(pid))"
                }
                isProcessingPurchase = false
                print("❌ SubscriptionViewModel: Package not found for plan: \(plan.type.rawValue) - productId: \(plan.productId ?? "none"). Available package count: \(revenueCatService.availablePackages.count)")
                return false
            }
            
            print("✅ SubscriptionViewModel: Found package - Product ID: \(packageToPurchase.storeProduct.productIdentifier), Price: \(packageToPurchase.localizedPriceString)")
            
            // Purchase via RevenueCat
            let success = try await revenueCatService.purchasePackage(packageToPurchase)
            
            if success {
                // Subscription status is automatically updated by RevenueCatService
                // and synced to Firebase
                isProcessingPurchase = false
                return true
            } else {
                errorMessage = "Purchase was cancelled"
                isProcessingPurchase = false
                // Ensure local subscription flag is cleared on cancelled purchase
                UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
                WidgetConfig.saveIsSubscribed(false)
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isProcessingPurchase = false
            print("❌ SubscriptionViewModel: Purchase failed: \(error.localizedDescription)")
            // Ensure local subscription flag is cleared on failed purchase
            UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
            WidgetConfig.saveIsSubscribed(false)
            return false
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
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ SubscriptionViewModel: Restore failed: \(error.localizedDescription)")
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
                price: 6.99,
                features: ["All prayer times", "Ad-free experience", "Widget support"],
                isBestValue: false,
                productId: "com.ramadanpro.weekly",
                billingPeriodLabel: "week",
                pricePerPeriodText: "$6.99 / week",
                trialLabel: nil,
                renewalDescription: "$6.99 / week. Cancel anytime."
            ),
            SubscriptionPlanDetails(
                type: .yearly,
                price: 29.99,
                features: ["All weekly features", "Priority support", "Advanced analytics"],
                isBestValue: true,
                productId: "com.ramadanpro.yearly",
                billingPeriodLabel: "year",
                pricePerPeriodText: "$29.99 / year",
                trialLabel: nil,
                renewalDescription: "$29.99 / year. Cancel anytime."
            )
        ]
    }
}
