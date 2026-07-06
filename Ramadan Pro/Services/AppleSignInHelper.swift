//
//  AppleSignInHelper.swift
//  Ramadan Pro
//
//  Sign in with Apple – bridges ASAuthorizationController to async/await
//

import Foundation
import UIKit
import AuthenticationServices
import CryptoKit
import FirebaseAuth

/// Result of Sign in with Apple – credential and nonce for Firebase
struct AppleSignInResult {
    let credential: ASAuthorizationAppleIDCredential
    let nonce: String
}

/// Helper to perform Sign in with Apple and return credential for Firebase
final class AppleSignInHelper: NSObject {
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentNonce: String?
    
    func performRequest() async throws -> AppleSignInResult {
        print("🍎 AppleSignInHelper: Generating nonce and creating request...")
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        print("🍎 AppleSignInHelper: Presenting Sign in with Apple sheet...")
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            authorizationController.performRequests()
        }
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
}

extension AppleSignInHelper: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("🍎 AppleSignInHelper: User completed Apple authorization (delegate callback received)")
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ AppleSignInHelper: Invalid credential type - expected ASAuthorizationAppleIDCredential")
            let error = NSError(domain: "AppleSignInHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid credential type"])
            DispatchQueue.main.async { [weak self] in
                self?.continuation?.resume(throwing: error)
                self?.continuation = nil
            }
            return
        }
        guard let nonce = currentNonce else {
            print("❌ AppleSignInHelper: No nonce found - invalid state (login callback received but no request was sent)")
            let error = NSError(domain: "AppleSignInHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid state: no nonce"])
            DispatchQueue.main.async { [weak self] in
                self?.continuation?.resume(throwing: error)
                self?.continuation = nil
            }
            return
        }
        let userId = appleIDCredential.user
        let hasIdentityToken = appleIDCredential.identityToken != nil
        print("✅ AppleSignInHelper: Got credential - user: \(userId), hasIdentityToken: \(hasIdentityToken)")
        let result = AppleSignInResult(credential: appleIDCredential, nonce: nonce)
        DispatchQueue.main.async { [weak self] in
            self?.continuation?.resume(returning: result)
            self?.continuation = nil
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.code == 1001 {
            print("🍎 AppleSignInHelper: User cancelled Sign in with Apple")
        } else {
            print("❌ AppleSignInHelper: Authorization failed - code: \(nsError.code), domain: \(nsError.domain), message: \(error.localizedDescription)")
        }
        DispatchQueue.main.async { [weak self] in
            self?.continuation?.resume(throwing: error)
            self?.continuation = nil
        }
    }
}

extension AppleSignInHelper: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("⚠️ AppleSignInHelper: No window found for presentation anchor")
            return ASPresentationAnchor()
        }
        return window
    }
}
