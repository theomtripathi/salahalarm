//
//  MainPaywallScreenView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseAnalytics
import PostHog

/// Screen 8: Main Paywall
struct MainPaywallScreenView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SubscriptionViewModel()
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var showError: Bool = false
    @State private var scrollOffset: CGFloat = 0
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
                ScrollView {
                    VStack(spacing: 40) {
                        // Header
                        Text("Unlock\nSalahAlarm")
                            .font(.canela(size: 36, weight: .bold))
                            .foregroundColor(AppColors.customTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.top, 60)
                            .padding(.horizontal, 32)
                        
                        // Benefits
                        VStack(alignment: .leading, spacing: 20) {
                            benefitRow(icon: "square.grid.2x2", text: "Live Widget access")
                            benefitRow(icon: "book.fill", text: "Quran tracking")
                            benefitRow(icon: "location.north.circle.fill", text: "Qibla compass")
                            benefitRow(icon: "bell.badge.fill", text: "Prayer alarm routines")
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 20)
                        
                        // Pricing Cards
                        VStack(spacing: 16) {
                            ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                                let storePlan = viewModel.availablePlans.first {
                                    $0.type == (plan == .yearly ? .yearly : .weekly)
                                        && $0.productId != "yearlydiscounted"
                                }
                                PricingCard(
                                    plan: plan,
                                    localizedPrice: storePlan?.priceString,
                                    isSelected: selectedPlan == plan,
                                    isYearly: plan == .yearly,
                                    action: {
                                        FunnelAnalytics.shared.track(.pricingPlanSelected, ["plan_id": storePlan?.productId ?? "", "plan_name": plan.rawValue, "billing_period": plan == .yearly ? "annual" : "weekly", "price_billed": storePlan?.priceString ?? ""])
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedPlan = plan
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        // CTA
                        VStack(spacing: 16) {
                            CustomGradientButton(
                                title: viewModel.isProcessingPurchase ? "Processing..." : "Continue",
                                style: .primary,
                                action: {
                                    handlePurchase()
                                }
                            )
                            .disabled(viewModel.isProcessingPurchase)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                        .padding(.bottom, 50)
                    }
                }
            }
        }
        .onAppear {
            // Increment paywall view count
            onboardingState.incrementPaywallViewCount()
            
            // Firebase Analytics: paywall viewed
            Analytics.logEvent("paywall_view", parameters: [
                "source": "onboarding" as NSString,
                "view_count": onboardingState.paywallViewCount as NSNumber
            ])
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
            // Load available plans when view appears
            await viewModel.loadAvailablePlans()
            FunnelAnalytics.shared.track(.paywallViewed, [
                "paywall_id": "legacy_main",
                "paywall_placement": "post_onboarding",
                "available_plan_ids": viewModel.availablePlans.compactMap(\.productId).joined(separator: ",")
            ])
        }
    }
    
    // MARK: - Private Methods
    
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppColors.accent)
                .frame(width: 24)
            
            Text(text)
                .font(.canela(size: 16, weight: .regular))
                .foregroundColor(AppColors.customTextColor)
            
            Spacer()
        }
    }
    
    // MARK: - Discount Display Logic
    
    /// Show delayed discount screen when abandonment is detected
    private func showDelayedDiscount() {
        // Discount screen disabled – keep user on main paywall
        print("📊 MainPaywallScreenView: Discount screen disabled; staying on main paywall")
    }

    /// Complete subscription onboarding and navigate to home
    private func completeSubscriptionAndExitOnboarding() {
        // Mark onboarding as completed so user doesn't see it again
        onboardingState.completeOnboarding()
        UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
        WidgetConfig.saveIsSubscribed(true)
        appState.onboardingComplete = true
        // Trigger switch from onboarding flow to MainTabView
        appState.shouldExitOnboarding = true
        print("🏠 MainPaywallScreenView: Completed onboarding after subscription - navigating to home")
    }
    
    private func handlePurchase() {
        guard !viewModel.isProcessingPurchase, !purchaseTaskRunning else { return }
        
        // Convert SubscriptionPlan to SubscriptionPlanType
        let planType: SubscriptionPlanType
        switch selectedPlan {
        case .weekly:
            planType = .weekly
        case .yearly:
            planType = .yearly
        }
        
        // Firebase Analytics: CTA tap
        Analytics.logEvent("subscription_cta_tap", parameters: [
            "entry_point": "main_paywall" as NSString,
            "plan_type": planType.rawValue as NSString
        ])
        
        print("🛒 MainPaywallScreenView: Attempting to purchase plan: \(planType.rawValue)")
        print("🛒 MainPaywallScreenView: Available plans count: \(viewModel.availablePlans.count)")
        print("🛒 MainPaywallScreenView: Available plan types: \(viewModel.availablePlans.map { $0.type.rawValue })")
        
        // Find the plan details
        guard let planDetails = viewModel.availablePlans.first(where: { $0.type == planType && $0.productId != "yearlydiscounted" }) else {
            print("❌ MainPaywallScreenView: Plan not found for \(planType)")
            print("❌ MainPaywallScreenView: Available plans: \(viewModel.availablePlans.map { "\($0.type.rawValue) - \($0.productId ?? "no ID")" })")
            return
        }
        
        print("✅ MainPaywallScreenView: Found plan details for \(planType.rawValue) - Product ID: \(planDetails.productId ?? "none")")
        
        // Process purchase
        purchaseTaskRunning = true
        let attemptProperties: [String: Any] = ["paywall_id": "legacy_main", "purchase_attempt_id": UUID().uuidString, "plan_id": planDetails.productId ?? "", "billing_period": planType.rawValue, "price_billed": planDetails.priceString]
        FunnelAnalytics.shared.track(.purchaseInitiated, attemptProperties)
        Task {
            defer { purchaseTaskRunning = false }
            let success = await viewModel.purchasePlan(planDetails, analyticsContext: attemptProperties)
            
            if success {
                FunnelAnalytics.shared.track(.purchaseCompleted, attemptProperties)
                // Purchase successful - reset abandonment tracking
                onboardingState.resetPaywallTracking()
                
                // Firebase Analytics: purchase success
                Analytics.logEvent("subscription_purchase_success", parameters: [
                    "entry_point": "main_paywall" as NSString,
                    "plan_type": planType.rawValue as NSString,
                    "product_id": (planDetails.productId ?? "") as NSString
                ])
                
                // Navigate directly to home after successful subscription purchase
                print("✅ MainPaywallScreenView: Purchase successful → Navigating to home")
                completeSubscriptionAndExitOnboarding()
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
                    "entry_point": "main_paywall" as NSString,
                    "plan_type": planType.rawValue as NSString,
                    "product_id": (planDetails.productId ?? "") as NSString
                ]
                viewModel.purchaseErrorProperties.forEach { parameters[$0.key] = $0.value as NSString }
                Analytics.logEvent(analyticsEvent, parameters: parameters)
                var properties = attemptProperties
                viewModel.purchaseErrorProperties.forEach { properties[$0.key] = $0.value }
                FunnelAnalytics.shared.track(event, properties)
            }
        }
    }
}

struct PricingCard: View {
    let plan: SubscriptionPlan
    let localizedPrice: String?
    let isSelected: Bool
    let isYearly: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.rawValue)
                            .font(.canela(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.customTextColor)
                        
                        if plan.isBestValue {
                            Text("Best Value")
                                .font(.canela(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.accent)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(localizedPrice ?? "Unavailable")
                        .font(.canela(size: 24, weight: .bold))
                        .foregroundColor(AppColors.customButtonColor)
                }
                
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? LinearGradient.customAppGradient : (isYearly ? LinearGradient(colors: [AppColors.customButtonColor.opacity(0.5)], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [AppColors.customPlaceholderText.opacity(0.3)], startPoint: .leading, endPoint: .trailing)), lineWidth: isSelected ? 2 : (isYearly ? 1.5 : 1))
            )
            .scaleEffect(isYearly ? 1.05 : 1.0)
        }
        .disabled(localizedPrice == nil)
    }
}

#Preview {
    MainPaywallScreenView()
        .environmentObject(OnboardingState.shared)
}
