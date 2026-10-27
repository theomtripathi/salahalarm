//
//  CustomTextField.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

// Custom TextField Representable to handle placeholder color
struct PlaceholderColorTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: UIFont
    let keyboardType: UIKeyboardType
    let placeholderColor: UIColor
    let textColor: UIColor
    let isSecure: Bool
    
    func makeUIView(context: Context) -> UITextField {
        let textField = isSecure ? UITextField() : UITextField()
        if isSecure {
            textField.isSecureTextEntry = true
        }
        textField.delegate = context.coordinator
        textField.font = font
        textField.keyboardType = keyboardType
        textField.textColor = textColor
        textField.autocorrectionType = .no
        textField.autocapitalizationType = keyboardType == .emailAddress ? .none : .words
        textField.spellCheckingType = .no
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor]
        )
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        uiView.isSecureTextEntry = isSecure
        uiView.autocorrectionType = .no
        uiView.autocapitalizationType = keyboardType == .emailAddress ? .none : .words
        uiView.spellCheckingType = .no
        uiView.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor]
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            _text = text
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if let text = textField.text,
               let textRange = Range(range, in: text) {
                let updatedText = text.replacingCharacters(in: textRange, with: string)
                self.text = updatedText
            }
            return true
        }
    }
}

/// Custom text field with custom theme styling
struct CustomTextField<Field: Hashable>: View {
    let title: String
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
    var isError: Bool = false
    
    private var isFocused: Bool {
        guard let field = field else { return false }
        return focusedField == field
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Label
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundColor(AppColors.customTextColor)
            
            // Input field with custom styling
            ZStack(alignment: .trailing) {
                // Use native SwiftUI TextField/SecureField for focus support
                Group {
                    if isSecure && !showPassword {
                        SecureField("", text: $text, prompt: Text(placeholder ?? "Enter your \(title.lowercased())").foregroundColor(AppColors.customPlaceholderText))
                            .textContentType(contentType ?? .none)
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundColor(AppColors.customTextColor)
                            .keyboardType(keyboardType)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    } else {
                        TextField("", text: $text, prompt: Text(placeholder ?? "Enter your \(title.lowercased())").foregroundColor(AppColors.customPlaceholderText))
                            .textContentType(contentType ?? .none)
                            .keyboardType(keyboardType)
                            .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                            .autocorrectionDisabled(keyboardType == .emailAddress)
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundColor(AppColors.customTextColor)
                    }
                }
                .focused($focusedField, equals: field)
                .padding(.horizontal, 16)
                .frame(height: 47)
                .padding(.trailing, (isSecure && showPasswordToggle && isFocused) ? 40 : 0)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                )
                .overlay(
                    // Gradient border (always visible)
                    RoundedRectangle(cornerRadius: 8)
                        .stroke( LinearGradient.customAppGradient ,
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                
                // Eye icon - only on focus for password fields
                if isSecure && showPasswordToggle && isFocused {
                    Button(action: {
                        showPassword.toggle()
                    }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(AppColors.customPlaceholderText)
                    }
                    .padding(.trailing, 16)
                }
            }
            
            // Helper text - only when provided
            if let helperText = helperText {
                Text(helperText)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundColor(isError ? Color.red.opacity(0.8) : AppColors.customPlaceholderText)
                    .padding(.top, 4)
            }
        }
    }
}

#Preview {
    PreviewContainer()
}


