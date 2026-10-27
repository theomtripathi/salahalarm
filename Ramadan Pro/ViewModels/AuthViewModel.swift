//
//  AuthViewModel.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel for managing authentication UI state
@MainActor
class AuthViewModel: ObservableObject {
    static let shared = AuthViewModel()
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var name: String = ""
    @Published var confirmPassword: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    private let authService = FirebaseAuthService.shared
    
    init() {
        // Keep initializer explicit in case we later observe auth state,
        // but don't bind isLoading to authentication — that caused the
        // "Creating account..." overlay to appear on its own.
    }
    
    // MARK: - Validation
    
    var isEmailValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }
    
    var isPasswordValid: Bool {
        password.count >= 6
    }
    
    var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var passwordsMatch: Bool {
        password == confirmPassword
    }
    
    var canSignIn: Bool {
        isEmailValid && isPasswordValid
    }
    
    var canSignUp: Bool {
        isEmailValid && isPasswordValid && isNameValid && passwordsMatch
    }
    
    // MARK: - Authentication Methods
    
    func signIn() async -> Bool {
        guard canSignIn else {
            errorMessage = "Please enter valid email and password"
            showError = true
            return false
        }
        
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            try await authService.signIn(email: email, password: password)
            isLoading = false
            return true
        } catch let error as AuthErrorType {
            isLoading = false
            errorMessage = error.errorDescription
            showError = true
            return false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    func signUp() async -> Bool {
        guard canSignUp else {
            if !isEmailValid {
                errorMessage = "Please enter a valid email address"
            } else if !isPasswordValid {
                errorMessage = "Password must be at least 6 characters"
            } else if !isNameValid {
                errorMessage = "Please enter your name"
            } else if !passwordsMatch {
                errorMessage = "Passwords do not match"
            }
            showError = true
            return false
        }
        
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            try await authService.signUp(email: email, password: password, name: name)
            isLoading = false
            return true
        } catch let error as AuthErrorType {
            isLoading = false
            errorMessage = error.errorDescription
            showError = true
            return false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    func resetPassword() async {
        guard isEmailValid else {
            errorMessage = "Please enter a valid email address"
            showError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            try await authService.resetPassword(email: email)
            isLoading = false
            errorMessage = "Password reset email sent. Please check your inbox."
            showError = true
        } catch let error as AuthErrorType {
            isLoading = false
            errorMessage = error.errorDescription
            showError = true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func clearError() {
        errorMessage = nil
        showError = false
    }
    
    /// Clear all form fields and errors
    func signInWithGoogle() async -> Bool {
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            try await authService.signInWithGoogle()
            isLoading = false
            return true
        } catch let error as AuthErrorType {
            isLoading = false
            errorMessage = error.errorDescription
            showError = true
            return false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    func signInWithApple() async -> Bool {
        print("🔐 AuthViewModel: signInWithApple() called")
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            try await authService.signInWithApple()
            isLoading = false
            print("✅ AuthViewModel: Apple Sign-In completed successfully")
            return true
        } catch let error as AuthErrorType {
            isLoading = false
            errorMessage = error.errorDescription
            showError = true
            print("❌ AuthViewModel: Apple Sign-In failed - \(error.errorDescription ?? "unknown")")
            return false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
            print("❌ AuthViewModel: Apple Sign-In failed - \(error.localizedDescription)")
            return false
        }
    }
    
    func clearFields() {
        email = ""
        password = ""
        name = ""
        confirmPassword = ""
        errorMessage = nil
        showError = false
        isLoading = false
        print("🧹 AuthViewModel: All fields cleared")
    }
}
