//
//  HomeView.swift
//  Ramadan Pro
//

import SwiftUI
import Combine

struct HomeView: View {
    @ObservedObject private var authService = FirebaseAuthService.shared
    @ObservedObject private var prayerLogViewModel = PrayerLogViewModel.shared
    @ObservedObject private var alarmViewModel = AlarmViewModel.shared
    @ObservedObject private var revenueCatService = RevenueCatService.shared
    @ObservedObject private var lockManager = AppLockManager.shared
    @EnvironmentObject var appState: AppState
    @StateObject private var internalPrayerTimesViewModel = PrayerTimesViewModel()
    @State private var currentTime = Date()
    @State private var selectedPrayer: PrayerName?
    @AppStorage("sl_hide_widget_promo") private var hideWidgetPromo = false

    let externalPrayerTimesViewModel: PrayerTimesViewModel?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(prayerTimesViewModel: PrayerTimesViewModel? = nil) {
        self.externalPrayerTimesViewModel = prayerTimesViewModel
    }

    private var prayerTimesViewModel: PrayerTimesViewModel {
        externalPrayerTimesViewModel ?? internalPrayerTimesViewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if alarmViewModel.shouldShowSilentWarning {
                    SAAlarmSilentWarningBanner(alarmViewModel: alarmViewModel)
                }
                nextPrayerCard
                nextAlarmCard
                if isEligibleTrialJourney {
                    trialJourneyCard
                }
                lockStatusStrip
                duaCard
                streakCard
                todaysPrayerProgressCard
                qiblaShortcutCard
                if !hideWidgetPromo {
                    widgetPromoCard
                }
            }
            .padding(20)
        }
        .background(AppColors.slCream.ignoresSafeArea())
        .task {
            await prayerTimesViewModel.loadPrayerTimes()
            await prayerLogViewModel.load()
            recordTrialJourneyVisibility()
        }
        .onChange(of: trialStatusFingerprint) { _ in
            recordTrialJourneyVisibility()
        }
        .onReceive(timer) { _ in
            currentTime = Date()
            alarmViewModel.syncSchedule(prayerTimesViewModel.activeSchedule, now: currentTime)
        }
        .sheet(item: $selectedPrayer) { prayer in
            SLPrayerConfirmationSheet(
                prayer: prayer,
                onConfirm: {
                    Task {
                        await prayerLogViewModel.confirmPrayer(prayer)
                        selectedPrayer = nil
                    }
                },
                onDismiss: {
                    selectedPrayer = nil
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $alarmViewModel.showSettingsSheet) {
            SAAlarmSettingsSheet(alarmViewModel: alarmViewModel)
        }
        .sheet(isPresented: $alarmViewModel.showSoundSetupSheet) {
            SAAlarmSoundSetupSheet()
                .presentationDetents([.medium])
        }
    }

    private var isEligibleTrialJourney: Bool {
        let status = revenueCatService.subscriptionStatus
        return status.isActive && status.isInTrial && !status.isExpired
    }

    private var trialStatusFingerprint: String {
        let status = revenueCatService.subscriptionStatus
        return "\(status.isActive)|\(status.isInTrial)|\(status.startDate?.timeIntervalSince1970 ?? 0)|\((status.trialEndDate ?? status.expiryDate)?.timeIntervalSince1970 ?? 0)"
    }

    private func recordTrialJourneyVisibility() {
        guard isEligibleTrialJourney else { return }
        let status = revenueCatService.subscriptionStatus
        TrialJourneyTracker.shared.recordView(status: status)
    }

    private var trialJourneyCard: some View {
        let status = revenueCatService.subscriptionStatus
        let configured = alarmViewModel.settings.alarmsEnabled
            && PrayerName.allCases.contains(where: { alarmViewModel.settings.isEnabled(for: $0) })
        let trialPrayerLogged = prayerLogViewModel.weeklyLogs.values.contains { log in
            log.confirmedAt.contains { date in
                guard let start = status.startDate,
                      let end = status.trialEndDate ?? status.expiryDate else { return false }
                return date >= start && date <= end
            }
        } || prayerLogViewModel.todayLog.confirmedAt.contains { date in
            guard let start = status.startDate,
                  let end = status.trialEndDate ?? status.expiryDate else { return false }
            return date >= start && date <= end
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(AppColors.slGreen)
                    .accessibilityHidden(true)
                Text(L10n.text("Your trial, one steady step at a time"))
                    .font(.headline)
                    .foregroundStyle(AppColors.slTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
                Text(trialDateSummary(for: status))
                .font(.subheadline)
                .foregroundStyle(AppColors.slTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                alarmViewModel.showSettingsSheet = true
            } label: {
                trialChecklistRow(L10n.text("Set up a prayer alarm"), isComplete: configured, action: L10n.text("Open alarm settings"))
            }
            .buttonStyle(.plain)

            Button {
                appState.selectedTab = AppEnums.TabItem.prayers.rawValue
            } label: {
                trialChecklistRow(L10n.text("Log a prayer during your trial"), isComplete: trialPrayerLogged, action: L10n.text("Open prayers"))
            }
            .buttonStyle(.plain)

            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                Text(L10n.text("Manage subscription"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.slGreen)
                    .underline()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityHint(L10n.text("Opens Apple subscription settings"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.slGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.slGreen.opacity(0.18), lineWidth: 1))
    }

    private func trialChecklistRow(_ title: String, isComplete: Bool, action: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? AppColors.slGreen : AppColors.slTextSecondary)
                .accessibilityHidden(true)
            Text(L10n.text(title))
                .font(.subheadline)
                .foregroundStyle(AppColors.slTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.slTextSecondary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text(title))
        .accessibilityValue(L10n.text(isComplete ? "Complete" : "Not complete"))
        .accessibilityHint(action)
    }

    private func trialDateSummary(for status: SubscriptionStatus) -> String {
        let end = status.trialEndDate ?? status.expiryDate
        if let start = status.startDate, let end {
            return L10n.format("Trial: %@ – %@", Self.trialDateFormatter.string(from: start), Self.trialDateFormatter.string(from: end))
        }
        if let end {
            return L10n.format("Your free trial ends %@.", Self.trialDateFormatter.string(from: end))
        }
        return L10n.text("Your free trial is active.")
    }

    private static let trialDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image("logo")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Text("SalahAlarm")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
            }

            Spacer()

            SLStreakBadge(streak: prayerLogViewModel.streakData.currentStreak, isActive: prayerLogViewModel.todayConfirmedCount > 0)

            Button {
                appState.selectedTab = AppEnums.TabItem.profile.rawValue
            } label: {
                Circle()
                    .fill(AppColors.slGreen.opacity(0.16))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.slGreen)
                    )
            }
        }
    }

    private var nextPrayerCard: some View {
        let schedule = prayerTimesViewModel.currentSchedule
        let next = schedule?.nextPrayer
        return card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.format("Assalamu Alaikum, %@ 🌙", displayName))
                            .font(.system(size: 18, weight: .semibold))
                        Text(prayerTimesViewModel.currentLocation?.city ?? schedule?.city ?? L10n.text("Your city"))
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.slTextSecondary)
                    }
                    Spacer()
                }

                if let next {
                    Text(L10n.text(next.name))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.slGreen)
                    Text(formatCountdown(next.time.timeIntervalSince(currentTime)))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColors.slGold)
                        .monospacedDigit()
                    Text(L10n.format("%@ at %@", L10n.text(next.name), next.time.timeString()))
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                } else {
                    Text(L10n.text("Today's prayers are complete"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.slGreen)
                }

                if let schedule {
                    HStack(spacing: 10) {
                        ForEach(PrayerName.allCases, id: \.self) { prayer in
                            VStack(spacing: 6) {
                                Text(L10n.text(prayer.shortLabel))
                                    .font(.system(size: 11, weight: .semibold))
                                Text(schedule.time(for: prayer)?.timeString() ?? "--")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.slTextSecondary)
                                Circle()
                                    .fill(statusColor(for: prayer, schedule: schedule))
                                    .frame(width: 8, height: 8)
                            }
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                selectedPrayer = prayer
                            }
                        }
                    }
                }
            }
        }
    }

    /// Compact strip showing the SalahLock state; tapping opens the Lock tab.
    @ViewBuilder
    private var lockStatusStrip: some View {
        if lockManager.lockEnabled && lockManager.isAuthorized && lockManager.hasSelection {
            Button {
                appState.selectedTab = AppEnums.TabItem.lock.rawValue
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: lockManager.activeLockPrayer != nil ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(lockManager.activeLockPrayer != nil ? AppColors.saAlarmRed : AppColors.slGreen)
                    Text(lockManager.activeLockPrayer.map { L10n.format("apps locked — pray %@ to unlock", L10n.text($0.displayName)) } ?? L10n.text("SalahLock armed · apps unlocked"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.slTextSecondary.opacity(0.7))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    /// Rotating dua card — same 30-minute rotation as the Dua widget.
    private var duaCard: some View {
        let dua = DuaLibrary.dua(for: currentTime)
        let theme = DuaLibrary.theme(for: currentTime)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "hands.and.sparkles.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: theme.accentHex))
                    Text(L10n.text("DUA OF THE MOMENT"))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundColor(.white.opacity(0.75))
                Spacer()
            }
            Text("“\(dua.english)”")
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(dua.arabic)
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(Color(hex: theme.accentHex))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .fixedSize(horizontal: false, vertical: true)
            Text(dua.reference)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: theme.topHex), Color(hex: theme.bottomHex)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    private var qiblaShortcutCard: some View {
        NavigationLink(value: AppEnums.NavigationRoute.qibla) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.slGreen.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppColors.slGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("Qibla Compass"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text(L10n.text("Find the direction of the Kaaba"))
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.slTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.slTextSecondary.opacity(0.7))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var streakCard: some View {
        card {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 36))
                    Text("\(prayerLogViewModel.streakData.currentStreak)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(AppColors.slGold)
                    Text(L10n.text("day streak"))
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 12) {
                    HStack(spacing: 10) {
                        ForEach(lastSevenDays(), id: \.self) { day in
                            let log = prayerLogViewModel.log(for: day)
                            let isToday = Calendar.current.isDateInToday(day)
                            Circle()
                                .fill(log.allFivePrayed ? AppColors.slGreen : (isToday ? Color.clear : AppColors.slBorderDefault))
                                .overlay(
                                    Circle()
                                        .stroke(isToday ? AppColors.slGold : AppColors.slBorderDefault, lineWidth: isToday ? 2 : 1)
                                )
                                .overlay {
                                    if log.allFivePrayed {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 20, height: 20)
                        }
                    }
                    Text(prayerLogViewModel.todayLog.allFivePrayed ? L10n.text("Streak maintained! ✓") : L10n.format("%d prayers today to keep your streak", max(0, 5 - prayerLogViewModel.todayConfirmedCount)))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.slTextSecondary)
                }
            }
        }
    }

    private var nextAlarmCard: some View {
        let nextAlarm = alarmViewModel.nextScheduledAlarm

        return card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    Label(L10n.text("Next Alarm"), systemImage: "bell.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                        .labelStyle(.titleAndIcon)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { alarmViewModel.settings.alarmsEnabled },
                        set: { alarmViewModel.setAlarmsEnabled($0) }
                    ))
                        .labelsHidden()
                        .tint(AppColors.slGreen)
                        .disabled(!alarmViewModel.hasAlarmAccess)
                }

                if !alarmViewModel.hasAlarmAccess {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text("Alarm access is locked"))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppColors.saAlarmRed)
                        Text(L10n.text("Your subscription is inactive. Renew to keep prayer alarms running."))
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.slTextSecondary)
                        SLPrimaryButton(title: L10n.text("Unlock alarms")) {
                            alarmViewModel.showSubscriptionPaywall = true
                        }
                    }
                } else if let nextAlarm {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.text(nextAlarm.prayer.displayName))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AppColors.slGreen)
                            Text(nextAlarm.scheduledTime.timeString())
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(AppColors.slGold)
                            Text(L10n.format("%@ · %@", L10n.text(nextAlarm.prayer.displayName), relativeAlarmCountdown(to: nextAlarm.scheduledTime)))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.slTextSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.slTextSecondary.opacity(0.7))
                    }

                    Text(L10n.text(alarmModeDescription))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(alarmModeColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(alarmModeColor.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text(L10n.text("No more alarms scheduled today."))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text(L10n.text("Tomorrow's prayer alarms will refresh automatically."))
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                alarmViewModel.showSettingsSheet = true
            }
        }
    }

    private var todaysPrayerProgressCard: some View {
        let schedule = prayerTimesViewModel.currentSchedule
        return card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(L10n.text("Today's Prayers"))
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    Text(L10n.format("%d / 5 prayed", prayerLogViewModel.todayConfirmedCount))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.slGold)
                }

                ForEach(PrayerName.allCases, id: \.self) { prayer in
                    HStack(spacing: 12) {
                        Text(prayer.emoji)
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.text(prayer.displayName))
                                .font(.system(size: 16, weight: .semibold))
                            Text(schedule?.time(for: prayer)?.timeString() ?? "--")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.slTextSecondary)
                        }
                        Spacer()
                        prayerAction(for: prayer, schedule: schedule)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func prayerAction(for prayer: PrayerName, schedule: DailyPrayerSchedule?) -> some View {
        let confirmed = prayerLogViewModel.todayLog.isConfirmed(prayer)
        let isPast = (schedule?.time(for: prayer) ?? .distantFuture) <= currentTime
        if confirmed {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.slGreen)
        } else if isPast {
            Button(L10n.text("Missed")) {
                selectedPrayer = prayer
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.red)
        } else {
            Button(L10n.text("Confirm 🤲")) {
                selectedPrayer = prayer
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(AppColors.slGold)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppColors.slGold.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private var widgetPromoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.text("Add SalahAlarm to your Home Screen"))
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button {
                    hideWidgetPromo = true
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(AppColors.slTextSecondary)
                }
            }
            Text(L10n.text("See your streak and next prayer time without opening the app."))
                .font(.system(size: 14))
                .foregroundColor(AppColors.slTextSecondary)
            Button(L10n.text("Add Widget →")) { }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.slGold)
        }
        .padding(16)
        .background(AppColors.slCream)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.slGold.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private func statusColor(for prayer: PrayerName, schedule: DailyPrayerSchedule) -> Color {
        if prayerLogViewModel.todayLog.isConfirmed(prayer) {
            return AppColors.slGreen
        }
        let prayerTime = schedule.time(for: prayer) ?? .distantFuture
        return prayerTime <= currentTime ? .red : AppColors.slBorderDefault
    }

    private func lastSevenDays() -> [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: -6 + $0, to: Date()) }
    }

    private func formatCountdown(_ interval: TimeInterval) -> String {
        let safe = max(0, interval)
        let hours = Int(safe) / 3600
        let minutes = (Int(safe) / 60) % 60
        let seconds = Int(safe) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func relativeAlarmCountdown(to date: Date) -> String {
        let interval = max(0, date.timeIntervalSince(currentTime))
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) / 60) % 60

        if hours > 0 {
            return L10n.format("in %dh %dm", hours, minutes)
        }
        return L10n.format("in %dm", minutes)
    }

    private var displayName: String {
        let name = authService.currentUser?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name?.isEmpty == false ? name! : "Friend")
    }

    private var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined().uppercased()
    }

    private var alarmModeDescription: String {
        switch alarmViewModel.settings.strictness {
        case .moderate:
            return "Moderate mode - auto-marks missed after 10 minutes"
        case .relaxed:
            return "Relaxed mode - one snooze before scan is required"
        default:
            return "Strict mode - scan your prayer mat to dismiss"
        }
    }

    private var alarmModeColor: Color {
        switch alarmViewModel.settings.strictness {
        case .moderate:
            return AppColors.slGold
        case .relaxed:
            return AppColors.slTextSecondary
        default:
            return AppColors.slGreen
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppState.shared)
    }
}

private extension DailyPrayerSchedule {
    func time(for prayer: PrayerName) -> Date? {
        switch prayer {
        case .fajr: return fajr
        case .dhuhr: return dhuhr
        case .asr: return asr
        case .maghrib: return maghrib
        case .isha: return isha
        }
    }
}
