//
//  SplashScreenView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

/// Screen 1: Splash / Trust Builder
struct SplashScreenView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @State private var isAnimating: Bool = false
    @State private var opacity: Double = 0
    var autoAdvance: Bool = true // Allow controlling auto-advance behavior
    
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
                
                // Subtle gold gradient glow from center
                RadialGradient(
                    gradient: Gradient(colors: [
                        AppColors.accent.opacity(0.2),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 50,
                    endRadius: max(reader.size.width, reader.size.height)
                )
            }
            .ignoresSafeArea()
            
            // MARK: - Content GeometryReader
            GeometryReader { contentGeometry in
                VStack(spacing: 24) {
                    Spacer()
                    
                    logoView
                    
                    taglineView
                    
                    Spacer()
                }
                .frame(width: contentGeometry.size.width, height: contentGeometry.size.height)
            }
        }
        .onAppear {
            // Zoom in animation with bounce
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0.1)) {
                self.isAnimating = true
                self.opacity = 1.0
            }
            
            // Auto transition after 2.0s (only if autoAdvance is enabled)
            if autoAdvance {
                print("⏱️ [SPLASH] Setting up auto-advance timer (2 seconds)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Only advance if we're still on splash step (prevent race conditions)
                    if onboardingState.currentStep == .splash {
                        print("⏱️ [SPLASH] Auto-advance timer fired → Moving to next step")
                        withAnimation {
                            onboardingState.nextStep()
                        }
                    } else {
                        print("⏱️ [SPLASH] Auto-advance timer fired but step is already \(onboardingState.currentStep) - ignoring")
                    }
                }
            } else {
                print("⏱️ [SPLASH] Auto-advance is disabled")
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var logoView: some View {
        // App logo in metallic gold with zoom animation
        Image("logo")
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
            .scaleEffect(isAnimating ? 1.2 : 0.1)
            .transition(.scale)
    }
    
    @ViewBuilder
    private var taglineView: some View {
        // Tagline below in white
        Text("Prayer first. Peace follows.")
            .font(.canela(size: 18, weight: .regular))
            .foregroundColor(.white.opacity(0.9))
            .opacity(opacity)
            .padding(.top, 8)
    }
}

#Preview {
    SplashScreenView()
        .environmentObject(OnboardingState.shared)
}
