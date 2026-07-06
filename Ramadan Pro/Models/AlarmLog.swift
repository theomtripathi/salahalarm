//
//  AlarmLog.swift
//  Ramadan Pro
//

import Foundation

struct AlarmLog: Identifiable, Codable, Hashable {
    let id: UUID
    let prayer: PrayerName
    let scheduledTime: Date
    let firedAt: Date
    let dismissedAt: Date?
    let dismissalMethod: DismissalMethod

    init(
        id: UUID = UUID(),
        prayer: PrayerName,
        scheduledTime: Date,
        firedAt: Date,
        dismissedAt: Date? = nil,
        dismissalMethod: DismissalMethod
    ) {
        self.id = id
        self.prayer = prayer
        self.scheduledTime = scheduledTime
        self.firedAt = firedAt
        self.dismissedAt = dismissedAt
        self.dismissalMethod = dismissalMethod
    }

    enum DismissalMethod: String, Codable, Hashable {
        case ringing
        case matScan
        case manual
        case missed
        case snoozed
    }
}
