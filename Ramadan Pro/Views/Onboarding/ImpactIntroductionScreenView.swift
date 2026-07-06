//
//  ImpactIntroductionScreenView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI
import RevenueCat

/// Screen 4: Impact Introduction (Sadaq Prime)
struct ImpactIntroductionScreenView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @EnvironmentObject var appState: AppState
    @ObservedObject private var authService = FirebaseAuthService.shared
    @StateObject private var sadaqViewModel = SadaqViewModel()
    @State private var mealCount: Int = 0
    @State private var animationTrigger = false
    @State private var showDonationAlert = false
    
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
            
            // MARK: - Content GeometryReader
            GeometryReader { contentGeometry in
                VStack(spacing: 40) {
                    
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width:60,height: 60)
                    
                    headlineView
                    
                    visualSection
                    
                    copyView
                    
                    Spacer()
                    
                    continueButton
                        .padding(.bottom, 50)
                }
                .frame(width: contentGeometry.size.width, height: contentGeometry.size.height)
            }
            
            // MARK: - Donation Alert Overlay (centered on screen)
            if showDonationAlert {
                DonationSelectionAlert(
                    isPresented: $showDonationAlert,
                    onDonate: { productId in
                        await handleDonation(productId: productId)
                    },
                    onDonateLater: {
                        navigateToHome()
                    }
                )
                .zIndex(1000)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showDonationAlert)
            }
        }
        .onAppear {
            animationTrigger = true
            // Animate counter from 0 to 1
            withAnimation(.easeInOut(duration: 1.0)) {
                mealCount = 1
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headlineView: some View {
        Text("Multiply\nyour rewards")
            .font(.canela(size: 36, weight: .bold))
            .foregroundColor(AppColors.customTextColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }
    
    @ViewBuilder
    private var visualSection: some View {
        VStack(spacing: 24) {
            // Gold meal bowl icon
            Image(systemName: "bowl.fill")
                .font(.system(size: 64))
                .foregroundColor(AppColors.customButtonColor)
                .scaleEffect(animationTrigger ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: animationTrigger
                )
            
            // Counter animation: $1 = 1 meal
            HStack(spacing: 8) {
                Text("$1")
                    .font(.canela(size: 32, weight: .bold))
                    .foregroundColor(AppColors.customButtonColor)
                
                Text("=")
                    .font(.canela(size: 32, weight: .regular))
                    .foregroundColor(AppColors.customPlaceholderText)
                
                Text("\(mealCount)")
                    .font(.canela(size: 32, weight: .bold))
                    .foregroundColor(AppColors.customButtonColor)
                    .animation(nil, value: mealCount)
                
                Text("meal")
                    .font(.canela(size: 32, weight: .regular))
                    .foregroundColor(AppColors.customPlaceholderText)
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }
    
    @ViewBuilder
    private var copyView: some View {
        Text("Your small sadaqah feeds\nreal families.")
            .font(.canela(size: 18, weight: .regular))
            .foregroundColor(AppColors.customPlaceholderText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }
    
    @ViewBuilder
    private var continueButton: some View {
        CustomGradientButton(
            title: "Continue",
            style: .primary,
            action: {
                showDonationAlert = true
            }
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
    
    // MARK: - Actions
    
    private func handleDonation(productId: String) async {
        print("💰 [IMPACT_INTRO] Processing donation for product: \(productId)")
        
        // Extract amount from productId
        let amount = extractAmount(from: productId)
        
        // Process donation via SadaqViewModel
        if let donation = await sadaqViewModel.processDonation(amount: amount) {
            print("✅ [IMPACT_INTRO] Donation successful - $\(amount)")
            onboardingState.subscriptionDonationAmount = amount
            
            // Navigate to donation success screen
            onboardingState.currentStep = .donationSuccess
            
            // Then navigate to home after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                navigateToHome()
            }
        } else {
            print("❌ [IMPACT_INTRO] Donation failed")
            // Show error but still allow navigation
            navigateToHome()
        }
    }
    
    private func extractAmount(from productId: String) -> Int {
        // Explicit mapping for known donation products
        if productId.hasSuffix(".100") { return 100 }
        if productId.hasSuffix(".200") { return 200 }
        if productId.hasSuffix(".500") { return 500 }
        if productId.hasSuffix(".1000") { return 1000 }
        
        // Fallback: Extract trailing numeric component (e.g. "com.ramadanpro.donation.250")
        let components = productId.components(separatedBy: ".")
        if let lastComponent = components.last, let amount = Int(lastComponent) {
            return amount
        }
        return 0
    }
    
    // MARK: - Navigation
    
    private func navigateToHome() {
        print("🏠 [IMPACT_INTRO] Navigating to home page after subscription purchase")
        
        // Ensure subscription status is saved to UserDefaults
        // This should already be done by RevenueCatService, but we'll ensure it
        if authService.currentUser?.isSubscribed == true {
            UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
            WidgetConfig.saveIsSubscribed(true)
            print("✅ [IMPACT_INTRO] Subscription status confirmed in UserDefaults")
        }
        
        // Complete onboarding so user doesn't see onboarding flow again
        onboardingState.completeOnboarding()
        
        // Trigger exit from onboarding flow
        appState.shouldExitOnboarding = true
        
        print("✅ [IMPACT_INTRO] Onboarding completed - triggering navigation to home")
    }
}

#Preview {
    ImpactIntroductionScreenView()
        .environmentObject(OnboardingState.shared)
}
