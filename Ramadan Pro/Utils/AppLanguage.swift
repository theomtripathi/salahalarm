import Foundation

/// UI language only. Never changes StoreKit's storefront/currency or Quran text.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case arabic = "ar"
    case turkish = "tr"
    case indonesian = "id"
    case urdu = "ur"

    static let preferenceKey = "sa_app_language"
    static let confirmedKey = "sa_language_confirmed"
    var id: String { rawValue }
    var isRightToLeft: Bool { self == .arabic || self == .urdu }
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .arabic: return "العربية"
        case .turkish: return "Türkçe"
        case .indonesian: return "Bahasa Indonesia"
        case .urdu: return "اردو"
        }
    }
    var englishName: String {
        switch self {
        case .english: return "English"
        case .arabic: return "Arabic"
        case .turkish: return "Turkish"
        case .indonesian: return "Indonesian"
        case .urdu: return "Urdu"
        }
    }
    static func resolve(saved: String?, preferred: [String]) -> AppLanguage {
        if let saved, let language = Self(rawValue: saved) { return language }
        for identifier in preferred {
            let code = identifier.replacingOccurrences(of: "_", with: "-")
                .split(separator: "-").first.map(String.init) ?? ""
            if let language = Self(rawValue: code) { return language }
            if code == "in" { return .indonesian }
        }
        return .english
    }
    static var current: AppLanguage {
        resolve(saved: UserDefaults.standard.string(forKey: preferenceKey), preferred: Locale.preferredLanguages)
    }
    var locale: Locale { Locale(identifier: rawValue) }
}

enum L10n {
    static func text(_ source: String) -> String {
        text(source, language: .current)
    }
    static func text(_ source: String, language: AppLanguage, bundle: Bundle = .main) -> String {
        guard let path = bundle.path(forResource: language.rawValue, ofType: "lproj"),
              let localized = Bundle(path: path) else { return source }
        for table in ["Localizable", "CoreLocalizable"] {
            let value = localized.localizedString(forKey: source, value: source, table: table)
            if value != source { return value }
        }
        return source
    }
    static func format(_ source: String, _ arguments: CVarArg...) -> String {
        String(format: text(source), locale: AppLanguage.current.locale, arguments: arguments)
    }
}
