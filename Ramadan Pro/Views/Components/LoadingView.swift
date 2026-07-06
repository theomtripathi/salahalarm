//
//  LoadingView.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

/// Centralized loading view component
struct LoadingView: View {
    var message: String = "Loading..."
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Loading content
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                    .scaleEffect(1.5)
                
                if !message.isEmpty {
                    Text(message)
                        .font(.canela(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 48)
        }
    }
}

/// View modifier to show loading overlay
extension View {
    func loadingOverlay(isLoading: Bool, message: String = "Loading...") -> some View {
        self.overlay(
            Group {
                if isLoading {
                    LoadingView(message: message)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: isLoading)
        )
    }
}

#Preview {
    ZStack {
        Color.white
            .ignoresSafeArea()
        
        Text("Content")
            .loadingOverlay(isLoading: true, message: "Signing in...")
    }
}
