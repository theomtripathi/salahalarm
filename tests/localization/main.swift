import Foundation

@main
struct LanguageTests {
    static func main() {
        precondition(AppLanguage.resolve(saved: "tr", preferred: ["ar-SA"]) == .turkish)
        precondition(AppLanguage.resolve(saved: "bad", preferred: ["fr-FR", "ur-PK"]) == .urdu)
        precondition(AppLanguage.resolve(saved: nil, preferred: ["id-ID"]) == .indonesian)
        precondition(AppLanguage.resolve(saved: nil, preferred: ["in_ID"]) == .indonesian)
        precondition(AppLanguage.resolve(saved: nil, preferred: ["de-DE"]) == .english)
        precondition(AppLanguage.arabic.isRightToLeft && AppLanguage.urdu.isRightToLeft)
        precondition(!AppLanguage.turkish.isRightToLeft && !AppLanguage.indonesian.isRightToLeft)
        if CommandLine.arguments.count > 1 {
            let bundle = Bundle(path: CommandLine.arguments[1])!
            precondition(L10n.text("Continue", language: .arabic, bundle: bundle) != "Continue")
            precondition(L10n.text("Home", language: .urdu, bundle: bundle) != "Home")
            precondition(L10n.text("__missing_key__", language: .turkish, bundle: bundle) == "__missing_key__")
            // No selected-language translation may change actual product/currency strings.
            precondition(L10n.text("yearlydiscountedtrial", language: .arabic, bundle: bundle) == "yearlydiscountedtrial")
            precondition(L10n.text("₹1,999.00", language: .urdu, bundle: bundle) == "₹1,999.00")
        }
        print("PASS: language selection, device fallback, RTL, bundle lookup, and literal-price preservation")
    }
}
