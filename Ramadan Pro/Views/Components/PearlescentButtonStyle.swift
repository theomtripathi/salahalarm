//
//  PearlescentButtonStyle.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

/// Premium pearlescent gold button style for dark mode screens
struct PearlescentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(AppColors.backgroundBlack)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        AppColors.goldSecondary,
                        AppColors.goldPrimary,
                        AppColors.goldSecondary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(18)
            .shadow(color: AppColors.goldPrimary.opacity(0.35), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        Button {
            // Action
        } label: {
            Text("Continue with Google")
                .font(.system(size: 16, weight: .medium))
        }
        .buttonStyle(PearlescentButtonStyle())
        
        Button {
            // Action
        } label: {
            Text("Sign In")
                .font(.system(size: 16, weight: .semibold))
        }
        .buttonStyle(PearlescentButtonStyle())
    }
    .padding()
    .background(AppColors.backgroundBlack)
}
