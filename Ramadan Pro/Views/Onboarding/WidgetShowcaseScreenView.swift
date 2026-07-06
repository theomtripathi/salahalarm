//
//  WidgetShowcaseScreenView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

/// Screen 6: The Aha Moment (Widget) - Shows widget transforming from small to medium to large
struct WidgetShowcaseScreenView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @State private var widgetSize: WidgetSize = .small
    @State private var widgetOpacity: Double = 0
    @State private var countdown: String = "02:45:12"
    @State private var timer: Timer?
    @State private var animationTimer: Timer?
    
    enum WidgetSize: Int, CaseIterable {
        case small = 0
        case medium = 1
        case large = 2
        
        var size: CGSize {
            switch self {
            case .small:
                return CGSize(width: 155, height: 155)
            case .medium:
                return CGSize(width: 329, height: 155)
            case .large:
                return CGSize(width: 329, height: 345)
            }
        }
        
        var title: String {
            switch self {
            case .small:
                return "Small"
            case .medium:
                return "Medium"
            case .large:
                return "Large"
            }
        }
    }
    
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
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Header
                    Text("Everything you need.\nWithout opening the app.")
                        .font(.canela(size: 28, weight: .bold))
                        .foregroundColor(AppColors.customTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                    
                    // Single widget that transforms
                    VStack(spacing: 12) {
                        Text(widgetSize.title)
                            .font(.canela(size: 14, weight: .medium))
                            .foregroundColor(AppColors.customPlaceholderText)
                        
                        // iPhone-style widget container that animates size
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.black.opacity(0.3))
                            .frame(width: widgetSize.size.width, height: widgetSize.size.height)
                            .overlay(
                                widgetContent
                                    .frame(width: widgetSize.size.width - 16, height: widgetSize.size.height - 16)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                            )
                            .shadow(color: AppColors.customButtonColor.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .opacity(widgetOpacity)
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    // Continue button
                    CustomGradientButton(
                        title: "Continue",
                        style: .primary,
                        action: {
                            timer?.invalidate()
                            withAnimation {
                                onboardingState.nextStep()
                            }
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            // Start animation sequence
            startWidgetTransformation()
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
            animationTimer?.invalidate()
        }
    }
    
    // MARK: - Widget Content (changes based on size)
    
    @ViewBuilder
    private var widgetContent: some View {
        Group {
            switch widgetSize {
            case .small:
                smallWidgetContent
            case .medium:
                mediumWidgetContent
            case .large:
                largeWidgetContent
            }
        }
        .background(Color.black)
    }
    
    @ViewBuilder
    private var smallWidgetContent: some View {
        VStack(spacing: 8) {
            // City name
            Text("New York")
                .font(.canela(size: 12))
                .foregroundColor(Color.white.opacity(0.7))
                .lineLimit(1)
            
            // Next prayer countdown
            VStack(spacing: 4) {
                Text("Until Maghrib")
                    .font(.canela(size: 11))
                    .foregroundColor(Color.white.opacity(0.7))
                
                Text(countdown)
                    .font(.canela(size: 24, weight: .bold))
                    .foregroundColor(AppColors.customButtonColor)
                    .monospacedDigit()
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.customButtonColor)
                        .frame(width: geometry.size.width * 0.65)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var mediumWidgetContent: some View {
        VStack(spacing: 12) {
            // City name at top
            Text("New York")
                .font(.canela(size: 12))
                .foregroundColor(Color.white.opacity(0.7))
                .frame(maxWidth: .infinity)
            
            HStack(spacing: 16) {
                // LEFT SIDE: Next Prayer
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Maghrib")
                            .font(.canela(size: 12))
                            .foregroundColor(Color.white.opacity(0.7))
                        
                        Text("6:25 PM")
                            .font(.canela(size: 18, weight: .medium))
                            .foregroundColor(AppColors.customButtonColor)
                    }
                    
                    Text(countdown)
                        .font(.canela(size: 20, weight: .bold))
                        .foregroundColor(AppColors.customButtonColor)
                        .monospacedDigit()
                }
                
                Spacer()
                
                // RIGHT SIDE: Sunset
                VStack(alignment: .trailing, spacing: 6) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Sunset")
                            .font(.canela(size: 12))
                            .foregroundColor(Color.white.opacity(0.7))
                        
                        Text("6:20 PM")
                            .font(.canela(size: 18, weight: .medium))
                            .foregroundColor(AppColors.customButtonColor)
                    }
                    
                    Text("00:15:30")
                        .font(.canela(size: 20, weight: .bold))
                        .foregroundColor(AppColors.customButtonColor)
                        .monospacedDigit()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var largeWidgetContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("New York")
                    .font(.canela(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("SalahAlarm")
                    .font(.canela(size: 12))
                    .foregroundColor(Color.white.opacity(0.7))
            }
            
            // Countdown section
            VStack(alignment: .leading, spacing: 8) {
                Text("Until Maghrib")
                    .font(.canela(size: 12))
                    .foregroundColor(Color.white.opacity(0.7))
                
                Text(countdown)
                    .font(.canela(size: 32, weight: .bold))
                    .foregroundColor(AppColors.customButtonColor)
                    .monospacedDigit()
                
                // Progress bar
                ProgressView(value: 0.65)
                    .tint(AppColors.customButtonColor)
                    .progressViewStyle(.linear)
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Prayer times list
            VStack(alignment: .leading, spacing: 6) {
                Text("Today's Prayer Times")
                    .font(.canela(size: 15, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.7))
                
                prayerTimeRow(prayer: "Imsak", time: "5:20 AM")
                prayerTimeRow(prayer: "Fajr", time: "5:30 AM")
                prayerTimeRow(prayer: "Dhuhr", time: "12:15 PM")
                prayerTimeRow(prayer: "Asr", time: "3:30 PM")
                prayerTimeRow(prayer: "Maghrib", time: "6:25 PM", isHighlighted: true)
                prayerTimeRow(prayer: "Isha", time: "7:45 PM")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    @ViewBuilder
    private func prayerTimeRow(prayer: String, time: String, isHighlighted: Bool = false) -> some View {
        HStack {
            Text(prayer)
                .font(.canela(size: 14))
                .foregroundColor(isHighlighted ? AppColors.customButtonColor : Color.white.opacity(0.7))
            Spacer()
            Text(time)
                .font(.canela(size: 14, weight: .medium))
                .foregroundColor(isHighlighted ? AppColors.customButtonColor : Color.white.opacity(0.9))
        }
    }
    
    // MARK: - Animation
    
    private func startWidgetTransformation() {
        // Fade in small widget first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                widgetOpacity = 1.0
            }
        }
        
        // Start continuous cycling after initial fade-in
        // Wait 2 seconds, then start cycling every 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            self.startCycling()
        }
    }
    
    private func startCycling() {
        // Cycle: small → medium → large → small (repeat)
        // Each transformation happens every 2 seconds
        animationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                switch widgetSize {
                case .small:
                    widgetSize = .medium
                case .medium:
                    widgetSize = .large
                case .large:
                    widgetSize = .small
                }
            }
        }
    }
    
    private func startCountdown() {
        var seconds = 9912 // 2:45:12 in seconds
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            seconds -= 1
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            let secs = seconds % 60
            countdown = String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
    }
}

#Preview {
    WidgetShowcaseScreenView()
        .environmentObject(OnboardingState.shared)
}
