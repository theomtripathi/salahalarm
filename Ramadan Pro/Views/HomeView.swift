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
                streakCard
                todaysPrayerProgressCard
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
                        Text("Assalamu Alaikum, \(displayName) 🌙")
                            .font(.system(size: 18, weight: .semibold))
                        Text(prayerTimesViewModel.currentLocation?.city ?? schedule?.city ?? "Your city")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.slTextSecondary)
                    }
                    Spacer()
                }

                if let next {
                    Text(next.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.slGreen)
                    Text(formatCountdown(next.time.timeIntervalSince(currentTime)))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColors.slGold)
                        .monospacedDigit()
                    Text("\(next.name) at \(next.time.timeString())")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                } else {
                    Text("Today's prayers are complete")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.slGreen)
                }

                if let schedule {
                    HStack(spacing: 10) {
                        ForEach(PrayerName.allCases, id: \.self) { prayer in
                            VStack(spacing: 6) {
                                Text(prayer.shortLabel)
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

    private var streakCard: some View {
        card {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 36))
                    Text("\(prayerLogViewModel.streakData.currentStreak)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(AppColors.slGold)
                    Text("day streak")
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
                    Text(prayerLogViewModel.todayLog.allFivePrayed ? "streak maintained! ✓" : "\(max(0, 5 - prayerLogViewModel.todayConfirmedCount)) prayers today to keep your streak")
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
                    Label("Next Alarm", systemImage: "bell.fill")
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
                        Text("Alarm access is locked")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppColors.saAlarmRed)
                        Text("Your subscription is inactive. Renew to keep prayer alarms running.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.slTextSecondary)
                        SLPrimaryButton(title: "unlock alarms") {
                            alarmViewModel.showSubscriptionPaywall = true
                        }
                    }
                } else if let nextAlarm {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(nextAlarm.prayer.displayName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AppColors.slGreen)
                            Text(nextAlarm.scheduledTime.timeString())
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(AppColors.slGold)
                            Text("\(nextAlarm.prayer.displayName) · \(relativeAlarmCountdown(to: nextAlarm.scheduledTime))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.slTextSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.slTextSecondary.opacity(0.7))
                    }

                    Text(alarmModeDescription)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(alarmModeColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(alarmModeColor.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text("No more alarms scheduled today.")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text("Tomorrow's prayer alarms will refresh automatically.")
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
                    Text("Today's Prayers")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    Text("\(prayerLogViewModel.todayConfirmedCount) / 5 prayed")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.slGold)
                }

                ForEach(PrayerName.allCases, id: \.self) { prayer in
                    HStack(spacing: 12) {
                        Text(prayer.emoji)
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prayer.displayName)
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
            Button("missed") {
                selectedPrayer = prayer
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.red)
        } else {
            Button("confirm 🤲") {
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
                Text("Add SalahAlarm to your Home Screen")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button {
                    hideWidgetPromo = true
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(AppColors.slTextSecondary)
                }
            }
            Text("See your streak and next prayer time without opening the app.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.slTextSecondary)
            Button("Add Widget →") { }
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
            return "in \(hours)h \(minutes)m"
        }
        return "in \(minutes)m"
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
