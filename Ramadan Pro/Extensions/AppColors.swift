//
//  AppColors.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import SwiftUI

/// App theme colors with hex codes
/// Add these colors to Assets.xcassets color set folder
///
/// Note: These were previously declared as `extension Color { ... }` with
/// static properties like `Color.appTextPrimary`. If a duplicate extension
/// exists elsewhere in the project, that causes "Invalid redeclaration" errors.
/// To avoid collisions, we provide a namespaced container `AppColors` instead.
/// Update call sites to use `AppColors.textPrimary` etc.
public struct AppColors {
    // MARK: - Background Colors
    /// White background: #FFFFFF
    public static var background: Color { Color("AppBackgroundColor") }
    
    // MARK: - Text Colors
    /// Black text: #1D1D1F (soft black for better readability)
    public static var textPrimary: Color { Color("AppTextPrimaryColor") }
    /// Secondary text: #6E6E73
    public static var textSecondary: Color { Color("AppTextSecondaryColor") }
    
    // MARK: - Accent Colors
    /// Golden accent: #c4a468 (luxury gold from design)
    public static var accent: Color { Color("AppAccentColor") }
    /// Golden accent light: #E8D5B7
    public static var accentLight: Color { Color("AppAccentLightColor") }
    /// Golden accent dark: #B8955C
    public static var accentDark: Color { Color("AppAccentDarkColor") }
    
    // MARK: - Card Colors
    /// Card background: #F5F5F7
    public static var cardBackground: Color { Color("AppCardBackgroundColor") }
    
    // MARK: - Premium Dark Mode Colors (Sign-In Screen)
    /// Background black: #0A0A0C
    public static var backgroundBlack: Color { Color(red: 10/255, green: 10/255, blue: 12/255) }
    /// Charcoal: #121216
    public static var charcoal: Color { Color(red: 18/255, green: 18/255, blue: 22/255) }
    
    /// Gold primary: #CDAA5F
    public static var goldPrimary: Color { Color(red: 205/255, green: 170/255, blue: 95/255) }
    /// Gold secondary: #EBCD8C
    public static var goldSecondary: Color { Color(red: 235/255, green: 205/255, blue: 140/255) }
    
    /// Off white: #F5F2EB
    public static var offWhite: Color { Color(red: 245/255, green: 242/255, blue: 235/255) }
    /// Muted gray: #A0A0A5
    public static var mutedGray: Color { Color(red: 160/255, green: 160/255, blue: 165/255) }
    
    // MARK: - Custom Theme Colors
    /// Text color: #FFFFFF (white)
    public static var customTextColor: Color { Color.white }
    
    /// Button color: #D89534
    public static var customButtonColor: Color { Color(red: 216/255, green: 149/255, blue: 52/255) }
    
    /// Button background: #262626
    public static var customButtonBackground: Color { Color(red: 38/255, green: 38/255, blue: 38/255) }
    
    /// Placeholder text: #FFFFFF 70% opacity
    public static var customPlaceholderText: Color { Color.white.opacity(0.7) }
    
    // MARK: - Custom Gradient Colors
    /// Gradient Color One: #C08329
    public static var customGradientOne: Color { Color(red: 192/255, green: 131/255, blue: 41/255) }
    /// Gradient Color Two: #C2872F
    public static var customGradientTwo: Color { Color(red: 194/255, green: 135/255, blue: 47/255) }
    /// Gradient Color Three: #C68E3C
    public static var customGradientThree: Color { Color(red: 198/255, green: 142/255, blue: 60/255) }
    /// Gradient Color Four: #C89346
    public static var customGradientFour: Color { Color(red: 200/255, green: 147/255, blue: 70/255) }
    /// Gradient Color Five: #CA974C
    public static var customGradientFive: Color { Color(red: 202/255, green: 151/255, blue: 76/255) }
    /// Gradient Color Six: #CA974D
    public static var customGradientSix: Color { Color(red: 202/255, green: 151/255, blue: 77/255) }
    /// Gradient Color Seven: #EBC17D
    public static var customGradientSeven: Color { Color(red: 235/255, green: 193/255, blue: 125/255) }
    /// Gradient Color Eight: #F4E6D0
    public static var customGradientEight: Color { Color(red: 244/255, green: 230/255, blue: 208/255) }
    /// Gradient Color Nine: #EDD089
    public static var customGradientNine: Color { Color(red: 237/255, green: 208/255, blue: 137/255) }

    // MARK: - SalahLock Onboarding Palette
    public static var slGreen: Color { Color(hex: "#1A9E3F") }
    public static var slGold: Color { Color(hex: "#C9A028") }
    public static var slCream: Color { Color(hex: "#F9F7F2") }
    public static var slTextPrimary: Color { Color(hex: "#111111") }
    public static var slTextSecondary: Color { Color(hex: "#666666") }
    public static var slBorderDefault: Color { Color(hex: "#E0E0E0") }
    public static var slBorderSelected: Color { Color(hex: "#1A9E3F") }
    public static var slBackground: Color { .white }
    public static var slCardBackground: Color { .white }
    public static var slProgressBar: Color { Color(hex: "#C9A028") }
    public static var slDeepGreen: Color { Color(hex: "#157832") }
    public static var slGradientTop: Color { Color(hex: "#22A847") }
    public static var slTabUnselected: Color { Color(hex: "#999999") }
    public static var saAlarmRed: Color { Color(hex: "#E53935") }
    public static var saAlarmRedLight: Color { Color(hex: "#FFEBEE") }
}
