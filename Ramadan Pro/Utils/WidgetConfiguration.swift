//
//  WidgetConfiguration.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation

// MARK: - Debug Logging (inline, works in both app and widget)
#if DEBUG
private func logConfig(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    let timestamp = formatter.string(from: Date())
    print("⚙️ [CONFIG] [\(timestamp)] \(message)")
}

private func logConfigError(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    let timestamp = formatter.string(from: Date())
    print("❌ [CONFIG ERROR] [\(timestamp)] \(message)")
}

private func logConfigSuccess(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    let timestamp = formatter.string(from: Date())
    print("✅ [CONFIG SUCCESS] [\(timestamp)] \(message)")
}
#else
private func logConfig(_ message: String) {}
private func logConfigError(_ message: String) {}
private func logConfigSuccess(_ message: String) {}
#endif

/// Configuration constants for widget functionality
enum WidgetConfig {
    /// App Group identifier for sharing data between app and widget
    /// IMPORTANT: This must match the App Group identifier configured in:
    /// 1. Xcode project settings (Signing & Capabilities)
    /// 2. Widget Extension target (Signing & Capabilities)
    /// 3. Apple Developer Portal (App Groups)
    static let appGroupIdentifier = "group.ramadan-pro.sonn"
    
    /// UserDefaults suite for widget data sharing
    static var sharedUserDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }
    
    /// Key for saving user location in shared UserDefaults
    static let userLocationKey = "saved_user_location"
    
    /// Key for subscription status (widget shows locked state when false)
    static let isSubscribedKey = "isSubscribed"
    static let streakDataKey = "salahlock_streak_data"
    static let displayNameKey = "salahlock_display_name"
    
    /// Load subscription status from shared container (for widget)
    static func loadIsSubscribed() -> Bool {
        sharedUserDefaults?.bool(forKey: isSubscribedKey) ?? false
    }
    
    /// Save subscription status to shared container (call from main app when it changes)
    static func saveIsSubscribed(_ value: Bool) {
        sharedUserDefaults?.set(value, forKey: isSubscribedKey)
        sharedUserDefaults?.synchronize()
    }

    static func saveDisplayName(_ value: String) {
        sharedUserDefaults?.set(value, forKey: displayNameKey)
        sharedUserDefaults?.synchronize()
    }

    static func loadDisplayName() -> String {
        sharedUserDefaults?.string(forKey: displayNameKey) ?? ""
    }
    
    /// Save location to shared container for widget access
    static func saveLocation(_ location: UserLocation) {
        logConfig("WidgetConfig.saveLocation() called for: \(location.city)")
        
        guard let encoded = try? JSONEncoder().encode(location) else {
            logConfigError("Failed to encode UserLocation")
            return
        }
        
        if let sharedDefaults = sharedUserDefaults {
            sharedDefaults.set(encoded, forKey: userLocationKey)
            logConfigSuccess("Location saved to shared UserDefaults with key: \(userLocationKey)")
        } else {
            logConfigError("Shared UserDefaults is nil - cannot save location!")
        }
    }
    
    /// Load location from shared container
    static func loadLocation() -> UserLocation? {
        logConfig("WidgetConfig.loadLocation() called")
        
        guard let sharedDefaults = sharedUserDefaults else {
            logConfigError("Shared UserDefaults is nil - App Groups not configured!")
            return nil
        }
        
        guard let data = sharedDefaults.data(forKey: userLocationKey) else {
            logConfig("No location data found in shared container with key: \(userLocationKey)")
            return nil
        }
        
        guard let location = try? JSONDecoder().decode(UserLocation.self, from: data) else {
            logConfigError("Failed to decode UserLocation from shared container")
            return nil
        }
        
        logConfigSuccess("Location loaded from shared container: \(location.city)")
        return location
    }

    static func savePrayerLog<T: Encodable>(_ log: T, for dateString: String) {
        guard let encoded = try? JSONEncoder().encode(log) else { return }
        sharedUserDefaults?.set(encoded, forKey: "salahlock_prayer_log_\(dateString)")
        sharedUserDefaults?.synchronize()
    }

    static func loadPrayerLog<T: Decodable>(for dateString: String, as type: T.Type) -> T? {
        guard let data = sharedUserDefaults?.data(forKey: "salahlock_prayer_log_\(dateString)") else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func saveStreakData<T: Encodable>(_ streakData: T) {
        guard let encoded = try? JSONEncoder().encode(streakData) else { return }
        sharedUserDefaults?.set(encoded, forKey: streakDataKey)
        sharedUserDefaults?.synchronize()
    }

    static func loadStreakData<T: Decodable>(as type: T.Type) -> T? {
        guard let data = sharedUserDefaults?.data(forKey: streakDataKey),
              let streak = try? JSONDecoder().decode(type, from: data) else { return nil }
        return streak
    }
}
