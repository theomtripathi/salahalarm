//
//  FocusSelectionScreenView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

/// Screen 3: Focus Selection
struct FocusSelectionScreenView: View {
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
            
            // MARK: - Content GeometryReader
            GeometryReader { contentGeometry in
                VStack(spacing: 40) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width:60,height: 60)
                    
                    headerView
                    
                    optionsSection
                    
                    Spacer()
                    Spacer()
                    ctaButton
                }
                .frame(width: contentGeometry.size.width, height: contentGeometry.size.height)
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 12) {
            Text("What do you want to focus on this Ramadan?")
                .font(.canela(size: 28, weight: .bold))
                .foregroundColor(AppColors.customTextColor)
                .multilineTextAlignment(.center)
                .padding(.top, 60)
                .padding(.horizontal, 32)
        }
    }
    
    @ViewBuilder
    private var optionsSection: some View {
        VStack(spacing: 16) {
            ForEach(FocusOption.allCases, id: \.self) { option in
                FocusOptionCard(
                    option: option,
                    isSelected: onboardingState.selectedFocus == option
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        onboardingState.selectedFocus = option
                    }
                }
            }
        }
        .padding(.horizontal, 32)
    }
    
    @ViewBuilder
    private var ctaButton: some View {
        CustomGradientButton(
            title: "Continue",
            style: .primary,
            action: {
                withAnimation {
                    onboardingState.nextStep()
                }
            }
        )
        .disabled(onboardingState.selectedFocus == nil)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.bottom, 50)
    }
}

struct FocusOptionCard: View {
    let option: FocusOption
    let isSelected: Bool
    let action: () -> Void
    
    @ViewBuilder
    var body: some View {
        Button(action: action) {
            HStack {
                Text(option.rawValue)
                    .font(.canela(size: 18, weight: .medium))
                    .foregroundColor(AppColors.customTextColor)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.black.opacity(0.3) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? LinearGradient.customAppGradient : LinearGradient(colors: [AppColors.customPlaceholderText.opacity(0.3)], startPoint: .leading, endPoint: .trailing), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

#Preview {
    FocusSelectionScreenView()
        .environmentObject(OnboardingState.shared)
}
