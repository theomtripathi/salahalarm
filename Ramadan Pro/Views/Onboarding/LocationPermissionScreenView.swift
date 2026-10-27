//
//  LocationPermissionScreenView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI
import CoreLocation

/// Screen 2: Location Permission
struct LocationPermissionScreenView: View {
    @EnvironmentObject var onboardingState: OnboardingState
    @StateObject private var locationManager = LocationManager.shared
    @State private var hasRequested = false
    
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
                VStack(spacing: 0) {
                    // Top spacing
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width:60,height: 60)
                    
                    // Header
                    headerView
                        .padding(.bottom, 40)
                    
                    // Widget mockup
                    widgetMockup
                        .padding(.bottom, 40)
                    
                    // Bottom spacing
                    Spacer()
                    
                    // CTA section
                    ctaSection
                        .padding(.bottom, 50)
                }
                .frame(width: contentGeometry.size.width, height: contentGeometry.size.height)
            }
        }
        .onAppear {
            print("📍 [LOCATION_PERMISSION] LocationPermissionScreenView appeared")
            print("   - Current onboarding step: \(onboardingState.currentStep)")
            print("   - Location auth status: \(locationManager.authorizationStatus.rawValue)")
            print("   - Stack trace: \(Thread.callStackSymbols.prefix(5).joined(separator: "\n   "))")
        }
        .onChange(of: locationManager.authorizationStatus) { newStatus in
            print("📍 [LOCATION_PERMISSION] Authorization status changed to: \(newStatus.rawValue)")
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                print("📍 [LOCATION_PERMISSION] Location authorized → Moving to next step")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        onboardingState.nextStep()
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerView: some View {
        // Header - Centered, prominent text
        VStack(spacing: 8) {
            Text("Accurate prayer times for your city")
                .font(.canela(size: 36, weight: .bold))
                .foregroundColor(AppColors.customTextColor)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
    }
    
    @ViewBuilder
    private var widgetMockup: some View {
        VStack(spacing: 20) {
            // Widget card mockup - using heroCard style
            VStack(spacing: 16) {
                // Widget header
                HStack {
                    Text("SALAHLOCK")
                        .font(.canela(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(AppColors.customButtonColor.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Widget prayer times mock
                VStack(spacing: 14) {
                    widgetPrayerRow(name: "Imsak", time: "4:30 AM")
                    widgetPrayerRow(name: "Maghrib", time: "6:45 PM")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .frame(width: 300, height: 160)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(LinearGradient.customAppGradient, lineWidth: 1)
                    )
                    .shadow(color: AppColors.customButtonColor.opacity(0.2), radius: 12, x: 0, y: 4)
            )
            
            // City detected placeholder
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.customButtonColor)
                
                Text("City auto detected")
                    .font(.canela(size: 16, weight: .medium))
                    .foregroundColor(AppColors.customTextColor)
            }
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private func widgetPrayerRow(name: String, time: String) -> some View {
        HStack {
            Text(name.uppercased())
                .font(.canela(size: 13, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(AppColors.customTextColor)
            Spacer()
            Text(time)
                .font(.canela(size: 16, weight: .bold))
                .foregroundColor(AppColors.customButtonColor)
        }
    }
    
    @ViewBuilder
    private var ctaSection: some View {
        VStack(spacing: 12) {
            CustomGradientButton(
                title: "Continue",
                style: .primary,
                action: requestLocationPermission
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
        }
    }
    
    private func requestLocationPermission() {
        print("📍 [LOCATION_PERMISSION] User tapped 'Continue' button")
        hasRequested = true
        
        // Check current authorization status
        let currentStatus = locationManager.authorizationStatus
        print("📍 [LOCATION_PERMISSION] Current auth status: \(currentStatus.rawValue)")
        
        // If permission is not determined or denied, request it
        // This will trigger the system alert
        if currentStatus == .notDetermined {
            print("📍 [LOCATION_PERMISSION] Status is notDetermined → Requesting permission")
            locationManager.requestPermission()
        } else if currentStatus == .denied || currentStatus == .restricted {
            print("📍 [LOCATION_PERMISSION] Status is denied/restricted → Attempting to request again")
            // If denied, we can't request again - would need to open Settings
            // For now, just try to request (will show system alert if possible)
            locationManager.requestPermission()
        } else {
            print("📍 [LOCATION_PERMISSION] Already authorized → Moving to next step")
            // Already authorized, move to next step
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    onboardingState.nextStep()
                }
            }
        }
    }
}

#Preview {
    LocationPermissionScreenView()
        .environmentObject(OnboardingState.shared)
}
