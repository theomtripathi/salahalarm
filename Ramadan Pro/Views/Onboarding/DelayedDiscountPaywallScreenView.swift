//
//  DelayedDiscountPaywallScreenView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI
import FirebaseAnalytics
import PostHog

/// Screen 9: Delayed Discount Paywall
struct DelayedDiscountPaywallScreenView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SubscriptionViewModel()
    @State private var showError: Bool = false
    @State private var purchaseTaskRunning = false
    
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
                    Text("A full year of SalahAlarm, billed once annually.")
                        .font(.canela(size: 18, weight: .regular))
                        .foregroundColor(AppColors.customPlaceholderText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    // Price
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            if let plan = discountedYearlyPlan {
                                Text(plan.formatAmount(plan.price / 12))
                                    .font(.canela(size: 40, weight: .bold))
                                    .foregroundColor(AppColors.customButtonColor)
                            } else {
                                Text("Loading App Store price…")
                                    .font(.canela(size: 20, weight: .semibold))
                                    .foregroundColor(AppColors.customPlaceholderText)
                            }
                        }
                        
                        if let plan = discountedYearlyPlan {
                            Text("per month · billed once a year at \(plan.priceString) / year")
                                .font(.canela(size: 16, weight: .regular))
                                .foregroundColor(AppColors.customPlaceholderText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 20)
                    
                    Spacer()
                    
                    // CTA
                    VStack(spacing: 16) {
                        CustomGradientButton(
                            title: viewModel.isProcessingPurchase ? "Processing..." : (discountedYearlyPlan.map { "Unlock for \($0.priceString)/year" } ?? "Offer temporarily unavailable"),
                            style: .primary,
                            action: {
                                handleDiscountPurchase()
                            }
                        )
                        .disabled(viewModel.isProcessingPurchase || discountedYearlyPlan == nil)
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
        .postHogNoMask()
        .loadingOverlay(isLoading: viewModel.isLoading || viewModel.isProcessingPurchase, message: viewModel.isProcessingPurchase ? "Processing purchase..." : "Loading...")
        .alert(viewModel.purchaseErrorTitle, isPresented: $showError) {
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
            // Report actual loaded products rather than implying the offer exists.
            await viewModel.loadAvailablePlans()
            FunnelAnalytics.shared.track(.paywallViewed, [
                "paywall_id": "discount_yearly",
                "paywall_placement": "post_onboarding",
                "available_plan_ids": discountedYearlyPlan?.productId ?? "",
                "plans_loaded": discountedYearlyPlan != nil
            ])
        }
    }
    
    // MARK: - Private Methods
    
    private func handleDiscountPurchase() {
        guard !viewModel.isProcessingPurchase, !purchaseTaskRunning else { return }
        let discountedProductId = "yearlydiscounted"
        guard let planToPurchase = discountedYearlyPlan else {
            viewModel.errorMessage = "This offer is temporarily unavailable. Please try again later."
            return
        }
        
        print("🔍 DelayedDiscountPaywallScreenView: Looking for discounted plan...")
        print("   - Discounted product ID: \(discountedProductId)")
        print("   - Available plans: \(viewModel.availablePlans.map { "\($0.type.rawValue) - \($0.productId ?? "no ID")" })")
        
        let plan = planToPurchase
        
        print("🛒 DelayedDiscountPaywallScreenView: Purchasing plan: \(plan.type.rawValue) - \(plan.productId ?? "no ID")")
        
        // Firebase Analytics: CTA tap on discount paywall
        Analytics.logEvent("subscription_cta_tap", parameters: [
            "entry_point": "discount_paywall" as NSString,
            "plan_type": plan.type.rawValue as NSString,
            "product_id": (plan.productId ?? "") as NSString
        ])
        purchaseTaskRunning = true
        let attemptProperties: [String: Any] = [
            "paywall_id": "discount_yearly",
            "purchase_attempt_id": UUID().uuidString,
            "offer_stage": "final_discount",
            "paywall_placement": "post_onboarding",
            "plan_id": plan.productId ?? "",
            "billing_period": plan.type.rawValue,
            "price_billed": plan.priceString
        ]
        FunnelAnalytics.shared.track(.purchaseInitiated, attemptProperties)
        
        Task {
            defer { purchaseTaskRunning = false }
            let success = await viewModel.purchasePlan(plan, analyticsContext: attemptProperties)
            
            if success {
                FunnelAnalytics.shared.track(.purchaseCompleted, attemptProperties)
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
                let event: FunnelEvent
                let analyticsEvent: String
                switch viewModel.lastPurchaseOutcome {
                case .cancelled:
                    event = .purchaseCancelled
                    analyticsEvent = "subscription_purchase_cancelled"
                case .pending:
                    event = .purchasePending
                    analyticsEvent = "subscription_purchase_pending"
                case .notAllowed:
                    event = .purchaseNotAllowed
                    analyticsEvent = "subscription_purchase_not_allowed"
                default:
                    event = .purchaseFailed
                    analyticsEvent = "subscription_purchase_failure"
                }
                var parameters: [String: Any] = [
                    "entry_point": "discount_paywall" as NSString,
                    "plan_type": plan.type.rawValue as NSString,
                    "product_id": (plan.productId ?? "") as NSString
                ]
                viewModel.purchaseErrorProperties.forEach { parameters[$0.key] = $0.value as NSString }
                Analytics.logEvent(analyticsEvent, parameters: parameters)
                var properties = attemptProperties
                viewModel.purchaseErrorProperties.forEach { properties[$0.key] = $0.value }
                FunnelAnalytics.shared.track(event, properties)
            }
        }
    }

    private var discountedYearlyPlan: SubscriptionPlanDetails? {
        viewModel.availablePlans.first { $0.productId == "yearlydiscounted" }
    }
}

#Preview {
    DelayedDiscountPaywallScreenView()
        .environmentObject(OnboardingState.shared)
}
