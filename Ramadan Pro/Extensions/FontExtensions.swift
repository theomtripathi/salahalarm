//
//  FontExtensions.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI

/// Custom font helpers for Inter, Noto Serif, and Canela
///
/// IMPORTANT: Make sure to:
/// 1. Add all font files to Xcode project's "Copy Bundle Resources" build phase
/// 2. Register fonts in Info.plist under "Fonts provided by application" (UIAppFonts)
///    Or add INFOPLIST_KEY_UIAppFonts in build settings if using auto-generated Info.plist
extension Font {
    /// Canela font family (display / headlines)
    /// Uses Canela Trial OTF files from CustomFont/canela-text-trial/
    /// Falls back to system font if Canela is not available
    static func canela(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .thin, .ultraLight:
            fontName = "CanelaTrial-Thin"
        case .light:
            fontName = "CanelaTrial-Light"
        case .regular:
            fontName = "CanelaTrial-Regular"
        case .medium, .semibold:
            fontName = "CanelaTrial-Medium"
        case .bold:
            fontName = "CanelaTrial-Bold"
        case .heavy, .black:
            fontName = "CanelaTrial-Black"
        default:
            fontName = "CanelaTrial-Regular"
        }
        
        // Check if font is available, fallback to system font if not
        if UIFont(name: fontName, size: size) != nil {
            return .custom(fontName, size: size, relativeTo: .body)
        } else {
            // Font not loaded - fallback to system font with serif design
            // This ensures the app still works while fonts are being set up
            #if DEBUG
            print("⚠️ Font '\(fontName)' not found - using system font fallback. See FONT_SETUP_INSTRUCTIONS.md")
            #endif
            return .system(size: size, weight: weight, design: .serif)
        }
    }

    /// Inter font family (sans-serif)
    /// Uses Inter-VariableFont which supports all weights via variable font axes
    /// Note: Don't apply .weight() modifier after - variable fonts handle weight internally
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Inter variable font PostScript name is "Inter" (from Inter-VariableFont file)
        // Variable fonts in SwiftUI work best when created via UIFont first
        // Convert SwiftUI weight to UIFont weight for proper variable font support
        let uiWeight = uiWeightFromSwiftUIWeight(weight)
        
        // Create UIFont with variable font and weight
        // Variable fonts support weight via their internal axes
        if let interFont = UIFont(name: "Inter", size: size) {
            // Apply weight trait to variable font
            let fontDescriptor = interFont.fontDescriptor
            if let weightedDescriptor = fontDescriptor.addingAttributes([
                .traits: [
                    UIFontDescriptor.TraitKey.weight: uiWeight
                ]
            ]) as? UIFontDescriptor {
                let weightedFont = UIFont(descriptor: weightedDescriptor, size: size)
                return Font(weightedFont)
            }
            return Font(interFont)
        }
        
        // Fallback to system font if Inter not available
        return .system(size: size, weight: weight, design: .default)
    }
    
    /// Helper to convert SwiftUI Font.Weight to UIFont.Weight
    private static func uiWeightFromSwiftUIWeight(_ weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
    
    /// Noto Serif font family (serif)
    /// Maps SwiftUI weight to specific Noto Serif font files
    static func notoSerif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Map SwiftUI weight to Noto Serif font file names
        let fontName: String
        switch weight {
        case .thin, .ultraLight:
            fontName = "NotoSerif-Thin"
        case .light:
            fontName = "NotoSerif-Light"
        case .regular:
            fontName = "NotoSerif-Regular"
        case .medium:
            fontName = "NotoSerif-Medium"
        case .semibold:
            fontName = "NotoSerif-SemiBold"
        case .bold:
            fontName = "NotoSerif-Bold"
        case .heavy, .black:
            fontName = "NotoSerif-ExtraBold"
        default:
            fontName = "NotoSerif-Regular"
        }
        
        return .custom(fontName, size: size, relativeTo: .body)
    }
}
