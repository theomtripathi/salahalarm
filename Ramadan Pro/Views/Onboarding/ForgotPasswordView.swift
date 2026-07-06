//
//  ForgotPasswordView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var onboardingState: OnboardingState
    @FocusState private var focusedField: Field?
    @State private var showPassword: Bool = false // Not used for email field, but required by CustomTextField
    
    enum Field {
        case email
    }
    
    var body: some View {
        ZStack {
            // MARK: - Background GeometryReader
            GeometryReader { backgroundGeometry in
                Image("background_image")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: backgroundGeometry.size.width, height: backgroundGeometry.size.height)
                    .clipped()
                
                // MARK: - Dark Overlay for Readability
                Color.black.opacity(0.6)
            }
            .ignoresSafeArea()
            .onTapGesture {
                hideKeyboard()
            }
            
            // MARK: - Content GeometryReader
            GeometryReader { contentGeometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 36) {
                        Spacer(minLength: 60)
                        
                        // MARK: - Logo (App Icon)
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                            .shadow(color: AppColors.customButtonColor.opacity(0.5), radius: 18)
                        
                        // MARK: - Header Section
                        headerSection
                        
                        // MARK: - Reset Form
                        resetForm
                            .padding(.top, 20)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 32)
                }
                .frame(width: contentGeometry.size.width, height: contentGeometry.size.height)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            // Back button
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.canela(size: 16, weight: .medium))
                }
                .foregroundColor(AppColors.customTextColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LinearGradient.customAppGradient.opacity(0.5), lineWidth: 1)
                        )
                )
                .padding(.top, 8)
                .padding(.leading, 20)
            }
        }
        .loadingOverlay(isLoading: viewModel.isLoading, message: "Sending reset email...")
        .alert("Success", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.clearError()
                if viewModel.errorMessage?.contains("sent") == true {
                    dismiss()
                }
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            // Clear fields if user is not authenticated (only clear email for forgot password)
            if !FirebaseAuthService.shared.isAuthenticated {
                viewModel.email = ""
                viewModel.errorMessage = nil
                viewModel.showError = false
                viewModel.isLoading = false
                print("🧹 ForgotPasswordView: Email field cleared")
            }
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Reset Password")
                .font(.canela(size: 32, weight: .bold))
                .foregroundColor(AppColors.customTextColor)
            
            Text("Enter your email and we'll send you a link to reset your password")
                .font(.canela(size: 16, weight: .regular))
                .foregroundColor(AppColors.customPlaceholderText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Reset Form
    
    @ViewBuilder
    private var resetForm: some View {
        VStack(spacing: 24) {
            // Email Field - Custom Text Field
            CustomTextField(
                title: "Email",
                text: $viewModel.email,
                placeholder: "Enter your email",
                contentType: .emailAddress,
                keyboardType: .emailAddress,
                isSecure: false,
                showPasswordToggle: false,
                showPassword: $showPassword,
                field: Field.email,
                focusedField: $focusedField
            )
            
            // Send Reset Link Button - Custom Gradient Button
            CustomGradientButton(
                title: "Send Reset Link",
                style: .primary,
                action: {
                    Task {
                        await viewModel.resetPassword()
                    }
                }
            )
            .disabled(!viewModel.isEmailValid || viewModel.isLoading)
            .opacity((viewModel.isEmailValid && !viewModel.isLoading) ? 1.0 : 0.6)
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(OnboardingState.shared)
}
