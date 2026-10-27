//
//  CustomButton.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

/// "Continue with Apple" button - dark bg, thin gold border, Apple icon, off‑white text
struct AppleSignInButton: View {
    let action: () -> Void
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(red: 0.96, green: 0.94, blue: 0.90))

                Text("Continue with Apple")
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(Color(red: 0.96, green: 0.94, blue: 0.90))
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LinearGradient.customAppGradient, lineWidth: 1)
            )
            .shadow(color: AppColors.customButtonColor.opacity(0.35), radius: 6, x: 0, y: 0)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
    }
}

/// "Continue with Google" button - dark bg, thin gold border, google_icon left, off‑white text
struct GoogleSignInButton: View {
    let action: () -> Void
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("google_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text("Continue with Google")
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(Color(red: 0.96, green: 0.94, blue: 0.90))
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LinearGradient.customAppGradient, lineWidth: 1)
            )
            .shadow(color: AppColors.customButtonColor.opacity(0.35), radius: 6, x: 0, y: 0)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
    }
}

/// Custom button - rounded rectangle with gradient border and shadow
struct CustomButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var backgroundColor: Color = AppColors.customButtonColor
    var textColor: Color = AppColors.customTextColor
    var maxWidth: CGFloat = 270
    var height: CGFloat = 52
    var cornerRadius: CGFloat = 38
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .default))
                .foregroundColor(textColor)
                .frame(maxWidth: maxWidth)
                .frame(height: height)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(isEnabled ? backgroundColor : backgroundColor.opacity(0.5))
                        .overlay(
                            // Custom gradient border
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(LinearGradient.customAppGradient, lineWidth: 1)
                        )
                        .shadow(
                            color: Color.black.opacity(0.25),
                            radius: 5.7,
                            x: 6,
                            y: 3
                        )
                )
        }
        .disabled(!isEnabled)
    }
}

/// Custom pill button
struct CustomPillButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false
    var width: CGFloat = 86
    var height: CGFloat = 28
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundColor(AppColors.customTextColor)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: 38)
                        .fill(title.lowercased() == "remove" ? Color.clear : AppColors.customButtonColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 38)
                        .stroke(
                            AppColors.customButtonColor,
                            lineWidth: 1
                        )
                )
                .overlay(
                    // Inner shadow effect
                    RoundedRectangle(cornerRadius: 38)
                        .fill(Color.black.opacity(0.25))
                        .blur(radius: 5.7)
                        .offset(x: 6, y: 3)
                        .mask(
                            RoundedRectangle(cornerRadius: 38)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [Color.black, Color.clear]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        )
                )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}

/// Gradient button - supports primary and secondary styles
struct CustomGradientButton: View {
    let title: String
    let style: ButtonStyle
    let action: () -> Void
    var height: CGFloat = 52
    
    enum ButtonStyle {
        case primary    // Button color background
        case secondary  // Clear background with gradient border
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(AppColors.customTextColor)
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .background(buttonBackground)
                
                .overlay(
                    RoundedRectangle(cornerRadius: 38)
                        .stroke(
                            LinearGradient.customAppGradient,
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: Color.black.opacity(0.25),
                    radius: 5.7,
                    x: 6,
                    y: 3
                )
                
                .cornerRadius(38)
                .padding(.horizontal,35)
        }
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        switch style {
        case .primary:
            AppColors.customButtonColor
        case .secondary:
            Color.clear
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GoogleSignInButton(action: { })
        
        CustomButton(
            title: "Disabled Button",
            action: { },
            isEnabled: false
        )
        
        HStack(spacing: 12) {
            CustomGradientButton(
                title: "Cancel",
                style: .secondary,
                action: { }
            )
            
            CustomGradientButton(
                title: "Sign In",
                style: .primary,
                action: { }
            )
        }
        
        CustomPillButton(title: "Join List") {
            // Action
        }
    }
    .padding()
    .background(Color.black)
}
