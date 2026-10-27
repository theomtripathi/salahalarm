//
//  CustomGradientExtensions.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

extension LinearGradient {
    /// Custom app gradient - horizontal gradient with all 9 gradient colors
    static var customAppGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppColors.customGradientOne,
                AppColors.customGradientTwo,
                AppColors.customGradientThree,
                AppColors.customGradientFour,
                AppColors.customGradientSeven,
                AppColors.customGradientEight,
                AppColors.customGradientNine,
                AppColors.customGradientFive,
                AppColors.customGradientSix,
                AppColors.customGradientOne
            ],
            startPoint: .trailing,
            endPoint: .leading
        )
    }
    
    /// Custom diagonal gradient - top leading to bottom trailing
    static var customDiagonalGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppColors.customGradientOne,
                AppColors.customGradientTwo,
                AppColors.customGradientThree,
                AppColors.customGradientFour,
                AppColors.customGradientSeven,
                AppColors.customGradientEight,
                AppColors.customGradientNine,
                AppColors.customGradientFive,
                AppColors.customGradientSix,
                AppColors.customGradientOne
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Custom vertical gradient - top to bottom
    static var customVerticalGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppColors.customButtonColor,
                AppColors.customTextColor.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Custom diagonal gradient with specific colors
    static func customDiagonalGradient(topColor: Color, bottomColor: Color) -> LinearGradient {
        LinearGradient(
            colors: [topColor, bottomColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Custom diagonal gradient with color array
    static func customDiagonalGradient(colors: [Color]) -> LinearGradient {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Custom vertical gradient with specific colors
    static func customVerticalGradient(topColor: Color, bottomColor: Color) -> LinearGradient {
        LinearGradient(
            colors: [topColor, bottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
