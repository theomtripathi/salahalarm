import SwiftUI

struct LanguagePickerView: View {
    var source = "onboarding"
    var onContinue: () -> Void = {}
    @AppStorage(AppLanguage.preferenceKey) private var languageCode = AppLanguage.current.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "globe")
                    .font(.largeTitle)
                    .foregroundStyle(AppColors.slGreen)
                    .accessibilityHidden(true)
                Text(L10n.text("Choose your language"))
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.text("Start your journey in the language you feel at home with."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        let previous = AppLanguage.current.rawValue
                        languageCode = language.rawValue
                        FunnelAnalytics.shared.track(.onboardingLanguageSelected, [
                            "language_code": language.rawValue, "previous_language": previous, "source": source
                        ])
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: language.nativeName).font(.headline)
                                if language != .english {
                                    Text(verbatim: language.englishName).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                            Image(systemName: languageCode == language.rawValue ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(AppColors.slGreen)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.slGreen.opacity(languageCode == language.rawValue ? 0.08 : 0.02)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.slGreen.opacity(languageCode == language.rawValue ? 1 : 0.2)))
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(languageCode == language.rawValue ? .isSelected : [])
                }
                Text(L10n.text("You can change this anytime in Profile."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .background(Color(.systemBackground))
        .safeAreaInset(edge: .bottom) {
            Button {
                // Choosing a language is not consent to tracking or a subscription.
                UserDefaults.standard.set(true, forKey: AppLanguage.confirmedKey)
                FunnelAnalytics.shared.track(.onboardingLanguageConfirmed, ["language_code": languageCode, "source": source])
                onContinue()
                dismiss()
            } label: {
                Text(L10n.text(source == "onboarding" ? "Continue" : "Done"))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(18)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.white)
                    .background(AppColors.slGreen, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .onAppear { FunnelAnalytics.shared.onboardingSurfaceViewed(name: "language_selection") }
    }
}

struct LanguagePickerButton: View {
    @State private var isPresented = false
    @AppStorage(AppLanguage.preferenceKey) private var languageCode = AppLanguage.current.rawValue
    var body: some View {
        Button { isPresented = true } label: {
            Label(AppLanguage(rawValue: languageCode)?.nativeName ?? AppLanguage.current.nativeName, systemImage: "globe")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
        }
        .foregroundStyle(AppColors.slGreen)
        .accessibilityLabel(L10n.text("App language"))
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                LanguagePickerView(source: "in_app")
                    .toolbar { ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.text("Done")) { isPresented = false }
                    } }
            }
            .environment(\.locale, AppLanguage.current.locale)
            .environment(\.layoutDirection, AppLanguage.current.isRightToLeft ? .rightToLeft : .leftToRight)
            .appTypesetting(AppLanguage.current)
        }
    }
}
