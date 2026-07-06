//
//  SubscriptionDonationSuccessView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

/// Donation success screen shown after subscription purchase
struct SubscriptionDonationSuccessView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @EnvironmentObject var appState: AppState
    
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
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Success message
                    VStack(spacing: 16) {
                        Text("You just fed \(onboardingState.subscriptionDonationAmount) people")
                            .font(.canela(size: 32, weight: .bold))
                            .foregroundColor(AppColors.customTextColor)
                            .multilineTextAlignment(.center)
                        
                        Text("May it be accepted")
                            .font(.canela(size: 18, weight: .regular))
                            .foregroundColor(AppColors.customPlaceholderText)
                    }
                    
                    Spacer()
                    
                    // Action button
                    VStack(spacing: 16) {
                        // Done button - completes onboarding and goes to main app
                        CustomGradientButton(
                            title: "Done",
                            style: .primary,
                            action: {
                                // Complete onboarding and go to main app (do NOT show delayed discount)
                                onboardingState.completeOnboarding()
                                appState.shouldExitOnboarding = true
                            }
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
                .frame(width: contentGeometry.size.width, height: contentGeometry.size.height)
            }
        }
    }
}

#Preview {
    SubscriptionDonationSuccessView()
        .environmentObject(OnboardingState.shared)
}
