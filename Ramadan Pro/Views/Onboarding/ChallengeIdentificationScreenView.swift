//
//  ChallengeIdentificationScreenView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

/// Screen 5: Challenge Identification
struct ChallengeIdentificationScreenView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    
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
                VStack(spacing: 40) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width:60,height: 60)
                    
                    // Question
                    Text("What usually breaks your consistency?")
                        .font(.canela(size: 28, weight: .bold))
                        .foregroundColor(AppColors.customTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.top, 60)
                        .padding(.horizontal, 32)
                    
                    Spacer()
                    VStack(spacing: 12) {
                        ForEach(ChallengeOption.allCases, id: \.self) { option in
                            ChallengeOptionButton(
                                option: option,
                                isSelected: onboardingState.selectedChallenge == option
                            ) {
                                withAnimation(.spring(response: 0.2)) {
                                    onboardingState.selectedChallenge = option
                                    // Auto advance after selection
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        withAnimation {
                                            onboardingState.nextStep()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    Spacer()
                }
            }
        }
    }
}

struct ChallengeOptionButton: View {
    let option: ChallengeOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(option.rawValue)
                .font(.canela(size: 16, weight: .regular))
                .foregroundColor(AppColors.customTextColor)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.black.opacity(0.3) : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? LinearGradient.customAppGradient : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing), lineWidth: isSelected ? 1.5 : 0)
                )
        }
    }
}

#Preview {
    ChallengeIdentificationScreenView()
        .environmentObject(OnboardingState.shared)
}
