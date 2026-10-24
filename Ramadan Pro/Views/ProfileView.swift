//
//  ProfileView.swift
//  Ramadan Pro
//

import SwiftUI
import StoreKit

struct ProfileView: View {
    @ObservedObject private var authService = FirebaseAuthService.shared
    @ObservedObject private var prayerLogViewModel = PrayerLogViewModel.shared
    @ObservedObject private var alarmViewModel = AlarmViewModel.shared
    @StateObject private var subscriptionViewModel = SubscriptionViewModel()
    @State private var showDeleteAccount = false
    @State private var showLogoutConfirmation = false
    @State private var showInfoAlert = false
    @State private var infoAlertTitle = ""
    @State private var infoAlertMessage = ""
    @AppStorage("sl_notification_offset") private var notificationOffset = 0
    @AppStorage("sl_fajr_reminder_enabled") private var fajrReminderEnabled = true
    @AppStorage("sl_jummah_reminder_enabled") private var jummahReminderEnabled = true
    @AppStorage("sl_quran_font_size") private var quranFontSize = 18.0
    @AppStorage("sl_translation_language") private var translationLanguage = "English"
    @AppStorage("sl_arabic_font_style") private var arabicFontStyle = "Uthmani"
    @AppStorage("sl_prayer_method") private var prayerMethod = "MWL"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statsRow
                section("Prayer Settings") {
                    HStack {
                        Text(L10n.text("App language"))
                        Spacer()
                        LanguagePickerButton()
                    }
                    settingRow(title: "Prayer calculation method", value: prayerMethod)
                    segmentedPicker(["Hanafi", "ISNA", "MWL"], selection: $prayerMethod)
                    settingRow(title: "Notification timing", value: notificationOffsetLabel)
                    segmentedPicker(["On time", "5 min before", "10 min before"], selection: Binding(
                        get: { notificationOffsetLabel },
                        set: { notificationOffset = $0 == "On time" ? 0 : ($0 == "5 min before" ? 5 : 10) }
                    ))
                    Toggle("Fajr reminder", isOn: $fajrReminderEnabled)
                    Toggle("Jumu'ah reminder", isOn: $jummahReminderEnabled)
                }
                section("Alarm Settings") {
                    if !alarmViewModel.hasAlarmAccess {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prayer alarms are premium")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.saAlarmRed)
                            Text("Alarms are available with an active paid plan.")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.slTextSecondary)
                            Button("Unlock alarms") {
                                alarmViewModel.showSubscriptionPaywall = true
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.slGreen)
                        }
                    }
                    Toggle("Prayer alarms", isOn: Binding(
                        get: { alarmViewModel.settings.alarmsEnabled },
                        set: { alarmViewModel.setAlarmsEnabled($0) }
                    ))
                    .disabled(!alarmViewModel.hasAlarmAccess)
                    settingRow(title: "Alarm mode", value: alarmViewModel.settings.strictness.displayLabel)
                    Picker("", selection: Binding(
                        get: { alarmViewModel.settings.strictness },
                        set: { alarmViewModel.setStrictness($0) }
                    )) {
                        ForEach(AlarmStrictness.allCases, id: \.self) { strictness in
                            Text(strictness.displayLabel).tag(strictness)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!alarmViewModel.hasAlarmAccess)
                    settingRow(title: "Alarm sound", value: alarmViewModel.settings.soundName)
                    Picker("", selection: Binding(
                        get: { alarmViewModel.settings.soundName },
                        set: { alarmViewModel.setSound($0) }
                    )) {
                        ForEach(AlarmSoundOption.allCases, id: \.rawValue) { sound in
                            Text(sound.shortLabel).tag(sound.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!alarmViewModel.hasAlarmAccess)
                    actionRow("Open Alarm Dashboard") {
                        if alarmViewModel.hasAlarmAccess {
                            alarmViewModel.showSettingsSheet = true
                        } else {
                            alarmViewModel.showSubscriptionPaywall = true
                        }
                    }
                }
                section("Quran Settings") {
                    VStack(alignment: .leading, spacing: 10) {
                        settingRow(title: "Font size", value: "\(Int(quranFontSize))")
                        Slider(value: $quranFontSize, in: 14...28, step: 1)
                        settingRow(title: "Translation language", value: translationLanguage)
                        segmentedPicker(["English", "Urdu", "Arabic"], selection: $translationLanguage)
                        settingRow(title: "Arabic font style", value: arabicFontStyle)
                        segmentedPicker(["Uthmani", "Naskh", "IndoPak"], selection: $arabicFontStyle)
                    }
                }
                section("Account") {
                    actionRow("Manage Subscription") {
                        openManageSubscription()
                    }
                    actionRow("Restore Purchases") {
                        Task {
                            let restored = await subscriptionViewModel.restorePurchases()
                            presentInfoAlert(
                                title: restored ? "Purchases Restored" : "Restore Failed",
                                message: restored ? "Your purchases have been restored." : (subscriptionViewModel.errorMessage ?? "Unable to restore purchases right now.")
                            )
                        }
                    }
                    if authService.currentUser?.email != nil {
                        actionRow("Change Password") {
                            sendPasswordReset()
                        }
                    }
                    actionRow("Sign Out", role: .destructive) {
                        showLogoutConfirmation = true
                    }
                    actionRow("Delete Account", role: .destructive) {
                        showDeleteAccount = true
                    }
                }
                section("About") {
                    settingRow(title: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    actionRow("Privacy Policy") {
                        openExternalURL("https://ramadan-pro.lovable.app/privacy")
                    }
                    actionRow("Terms of Use") {
                        openExternalURL("https://ramadan-pro.lovable.app/terms")
                    }
                    actionRow("Leave a Review") {
                        // User-initiated reviews are open to everyone, with no
                        // satisfaction filter or requested star rating.
                        openExternalURL("https://apps.apple.com/app/id6758457826?action=write-review")
                    }
                    actionRow("Send Feedback") {
                        // This is the support form listed in App Store Connect.
                        // Never prefill account details or send feedback automatically.
                        openExternalURL("https://ramadan-pro.lovable.app/support")
                    }
                    Text("Your reviews help us reach more Muslims and improve the app.")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.slTextSecondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    actionRow("Share SalahAlarm") {
                        let activity = UIActivityViewController(activityItems: ["SalahAlarm"], applicationActivities: nil)
                        UIApplication.shared.topMostViewController?.present(activity, animated: true)
                    }
                }
            }
            .padding(20)
        }
        .background(AppColors.slCream.ignoresSafeArea())
        .task {
            await prayerLogViewModel.load()
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountView(onDeleteComplete: {})
        }
        .sheet(isPresented: $alarmViewModel.showSettingsSheet) {
            SAAlarmSettingsSheet(alarmViewModel: alarmViewModel)
        }
        .alert("Sign Out", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task { try? await LogoutService.clearAllAndSignOut() }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert(infoAlertTitle, isPresented: $showInfoAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoAlertMessage)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(AppColors.slGreen)
                .frame(width: 72, height: 72)
                .overlay(
                    Text(initials)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(authService.currentUser?.name ?? "SalahAlarm User")
                    .font(.system(size: 20, weight: .bold))
                Text(authService.currentUser?.email ?? "")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.slTextSecondary)
                Text("Member since \(memberSince)")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.slTextSecondary)
            }
            Spacer()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard("🔥", "\(prayerLogViewModel.streakData.currentStreak)", "Current streak")
            statCard("🕌", "\(prayerLogViewModel.streakData.totalPrayersConfirmed)", "Total prayers")
            statCard("📅", "\(prayerLogViewModel.streakData.totalPrayerDays)", "Full days")
        }
    }

    private func statCard(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 8) {
            Text(emoji)
            Text(value)
                .font(.system(size: 20, weight: .bold))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.slTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.slTextSecondary)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
    }

    private func settingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(AppColors.slTextSecondary)
        }
    }

    private func actionRow(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 15, weight: .medium))
        }
        .foregroundColor(role == .destructive ? .red : AppColors.slTextPrimary)
    }

    private func segmentedPicker(_ values: [String], selection: Binding<String>) -> some View {
        Picker("", selection: selection) {
            ForEach(values, id: \.self) { value in
                Text(value).tag(value)
            }
        }
        .pickerStyle(.segmented)
    }

    private var initials: String {
        let parts = (authService.currentUser?.name ?? "SalahAlarm User").split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined().uppercased()
    }

    private var memberSince: String {
        authService.currentUser?.createdAt.formattedDate("MMM yyyy") ?? Date().formattedDate("MMM yyyy")
    }

    private var notificationOffsetLabel: String {
        switch notificationOffset {
        case 10: return "10 min before"
        case 5: return "5 min before"
        default: return "On time"
        }
    }

    private func openManageSubscription() {
        openExternalURL("https://apps.apple.com/account/subscriptions")
    }

    private func sendPasswordReset() {
        guard let email = authService.currentUser?.email, !email.isEmpty else {
            presentInfoAlert(title: "No Email Found", message: "This account does not have an email address available for password reset.")
            return
        }

        Task {
            do {
                try await FirebaseAuthService.shared.resetPassword(email: email)
                presentInfoAlert(title: "Password Reset Sent", message: "A reset link was sent to \(email).")
            } catch {
                presentInfoAlert(title: "Reset Failed", message: error.localizedDescription)
            }
        }
    }

    private func openExternalURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            presentInfoAlert(title: "Unavailable", message: "That link is not available right now.")
            return
        }

        guard UIApplication.shared.canOpenURL(url) else {
            presentInfoAlert(title: "Unavailable", message: "That link cannot be opened on this device.")
            return
        }

        UIApplication.shared.open(url)
    }

    private func presentInfoAlert(title: String, message: String) {
        infoAlertTitle = title
        infoAlertMessage = message
        showInfoAlert = true
    }
}

private extension UIApplication {
    var topMostViewController: UIViewController? {
        guard let scene = connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return nil }
        var current = root
        while let presented = current.presentedViewController {
            current = presented
        }
        return current
    }
}

#Preview {
    ProfileView()
}
