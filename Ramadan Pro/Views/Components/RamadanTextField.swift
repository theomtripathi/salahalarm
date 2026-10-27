//
//  RamadanTextField.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

/// Premium Ramadan-themed text field with pearlescent styling
struct RamadanTextField<Field: Hashable>: View {
    let label: String
    @Binding var text: String
    var placeholder: String? = nil
    var contentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var showPasswordToggle: Bool = false
    @Binding var showPassword: Bool
    var field: Field?
    @FocusState.Binding var focusedField: Field?
    var helperText: String? = nil
    var isDarkMode: Bool = false // For dark background screens
    
    private var isFocused: Bool {
        guard let field = field else { return false }
        return focusedField == field
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label (only show if not empty)
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundColor(isDarkMode ? AppColors.customTextColor : Color(hex: "555555"))
                    .kerning(0.04) // 4% letter spacing
            }
            
            // Input Field
            ZStack(alignment: .trailing) {
                Group {
                    if isSecure && !showPassword {
                        SecureField("", text: $text, prompt: Text(placeholder ?? "Enter your \(label.lowercased())").foregroundColor(isDarkMode ? AppColors.customPlaceholderText : Color(hex: "9A9A9A")))
                            .textContentType(contentType ?? .none)
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundColor(isDarkMode ? AppColors.customTextColor : Color(hex: "1A1A1A"))
                    } else {
                        TextField("", text: $text, prompt: Text(placeholder ?? "Enter your \(label.lowercased())").foregroundColor(isDarkMode ? AppColors.customPlaceholderText : Color(hex: "9A9A9A")))
                            .textContentType(contentType ?? .none)
                            .keyboardType(keyboardType)
                            .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                            .autocorrectionDisabled(keyboardType == .emailAddress)
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundColor(isDarkMode ? AppColors.customTextColor : Color(hex: "1A1A1A"))
                    }
                }
                .frame(height: 54)
                .padding(.trailing, (isSecure && showPasswordToggle && isFocused) ? 36 : 0)
                .focused($focusedField, equals: field)
                .overlay(
                    Group {
                        if isFocused && isDarkMode {
                            // Use custom gradient for focused state in dark mode
                            Rectangle()
                                .fill(LinearGradient.customAppGradient)
                                .frame(height: 1)
                                .offset(y: 27)
                        } else {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(isFocused ? AppColors.customButtonColor : (isDarkMode ? AppColors.customPlaceholderText.opacity(0.3) : Color(hex: "DDD4C4")))
                                .offset(y: 27)
                        }
                    },
                    alignment: .bottom
                )
                
                // Eye icon - only on focus for password fields
                if isSecure && showPasswordToggle && isFocused {
                    Button(action: {
                        showPassword.toggle()
                    }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(isDarkMode ? AppColors.customPlaceholderText : Color(hex: "9A9A9A"))
                    }
                    .offset(x: -8)
                }
            }
            
            // Helper text - only when provided
            if let helperText = helperText {
                Text(helperText)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundColor(isDarkMode ? AppColors.customPlaceholderText : Color(hex: "8A8A8A"))
                    .padding(.top, 4)
            }
        }
    }
}

#Preview {
    PreviewContainer()
}

struct PreviewContainer: View {
    enum PreviewField: Hashable {
        case name
        case password
    }
    
    @State private var nameText = ""
    @State private var passwordText = ""
    @State private var showPassword = false
    @FocusState private var focusedField: PreviewField?
    
    var body: some View {
        VStack(spacing: 24) {
            RamadanTextField(
                label: "Name",
                text: $nameText,
                showPassword: .constant(false),
                field: PreviewField.name,
                focusedField: $focusedField
            )
            
            RamadanTextField(
                label: "Password",
                text: $passwordText,
                placeholder: "Enter password",
                contentType: .newPassword,
                isSecure: true,
                showPasswordToggle: true,
                showPassword: $showPassword,
                field: PreviewField.password,
                focusedField: $focusedField,
                helperText: "At least 6 characters"
            )
        }
        .padding()
    }
}
