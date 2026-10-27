//
//  PrayerTimesViewModel.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import Combine
import SwiftUI
import WidgetKit

/// ViewModel for managing prayer times and fasting status
@MainActor
class PrayerTimesViewModel: ObservableObject {
    @Published var currentSchedule: DailyPrayerSchedule?
    @Published var tomorrowSchedule: DailyPrayerSchedule?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentLocation: UserLocation?
    
    private let locationManager = LocationManager.shared
    private let notificationManager = NotificationManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    
    init() {
        setupLocationObserver()
        startAutoRefresh()
    }
    
    /// Load prayer times for current date and location
    func loadPrayerTimes() async {
        isLoading = true
        errorMessage = nil
        
        // Get or request location
        if let location = locationManager.currentLocation {
            await loadPrayerTimes(for: location)
        } else {
            locationManager.startUpdatingLocation { [weak self] location in
                Task { @MainActor in
                    if let location = location {
                        await self?.loadPrayerTimes(for: location)
                    } else {
                        self?.isLoading = false
                        self?.errorMessage = "Unable to get your location. Please enable location access."
                    }
                }
            }
        }
    }
    
    /// Load prayer times for a specific location
    func loadPrayerTimes(for location: UserLocation) async {
        isLoading = true
        errorMessage = nil
        currentLocation = location
        
        let today = Date()
        let calendar = Calendar.current
        
        // Load today's schedule
        let schedule = PrayerTimesCalculator.calculatePrayerTimes(
            for: today,
            location: location
        )
        
        currentSchedule = schedule
        
        // Also load tomorrow's schedule
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
            let tomorrowSchedule = PrayerTimesCalculator.calculatePrayerTimes(
                for: tomorrow,
                location: location
            )
            self.tomorrowSchedule = tomorrowSchedule
        }
        
        isLoading = false
        
        // Store location for future use
        saveLocation(location)
        
        // Schedule notifications for prayers
        await schedulePrayerNotifications()
    }
    
    /// Refresh prayer times (useful when date changes)
    func refresh() async {
        guard let location = currentLocation else {
            await loadPrayerTimes()
            return
        }
        
        await loadPrayerTimes(for: location)
        // Notifications will be rescheduled automatically via loadPrayerTimes
    }
    
    /// Get fasting status for current time
    var fastingStatus: FastingStatus {
        return currentSchedule?.currentFastingStatus ?? .notStarted
    }
    
    /// Get fasting progress (0.0 to 1.0)
    var fastingProgress: Double {
        return currentSchedule?.fastingProgress ?? 0.0
    }
    
    /// Get time until Iftar (Maghrib)
    var timeUntilIftar: TimeInterval? {
        return currentSchedule?.timeUntilMaghrib
    }
    
    /// Get the active schedule (today's if prayers remain, tomorrow's if all today's prayers have passed)
    var activeSchedule: DailyPrayerSchedule? {
        guard let todaySchedule = currentSchedule else { return nil }
        let now = Date()
        
        // Check if all today's prayers have passed
        let allPrayersPassed = now > todaySchedule.isha
        
        if allPrayersPassed, let tomorrowSchedule = tomorrowSchedule {
            return tomorrowSchedule
        } else {
            return todaySchedule
        }
    }
    
    /// Check if we're showing tomorrow's schedule
    var isShowingTomorrowSchedule: Bool {
        guard let todaySchedule = currentSchedule else { return false }
        let now = Date()
        return now > todaySchedule.isha && tomorrowSchedule != nil
    }
    
    /// Get time until Imsak
    var timeUntilImsak: TimeInterval? {
        return currentSchedule?.timeUntilImsak
    }
    
    /// Format time interval as countdown string
    func formatCountdown(_ interval: TimeInterval?) -> String {
        guard let interval = interval, interval > 0 else {
            return "00:00:00"
        }
        
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // MARK: - Private Methods
    
    private func setupLocationObserver() {
        locationManager.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                if let location = location {
                    Task { @MainActor in
                        await self?.loadPrayerTimes(for: location)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func startAutoRefresh() {
        // Refresh every minute to update countdowns
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }
    
    private func saveLocation(_ location: UserLocation) {
        DebugLogger.log("Saving location: \(location.city) (\(location.latitude), \(location.longitude))")
        
        // Save to UserDefaults for persistence (both standard and shared for widget)
        if let encoded = try? JSONEncoder().encode(location) {
            UserDefaults.standard.set(encoded, forKey: "saved_user_location")
            DebugLogger.log("Location saved to standard UserDefaults")
            
            // Also save to shared container for widget access
            WidgetConfig.saveLocation(location)
            DebugLogger.logSuccess("Location saved to shared container (App Group)")
            
            // Reload widget timeline so it picks up the new location
            WidgetHelper.reloadWidgetTimeline()
            DebugLogger.log("Widget timeline reload requested")
        } else {
            DebugLogger.logError("Failed to encode location for saving")
        }
    }
    
    private func loadSavedLocation() -> UserLocation? {
        guard let data = UserDefaults.standard.data(forKey: "saved_user_location"),
              let location = try? JSONDecoder().decode(UserLocation.self, from: data) else {
            return nil
        }
        return location
    }
    
    /// Schedule prayer notifications
    private func schedulePrayerNotifications() async {
        // Request authorization if needed
        let status = await notificationManager.getAuthorizationStatus()
        if status != .authorized {
            let granted = await notificationManager.requestAuthorization()
            if !granted {
                DebugLogger.logError("Notification permission denied")
                return
            }
        }
        
        // Schedule notifications for current and tomorrow's schedule
        guard let currentSchedule = currentSchedule, let location = currentLocation else {
            return
        }
        
        notificationManager.scheduleNotificationsForUpcomingDays(
            currentSchedule: currentSchedule,
            tomorrowSchedule: tomorrowSchedule,
            location: location
        )
    }
    
    deinit {
        timer?.invalidate()
    }
}
