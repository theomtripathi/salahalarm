//
//  SideMenuView.swift
//  Ramadan Pro
//
//  Created by Cursor on 2026-01-24.
//

import SwiftUI

struct SideMenuView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var onboardingState: OnboardingState
    @ObservedObject private var authService = FirebaseAuthService.shared
    @State private var showDeleteAccountConfirmation = false
    @State private var showDeleteAccountView = false
    
    private let menuWidth: CGFloat = 300
    
    var body: some View {
        ZStack(alignment: .leading) {
            if appState.isSideMenuOpen {
                // Dimmed backdrop
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            appState.isSideMenuOpen = false
                        }
                    }
            }
            
            menuContent
                .frame(width: menuWidth)
                .offset(x: appState.isSideMenuOpen ? 0 : -menuWidth - 20)
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: appState.isSideMenuOpen)
        }
        .allowsHitTesting(appState.isSideMenuOpen)
        .accessibilityHidden(!appState.isSideMenuOpen)
    }
    
    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 12)
            
            VStack(spacing: 10) {
                menuButton(title: "Privacy Policy", icon: "lock.shield.fill") {
                    openPrivacyPolicy()
                }
                
                menuButton(title: "Terms of Use", icon: "doc.text.fill") {
                    openTermsOfUse()
                }
                
                menuButton(title: "Support", icon: "questionmark.circle.fill") {
                    openSupportURL()
                }
            }
            .padding(.top, 10)
            
            Spacer()
            
            Divider()
                .background(AppColors.customPlaceholderText.opacity(0.25))
                .padding(.vertical, 14)
            
            Button(role: .destructive) {
                showDeleteAccountConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Delete Account")
                        .font(.canela(size: 15, weight: .semibold))
                    Spacer()
                }
                .foregroundColor(.red)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                )
            }
            .padding(.bottom, 8)
            
            Button(role: .destructive) {
                performLogout()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.right.square")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Logout")
                        .font(.canela(size: 15, weight: .semibold))
                    Spacer()
                }
                .foregroundColor(.red)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                )
            }
            .padding(.bottom, 18)
        }
        .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {
                showDeleteAccountConfirmation = false
            }
            Button("Continue", role: .destructive) {
                showDeleteAccountConfirmation = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    appState.isSideMenuOpen = false
                }
                showDeleteAccountView = true
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted. You will need to enter your password to confirm.")
        }
        .sheet(isPresented: $showDeleteAccountView) {
            DeleteAccountView {
                onboardingState.hasCompletedOnboarding = false
            }
        }
        .padding(.top, 14)
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(LinearGradient.customAppGradient.opacity(0.8), lineWidth: 1)
                )
                .shadow(color: AppColors.customButtonColor.opacity(0.22), radius: 18, x: 8, y: 0)
        )
        .padding(.leading, 12)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SalahLockBrandMark(size: 28)
                
                Text("SalahAlarm")
                    .font(.canela(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.customTextColor)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        appState.isSideMenuOpen = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.customPlaceholderText)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(authService.currentUser?.name ?? "User")
                    .font(.canela(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.customTextColor)
                
                if let email = authService.currentUser?.email {
                    Text(email)
                        .font(.canela(size: 12, weight: .regular))
                        .foregroundColor(AppColors.customPlaceholderText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
    }
    
    private func menuButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.customButtonColor)
                    .frame(width: 22)
                
                Text(title)
                    .font(.canela(size: 15, weight: .medium))
                    .foregroundColor(AppColors.customTextColor)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.customPlaceholderText.opacity(0.9))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
    
    private func openPrivacyPolicy() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            appState.isSideMenuOpen = false
        }
        if let url = URL(string: "https://ramadan-pro.lovable.app/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTermsOfUse() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            appState.isSideMenuOpen = false
        }
        if let url = URL(string: "https://ramadan-pro.lovable.app/terms") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openSupportURL() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            appState.isSideMenuOpen = false
        }
        if let url = URL(string: "https://ramadan-pro.lovable.app/support") {
            UIApplication.shared.open(url)
        }
    }
    
    private func performLogout() {
        Task { @MainActor in
            do {
                try await LogoutService.clearAllAndSignOut()
            } catch {
                print("❌ SideMenuView: Logout failed: \(error.localizedDescription)")
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    appState.isSideMenuOpen = false
                }
                onboardingState.hasCompletedOnboarding = false
                onboardingState.currentStep = .login
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SideMenuView()
            .environmentObject(AppState.shared)
            .environmentObject(NavigationCoordinator.shared)
            .environmentObject(OnboardingState.shared)
    }
}
