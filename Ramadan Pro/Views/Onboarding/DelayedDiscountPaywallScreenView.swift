//
//  DelayedDiscountPaywallScreenView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI
import FirebaseAnalytics

/// Screen 9: Delayed Discount Paywall
struct DelayedDiscountPaywallScreenView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SubscriptionViewModel()
    @State private var showError: Bool = false
    
    var body: some View {
        ZStack {
            // MARK: - Background GeometryReader
            GeometryReader { reader in
                Image("background_image")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: reader.size.width, height: reader.size.height)
                
                // MARK: - Dark Overlay for Readability
                Color.black.opacity(0.6)
            }
            .ignoresSafeArea()
            
            // MARK: - Content
            GeometryReader { geometry in
                // Gold bordered modal
                VStack(spacing: 30) {
                    // Headline
                    Text("Wait.\nOne last thing.")
                        .font(.canela(size: 32, weight: .bold))
                        .foregroundColor(AppColors.customTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                    
                    // Copy
                    Text("Yearly access for less than $2.50/month.")
                        .font(.canela(size: 18, weight: .regular))
                        .foregroundColor(AppColors.customPlaceholderText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    // Price
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Text("$83.88")
                                .font(.canela(size: 32, weight: .bold))
                                .foregroundColor(AppColors.customPlaceholderText)
                                .strikethrough()
                            
                            Text("→")
                                .font(.canela(size: 32, weight: .regular))
                                .foregroundColor(AppColors.customButtonColor)
                            
                            Text("$29.99")
                                .font(.canela(size: 40, weight: .bold))
                                .foregroundColor(AppColors.customButtonColor)
                        }
                        
                        Text("/ year")
                            .font(.canela(size: 16, weight: .regular))
                            .foregroundColor(AppColors.customPlaceholderText)
                    }
                    .padding(.vertical, 20)
                    
                    Spacer()
                    
                    // CTA
                    VStack(spacing: 16) {
                        CustomGradientButton(
                            title: viewModel.isProcessingPurchase ? "Processing..." : "Unlock for $29.99/year",
                            style: .primary,
                            action: {
                                handleDiscountPurchase()
                            }
                        )
                        .disabled(viewModel.isProcessingPurchase)
                        .frame(maxWidth: .infinity)
                        
                        Button(action: {
                            // Dismiss discount popup and return to main subscription page
                            withAnimation {
                                onboardingState.currentStep = .mainPaywall
                            }
                        }) {
                            Text("No thanks")
                                .font(.canela(size: 14, weight: .regular))
                                .foregroundColor(AppColors.customPlaceholderText)
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 32)
                }
                .frame(maxWidth: 500)
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(LinearGradient.customAppGradient, lineWidth: 2)
                )
                .padding(.horizontal, 32)
            }
        }
        .loadingOverlay(isLoading: viewModel.isLoading || viewModel.isProcessingPurchase, message: viewModel.isProcessingPurchase ? "Processing purchase..." : "Loading...")
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                viewModel.errorMessage = nil
                showError = false
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onChange(of: viewModel.errorMessage) { newValue in
            showError = newValue != nil
        }
        .task {
            // Firebase Analytics: discounted paywall viewed
            Analytics.logEvent("discount_paywall_view", parameters: [
                "entry_point": "discount_paywall" as NSString
            ])
            // Load available plans when view appears
            await viewModel.loadAvailablePlans()
        }
    }
    
    // MARK: - Private Methods
    
    private func handleDiscountPurchase() {
        // Try to find discounted yearly plan first, fallback to regular yearly plan
        // Option 1: Look for discounted product ID specifically
        let discountedProductId = "com.ramadanpro.yearly.discount"
        var planToPurchase = viewModel.availablePlans.first(where: { 
            $0.productId == discountedProductId 
        })
        
        print("🔍 DelayedDiscountPaywallScreenView: Looking for discounted plan...")
        print("   - Discounted product ID: \(discountedProductId)")
        print("   - Available plans: \(viewModel.availablePlans.map { "\($0.type.rawValue) - \($0.productId ?? "no ID")" })")
        
        if let discountedPlan = planToPurchase {
            print("✅ DelayedDiscountPaywallScreenView: Found discounted plan: \(discountedPlan.productId ?? "no ID")")
        } else {
            print("⚠️ DelayedDiscountPaywallScreenView: Discounted plan not found, looking for regular yearly plan")
            // Option 2: Fallback to regular yearly plan if discounted not found
            // Make sure we get the regular yearly, not the discounted one
            planToPurchase = viewModel.availablePlans.first(where: { 
                $0.type == .yearly && $0.productId != discountedProductId
            })
        }
        
        guard let plan = planToPurchase else {
            print("❌ DelayedDiscountPaywallScreenView: Yearly plan (discounted or regular) not found")
            print("❌ Available plans: \(viewModel.availablePlans.map { "\($0.type.rawValue) - \($0.productId ?? "no ID")" })")
            return
        }
        
        print("🛒 DelayedDiscountPaywallScreenView: Purchasing plan: \(plan.type.rawValue) - \(plan.productId ?? "no ID")")
        
        // Firebase Analytics: CTA tap on discount paywall
        Analytics.logEvent("subscription_cta_tap", parameters: [
            "entry_point": "discount_paywall" as NSString,
            "plan_type": plan.type.rawValue as NSString,
            "product_id": (plan.productId ?? "") as NSString
        ])
        
        Task {
            let success = await viewModel.purchasePlan(plan)
            
            if success {
                // Purchase successful - reset abandonment tracking
                onboardingState.resetPaywallTracking()
                
                // Firebase Analytics: purchase success from discount paywall
                Analytics.logEvent("subscription_purchase_success", parameters: [
                    "entry_point": "discount_paywall" as NSString,
                    "plan_type": plan.type.rawValue as NSString,
                    "product_id": (plan.productId ?? "") as NSString
                ])
                
                // Navigate directly to home after successful subscription purchase
                print("✅ DelayedDiscountPaywallScreenView: Purchase successful → Navigating to home")
                onboardingState.completeOnboarding()
                UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
                WidgetConfig.saveIsSubscribed(true)
                appState.onboardingComplete = true
                appState.shouldExitOnboarding = true
            } else {
                // Purchase failed - error is already set in viewModel
                print("❌ DelayedDiscountPaywallScreenView: Purchase failed")
                
                // Firebase Analytics: purchase failure
                Analytics.logEvent("subscription_purchase_failure", parameters: [
                    "entry_point": "discount_paywall" as NSString,
                    "plan_type": plan.type.rawValue as NSString,
                    "product_id": (plan.productId ?? "") as NSString
                ])
            }
        }
    }
}

#Preview {
    DelayedDiscountPaywallScreenView()
        .environmentObject(OnboardingState.shared)
}
