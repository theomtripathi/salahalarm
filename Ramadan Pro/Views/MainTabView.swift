//
//  MainTabView.swift
//  Ramadan Pro
//

import SwiftUI
import UIKit
import Combine
import RevenueCat

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    @StateObject private var prayerTimesViewModel = PrayerTimesViewModel()
    @StateObject private var alarmViewModel = AlarmViewModel.shared
    @ObservedObject private var prayerLogViewModel = PrayerLogViewModel.shared
    @Environment(\.scenePhase) private var scenePhase
    private let keepAlive = BackgroundAudioKeepAlive.shared
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack(path: $navigationCoordinator.homeNavigationPath) {
                HomeView(prayerTimesViewModel: prayerTimesViewModel)
                    .navigationDestination(for: AppEnums.NavigationRoute.self) { route in
                        destinationView(for: route)
                    }
            }
            .tabItem {
                Label(L10n.text("Home"), systemImage: "house.fill")
            }
            .tag(AppEnums.TabItem.home.rawValue)

            NavigationStack(path: $navigationCoordinator.prayersNavigationPath) {
                PrayerHistoryView(prayerTimesViewModel: prayerTimesViewModel)
                    .navigationDestination(for: AppEnums.NavigationRoute.self) { route in
                        destinationView(for: route)
                    }
            }
            .tabItem {
                Label(L10n.text("Prayers"), systemImage: "sun.max.fill")
            }
            .badge(unconfirmedPrayerCount)
            .tag(AppEnums.TabItem.prayers.rawValue)

            NavigationStack(path: $navigationCoordinator.lockNavigationPath) {
                LockTabView(prayerTimesViewModel: prayerTimesViewModel)
                    .navigationDestination(for: AppEnums.NavigationRoute.self) { route in
                        destinationView(for: route)
                    }
            }
            .tabItem {
                Label(L10n.text("Lock"), systemImage: "lock.fill")
            }
            .tag(AppEnums.TabItem.lock.rawValue)

            NavigationStack(path: $navigationCoordinator.quranNavigationPath) {
                QuranTabView()
                    .navigationDestination(for: AppEnums.NavigationRoute.self) { route in
                        destinationView(for: route)
                    }
            }
            .tabItem {
                Label(L10n.text("Quran"), systemImage: "book.fill")
            }
            .tag(AppEnums.TabItem.quran.rawValue)

            NavigationStack(path: $navigationCoordinator.profileNavigationPath) {
                ProfileView()
            }
            .tabItem {
                Label(L10n.text("Profile"), systemImage: "person.fill")
            }
            .tag(AppEnums.TabItem.profile.rawValue)
        }
        .environmentObject(navigationCoordinator)
        .tint(AppColors.slGreen)
        .task {
            // Existing users skip onboarding, so offer the ATT prompt here too
            await AppsFlyerService.shared.requestTrackingAuthorizationIfNeeded()
            await prayerTimesViewModel.loadPrayerTimes()
            await prayerLogViewModel.load()
            alarmViewModel.syncSchedule(prayerTimesViewModel.activeSchedule)
            // Feed schedules to keep-alive and BGTask manager
            keepAlive.updateSchedules(
                today: prayerTimesViewModel.currentSchedule,
                tomorrow: prayerTimesViewModel.tomorrowSchedule
            )
            AppLockManager.shared.update(
                schedule: prayerTimesViewModel.currentSchedule,
                log: prayerLogViewModel.todayLog
            )
        }
        .task(id: scenePhase) {
            // Establish the first eligible-use time without ever prompting on
            // an unentitled launch. A first-use invocation only saves a baseline;
            // later foreground transitions can pass the 24-hour gate.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled, scenePhase == .active,
                  let scene = activeWindowScene() else { return }
            let revenueCatUserID = Purchases.shared.appUserID
            guard let customerInfo = try? await Purchases.shared.customerInfo() else { return }
            guard !Task.isCancelled, scenePhase == .active,
                  Purchases.shared.appUserID == revenueCatUserID else { return }
            let hasActiveEntitlement = customerInfo.entitlements.active.values.contains {
                $0.expirationDate.map { $0 > Date() } ?? true
            }
            RatingPromptManager.shared.recordFirstEligibleUseIfNeeded(
                hasActiveEntitlement: hasActiveEntitlement
            )
            guard ratingPromptContextIsAvailable(in: scene) else { return }
            RatingPromptManager.shared.considerForegroundReturn(
                hasActiveEntitlement: hasActiveEntitlement,
                scene: scene,
                isModalPresented: false
            )
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.slTabUnselected)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(AppColors.slTabUnselected)
            ]
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.slGreen)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(AppColors.slGreen)
            ]
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
        .onReceive(timer) { now in
            alarmViewModel.syncSchedule(prayerTimesViewModel.activeSchedule, now: now)
            // Keep schedules fresh for background keep-alive
            keepAlive.updateSchedules(
                today: prayerTimesViewModel.currentSchedule,
                tomorrow: prayerTimesViewModel.tomorrowSchedule
            )
            AppLockManager.shared.update(
                schedule: prayerTimesViewModel.currentSchedule,
                log: prayerLogViewModel.todayLog,
                now: now
            )
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                if alarmViewModel.hasAlarmAccess && alarmViewModel.settings.alarmsEnabled {
                    keepAlive.startSilentLoop()
                }
            case .active:
                keepAlive.stopSilentLoop()
                AppLockManager.shared.refreshAuthorizationStatus()
                AppLockManager.shared.update(
                    schedule: prayerTimesViewModel.currentSchedule,
                    log: prayerLogViewModel.todayLog
                )
            default:
                break
            }
        }
        .fullScreenCover(item: $alarmViewModel.activeAlarm) { alarm in
            SAActiveAlarmOverlay(alarmViewModel: alarmViewModel, alarm: alarm)
        }
        .fullScreenCover(isPresented: $alarmViewModel.showSubscriptionPaywall) {
            SLPaywallScreen(vm: OnboardingFlowViewModel(), onExit: {
                alarmViewModel.showSubscriptionPaywall = false
            })
        }
    }

    private func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    private func hasPresentedModal(in scene: UIWindowScene) -> Bool {
        guard let window = scene.windows.first(where: \.isKeyWindow),
              let root = window.rootViewController else { return true }
        return hasPresentedModal(from: root)
    }

    private func hasPresentedModal(from controller: UIViewController) -> Bool {
        if controller.presentedViewController != nil { return true }
        if let navigationController = controller as? UINavigationController,
           let visible = navigationController.visibleViewController,
           hasPresentedModal(from: visible) {
            return true
        }
        if let tabController = controller as? UITabBarController,
           let selected = tabController.selectedViewController,
           hasPresentedModal(from: selected) {
            return true
        }
        return controller.children.contains { hasPresentedModal(from: $0) }
    }

    private func ratingPromptContextIsAvailable(in scene: UIWindowScene) -> Bool {
        scenePhase == .active
            && scene.activationState == .foregroundActive
            && appState.selectedTab != AppEnums.TabItem.profile.rawValue
            && !alarmViewModel.showSubscriptionPaywall
            && alarmViewModel.activeAlarm == nil
            && !alarmViewModel.showSettingsSheet
            && !alarmViewModel.showSoundSetupSheet
            && !hasPresentedModal(in: scene)
    }

    @ViewBuilder
    private func destinationView(for route: AppEnums.NavigationRoute) -> some View {
        switch route {
        case .quranReading(let surah, let juz, let page):
            QuranReadingView(surah: surah, juz: juz, page: page)
        case .prayerDetail(let prayerType):
            Text(prayerType)
        case .qibla:
            QiblaCompassView()
        }
    }

    private var unconfirmedPrayerCount: Int {
        guard let schedule = prayerTimesViewModel.currentSchedule else { return 0 }
        let now = Date()
        return PrayerName.allCases.filter { prayer in
            let prayerDate: Date
            switch prayer {
            case .fajr: prayerDate = schedule.fajr
            case .dhuhr: prayerDate = schedule.dhuhr
            case .asr: prayerDate = schedule.asr
            case .maghrib: prayerDate = schedule.maghrib
            case .isha: prayerDate = schedule.isha
            }
            guard prayerDate <= now else { return false }
            return !prayerLogViewModel.todayLog.isConfirmed(prayer)
        }.count
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState.shared)
}
