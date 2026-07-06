//
//  MainTabView.swift
//  Ramadan Pro
//

import SwiftUI
import UIKit
import Combine

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
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppEnums.TabItem.home.rawValue)

            NavigationStack(path: $navigationCoordinator.prayersNavigationPath) {
                PrayerHistoryView(prayerTimesViewModel: prayerTimesViewModel)
                    .navigationDestination(for: AppEnums.NavigationRoute.self) { route in
                        destinationView(for: route)
                    }
            }
            .tabItem {
                Label("Prayers", systemImage: "sun.max.fill")
            }
            .badge(unconfirmedPrayerCount)
            .tag(AppEnums.TabItem.prayers.rawValue)

            NavigationStack(path: $navigationCoordinator.quranNavigationPath) {
                QuranTabView()
                    .navigationDestination(for: AppEnums.NavigationRoute.self) { route in
                        destinationView(for: route)
                    }
            }
            .tabItem {
                Label("Quran", systemImage: "book.fill")
            }
            .tag(AppEnums.TabItem.quran.rawValue)

            NavigationStack(path: $navigationCoordinator.qiblaNavigationPath) {
                QiblaCompassView()
                    .navigationDestination(for: AppEnums.NavigationRoute.self) { route in
                        destinationView(for: route)
                    }
            }
            .tabItem {
                Label("Qibla", systemImage: "location.north.fill")
            }
            .tag(AppEnums.TabItem.qibla.rawValue)

            NavigationStack(path: $navigationCoordinator.profileNavigationPath) {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(AppEnums.TabItem.profile.rawValue)
        }
        .environmentObject(navigationCoordinator)
        .tint(AppColors.slGreen)
        .task {
            await prayerTimesViewModel.loadPrayerTimes()
            await prayerLogViewModel.load()
            alarmViewModel.syncSchedule(prayerTimesViewModel.activeSchedule)
            // Feed schedules to keep-alive and BGTask manager
            keepAlive.updateSchedules(
                today: prayerTimesViewModel.currentSchedule,
                tomorrow: prayerTimesViewModel.tomorrowSchedule
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
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                if alarmViewModel.hasAlarmAccess && alarmViewModel.settings.alarmsEnabled {
                    keepAlive.startSilentLoop()
                }
            case .active:
                keepAlive.stopSilentLoop()
            default:
                break
            }
        }
        .fullScreenCover(item: $alarmViewModel.activeAlarm) { alarm in
            SAActiveAlarmOverlay(alarmViewModel: alarmViewModel, alarm: alarm)
        }
        .fullScreenCover(isPresented: $alarmViewModel.showSubscriptionPaywall) {
            SLPaywallScreen(vm: OnboardingFlowViewModel())
        }
    }

    @ViewBuilder
    private func destinationView(for route: AppEnums.NavigationRoute) -> some View {
        switch route {
        case .quranReading(let surah, let juz, let page):
            QuranReadingView(surah: surah, juz: juz, page: page)
        case .prayerDetail(let prayerType):
            Text(prayerType)
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
