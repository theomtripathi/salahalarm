//
//  LockTabView.swift
//  Ramadan Pro
//
//  SalahLock — locks the user's chosen apps when an enforced prayer's time
//  arrives, and unlocks them only after they confirm "I've prayed".
//

import SwiftUI
import Combine
import FamilyControls

struct LockTabView: View {
    @ObservedObject var prayerTimesViewModel: PrayerTimesViewModel
    @ObservedObject private var lockManager = AppLockManager.shared
    @ObservedObject private var prayerLogViewModel = PrayerLogViewModel.shared

    @State private var showAppPicker = false
    @State private var confirmingPrayer: PrayerName?
    @State private var isRequestingAuth = false

    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                statusCard
                if !lockManager.isAuthorized {
                    connectCard
                } else {
                    appsCard
                    prayersCard
                    settingsCard
                }
                howItWorksCard
            }
            .padding(20)
        }
        .background(AppColors.slCream.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            lockManager.refreshAuthorizationStatus()
            reevaluate()
        }
        .onReceive(timer) { _ in
            reevaluate()
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $lockManager.selection)
        .sheet(item: $confirmingPrayer) { prayer in
            SLPrayerConfirmationSheet(
                prayer: prayer,
                onConfirm: {
                    Task {
                        await prayerLogViewModel.confirmPrayer(prayer)
                        lockManager.refreshLog(prayerLogViewModel.todayLog)
                        confirmingPrayer = nil
                    }
                },
                onDismiss: { confirmingPrayer = nil }
            )
            .presentationDetents([.medium])
        }
    }

    private func reevaluate() {
        lockManager.update(
            schedule: prayerTimesViewModel.currentSchedule,
            log: prayerLogViewModel.todayLog
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.slGreen)
                Text("SalahLock")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
            }
            Spacer()
            statusPill
        }
    }

    private var statusPill: some View {
        let locked = lockManager.activeLockPrayer != nil
        return HStack(spacing: 6) {
            Circle()
                .fill(locked ? AppColors.saAlarmRed : AppColors.slGreen)
                .frame(width: 8, height: 8)
                Text(L10n.text(locked ? "locked" : (lockManager.lockEnabled && lockManager.isAuthorized && lockManager.hasSelection ? "armed" : "off")))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.slTextPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().stroke(AppColors.slBorderDefault, lineWidth: 1))
    }

    // MARK: - Status

    private var statusCard: some View {
        card {
            if let prayer = lockManager.activeLockPrayer {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.saAlarmRedLight)
                                .frame(width: 52, height: 52)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(AppColors.saAlarmRed)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.text("Your apps are locked"))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppColors.slTextPrimary)
                            Text(L10n.format("Pray %@ (%@) to unlock your apps", prayer.displayName, prayer.arabicName))
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.slTextSecondary)
                        }
                    }
                    SLPrimaryButton(title: L10n.format("I've prayed %@ 🤲", prayer.displayName)) {
                        confirmingPrayer = prayer
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.slGreen.opacity(0.12))
                                .frame(width: 52, height: 52)
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(AppColors.slGreen)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.text("Apps unlocked"))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppColors.slTextPrimary)
                            Text(nextLockText)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.slTextSecondary)
                        }
                    }
                }
            }
        }
    }

    private var nextLockText: String {
        guard lockManager.lockEnabled, lockManager.isAuthorized, lockManager.hasSelection else {
            return L10n.text("Finish setup below to activate the prayer lock")
        }
        guard let schedule = prayerTimesViewModel.currentSchedule else {
            return L10n.text("Waiting for your prayer times…")
        }
        let now = Date()
        let upcoming: [(PrayerName, Date)] = [
            (.fajr, schedule.fajr),
            (.dhuhr, schedule.dhuhr),
            (.asr, schedule.asr),
            (.maghrib, schedule.maghrib),
            (.isha, schedule.isha)
        ]
        .filter { lockManager.enforcedPrayers.contains($0.0) && $0.1 > now }

        if let next = upcoming.first {
            return L10n.format("Apps lock at %@, %@", L10n.text(next.0.displayName), next.1.timeString(format: "h:mm a"))
        }
        return L10n.text("No more locks today — see you at the next prayer")
    }

    // MARK: - Setup / cards

    private var connectCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.text("Connect Screen Time"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text(L10n.text("SalahAlarm uses Apple's Screen Time to temporarily block your chosen apps until you've prayed. Nothing is tracked and nothing leaves your phone."))
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.slTextSecondary)
                SLPrimaryButton(title: L10n.text(isRequestingAuth ? "Connecting…" : "Connect Screen Time"), isEnabled: !isRequestingAuth) {
                    isRequestingAuth = true
                    Task {
                        _ = await lockManager.requestAuthorization()
                        isRequestingAuth = false
                        reevaluate()
                    }
                }
            }
        }
    }

    private var appsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.text("Locked apps"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Spacer()
                    Image(systemName: "apps.iphone")
                        .foregroundColor(AppColors.slGreen)
                }
                Text(lockManager.hasSelection
                     ? lockManager.selectionSummary
                     : L10n.text("Choose the apps that distract you from salah"))
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.slTextSecondary)
                SLSecondaryButton(title: L10n.text(lockManager.hasSelection ? "Change apps" : "Choose apps")) {
                    showAppPicker = true
                }
            }
        }
    }

    private var prayersCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("Lock for these prayers"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text(L10n.text("Your apps lock when prayer time arrives and unlock when you confirm you've prayed."))
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.slTextSecondary)
                HStack(spacing: 8) {
                    ForEach(PrayerName.allCases) { prayer in
                        let selected = lockManager.enforcedPrayers.contains(prayer)
                        Button {
                            lockManager.toggleEnforced(prayer)
                            reevaluate()
                        } label: {
                            Text(L10n.text(prayer.displayName))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(selected ? .white : AppColors.slTextPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selected ? AppColors.slGreen : AppColors.slCream)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                if lockManager.enforcedPrayers.isEmpty {
                    Text(L10n.text("Select at least one prayer to activate the lock"))
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.saAlarmRed)
                }
            }
        }
    }

    private var settingsCard: some View {
        card {
            Toggle(isOn: Binding(
                get: { lockManager.lockEnabled },
                set: { lockManager.lockEnabled = $0; reevaluate() }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("Prayer lock"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text(L10n.text("Turn off to pause app locking"))
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.slTextSecondary)
                }
            }
            .tint(AppColors.slGreen)
        }
    }

    private var howItWorksCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("How it works"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                VStack(spacing: 0) {
                    SLTimelineRow(number: 1, title: L10n.text("Prayer time arrives"), isLast: false)
                    SLTimelineRow(number: 2, title: L10n.text("Your chosen apps get locked"), isLast: false)
                    SLTimelineRow(number: 3, title: L10n.text("You pray"), isLast: false)
                    SLTimelineRow(number: 4, title: L10n.text("Confirm that you've prayed to unlock"), isLast: true)
                }
                Text(L10n.text("Keep SalahAlarm on your phone — deleting the app removes the lock."))
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.slTextSecondary)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}
