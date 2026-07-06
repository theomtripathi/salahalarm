//
//  CustomizationLoaderScreenView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

/// Screen 7: Customization Loader
struct CustomizationLoaderScreenView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @State private var progress: Double = 0
    @State private var currentTextIndex = 0
    @State private var timer: Timer?
    
    private let loadingTexts = [
        "Setting prayer times",
        "Aligning fasting schedule",
        "Preparing widget"
    ]
    
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
                    Spacer()
                    
                    // Progress bar
                    VStack(spacing: 24) {
                        // Gold progress bar
                        GeometryReader { barGeometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 8)
                                
                                // Progress fill
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.customButtonColor)
                                    .frame(width: barGeometry.size.width * progress, height: 8)
                                    .animation(.linear(duration: 0.3), value: progress)
                            }
                        }
                        .frame(height: 8)
                        .padding(.horizontal, 32)
                        
                        // Rotating text
                        Text(loadingTexts[currentTextIndex])
                            .font(.canela(size: 16, weight: .regular))
                            .foregroundColor(AppColors.customPlaceholderText)
                            .animation(.easeInOut(duration: 0.3), value: currentTextIndex)
                    }
                    .padding(.vertical, 60)
                    
                    // Percentage
                    Text("\(Int(progress * 100))%")
                        .font(.canela(size: 48, weight: .light))
                        .foregroundColor(AppColors.customButtonColor)
                        .padding(.top, 20)
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            startProgress()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Private Methods
    
    private func startProgress() {
        var elapsed: Double = 0
        let duration: Double = 3.0 // 3 seconds total
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            elapsed += 0.05
            progress = min(elapsed / duration, 1.0)
            
            // Rotate text based on progress
            let newIndex = Int((elapsed / duration) * Double(loadingTexts.count))
            if newIndex < loadingTexts.count && newIndex != currentTextIndex {
                withAnimation {
                    currentTextIndex = newIndex
                }
            }
            
            // Complete and advance
            if progress >= 1.0 {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        onboardingState.nextStep()
                    }
                }
            }
        }
    }
}

#Preview {
    CustomizationLoaderScreenView()
        .environmentObject(OnboardingState.shared)
}
