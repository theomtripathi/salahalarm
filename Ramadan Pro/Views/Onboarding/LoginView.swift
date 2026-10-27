//
//  LoginView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI
import UIKit
import FirebaseAuth

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @EnvironmentObject var onboardingState: OnboardingState
    @EnvironmentObject var appState: AppState
    @State private var showForgotPassword = false
    @State private var showPassword = false
    var onAuthenticated: (() -> Void)? = nil
    @FocusState private var focusedField: Field?

    enum Field {
        case email
        case password
    }

    var body: some View {
        ZStack {
            AppColors.slBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer().frame(height: 24)

                    VStack(spacing: 12) {
                        SalahLockBrandMark(size: 84)
                        Text("SalahAlarm")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.slGreen)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Welcome Back")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(AppColors.slTextPrimary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text("sign in to keep your prayer plan, streak, and alarms in sync.")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.slTextSecondary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 12) {
                        authProviderButton(provider: .google) {
                            Task {
                                let success = await viewModel.signInWithGoogle()
                                if success {
                                    handleAuthSuccess()
                                }
                            }
                        }

                        authProviderButton(provider: .apple) {
                            Task {
                                let success = await viewModel.signInWithApple()
                                if success {
                                    handleAuthSuccess()
                                }
                            }
                        }
                    }

                    VStack(spacing: 16) {
                        authField(
                            title: "Email",
                            text: $viewModel.email,
                            placeholder: "you@example.com",
                            contentType: .emailAddress,
                            keyboardType: .emailAddress,
                            isSecure: false
                        )
                        .focused($focusedField, equals: .email)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Password")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppColors.slTextPrimary)
                                Spacer()
                                Button("Forgot?") {
                                    showForgotPassword = true
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.slGreen)
                            }

                            authField(
                                title: nil,
                                text: $viewModel.password,
                                placeholder: "enter your password",
                                contentType: .password,
                                keyboardType: .default,
                                isSecure: !showPassword,
                                trailingButtonTitle: showPassword ? "Hide" : "Show",
                                trailingButtonAction: {
                                    showPassword.toggle()
                                }
                            )
                            .focused($focusedField, equals: .password)
                        }

                        SLPrimaryButton(
                            title: "sign in",
                            isEnabled: viewModel.canSignIn,
                            isLoading: viewModel.isLoading
                        ) {
                            Task {
                                let success = await viewModel.signIn()
                                if success {
                                    handleAuthSuccess()
                                }
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        Text("don't have an account?")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.slTextSecondary)

                        Button("create one now") {
                            onboardingState.currentStep = .login
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.slGreen)
                        .underline()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 24)
            }
        }
        .loadingOverlay(isLoading: viewModel.isLoading, message: "Signing in...")
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(L10n.text(errorMessage))
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
                .environmentObject(onboardingState)
        }
        .onAppear {
            if !FirebaseAuthService.shared.isAuthenticated {
                viewModel.clearFields()
            }
        }
    }

    private func handleAuthSuccess() {
        if let onAuthenticated {
            onAuthenticated()
            return
        }

        Task {
            let authService = FirebaseAuthService.shared
            
            // Give Firebase a tiny moment to settle auth state before fetching RevenueCat
            if let userId = authService.currentUser?.userId ?? Auth.auth().currentUser?.uid {
                try? await RevenueCatService.shared.setUserID(userId)
            }
            await RevenueCatService.shared.checkSubscriptionStatus()
            
            let isSubscribed = authService.currentUser?.isSubscribed ?? false || RevenueCatService.shared.subscriptionStatus.isActive
            
            await MainActor.run {
                if isSubscribed {
                    print("🔐 [LOGIN] User signed in and has subscription → Main app will handle navigation")
                    UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
                    appState.onboardingComplete = true
                    onboardingState.completeOnboarding()
                    appState.shouldExitOnboarding = true
                } else {
                    print("🔐 [LOGIN] User signed in but no subscription → Setting step to .locationPermission")
                    onboardingState.currentStep = .locationPermission
                }
            }
        }
    }

    private func authProviderButton(provider: SLAuthProvider, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Group {
                    if provider == .google {
                        Image("google_icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.slTextPrimary)
                    }
                }
                .frame(width: 24)

                Text(L10n.text(provider.title))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.slTextPrimary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.slBorderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .opacity(viewModel.isLoading ? 0.7 : 1)
    }

    private func authField(
        title: String?,
        text: Binding<String>,
        placeholder: String,
        contentType: UITextContentType,
        keyboardType: UIKeyboardType,
        isSecure: Bool,
        trailingButtonTitle: String? = nil,
        trailingButtonAction: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(L10n.text(title))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.slTextPrimary)
            }

            HStack(spacing: 12) {
                Group {
                    if isSecure {
                        SecureField(placeholder, text: text)
                    } else {
                        TextField(placeholder, text: text)
                            .autocapitalization(.none)
                    }
                }
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .font(.system(size: 16))
                .foregroundColor(AppColors.slTextPrimary)

                if let trailingButtonTitle, let trailingButtonAction {
                    Button(trailingButtonTitle, action: trailingButtonAction)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.slGreen)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.slBorderDefault, lineWidth: 1)
            )
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(OnboardingState.shared)
}
