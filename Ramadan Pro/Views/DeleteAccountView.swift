//
//  DeleteAccountView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) var dismiss
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    
    let onDeleteComplete: () -> Void
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.white
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 32) {
                                // Warning icon and message
                                VStack(spacing: 16) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.red)
                                    
                                    Text("Delete Account")
                                        .font(.canela(size: 24, weight: .bold))
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    Text("This action cannot be undone. All your data will be permanently deleted.")
                                        .font(.canela(size: 14, weight: .regular))
                                        .foregroundColor(AppColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }
                                .padding(.top, 40)
                                
                                // Password field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Confirm Password")
                                        .font(.canela(size: 14, weight: .medium))
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    SecureField("Enter your password", text: $password)
                                        .font(.canela(size: 16, weight: .regular))
                                        .foregroundColor(AppColors.textPrimary)
                                        .padding(.horizontal, 16)
                                        .frame(height: 56)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(AppColors.textPrimary.opacity(0.1), lineWidth: 1)
                                                )
                                        )
                                }
                                .padding(.top, 20)
                                
                                // Delete button
                                Button(action: {
                                    Task {
                                        await deleteAccount()
                                    }
                                }) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .tint(.white)
                                                .scaleEffect(0.9)
                                        } else {
                                            Text("Delete Account")
                                                .font(.canela(size: 16, weight: .semibold))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(password.isEmpty || isLoading ? Color.red.opacity(0.5) : Color.red)
                                    )
                                }
                                .disabled(password.isEmpty || isLoading)
                                .padding(.top, 20)
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 40)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    errorMessage = nil
                    showError = false
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(L10n.text(errorMessage))
                }
            }
        }
    }
    
    private func deleteAccount() async {
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            try await FirebaseAuthService.shared.deleteAccount(password: password)
            
            // Clear all local app data (UserDefaults, onboarding, RevenueCat, widget)
            await LogoutService.clearAllLocalState()
            
            await MainActor.run {
                isLoading = false
                dismiss()
                onDeleteComplete()
            }
            
            print("✅ DeleteAccountView: Account deleted successfully")
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
            print("❌ DeleteAccountView: Error deleting account: \(error.localizedDescription)")
        }
    }
}
