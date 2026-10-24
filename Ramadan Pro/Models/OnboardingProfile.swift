//
//  OnboardingProfile.swift
//  Ramadan Pro
//

import Foundation

struct OnboardingProfile: Codable {
    var displayName: String = ""
    var ageRange: AgeRange = .unset
    var prayerFrequency: PrayerFrequency = .unset
    var dailyPhoneUsageRange: PhoneUsageRange = .unset
    var goals: [UserGoal] = []
    var obstacles: [UserObstacle] = []
    var relationshipWithAllah: RelationshipState = .unset
    var deeperStruggles: [DeeperStruggle] = []
    var muslimBackground: MuslimBackground = .unset
    var gender: UserGender = .unset
    var commitmentLevel: CommitmentLevel = .unset
    var selectedDistractingApps: [String] = []
    var notificationsPermissionState: PermissionState = .notDetermined
    var locationPermissionState: PermissionState = .notDetermined
    var screenTimePermissionState: PermissionState = .notDetermined
    var missedPrayerFocus: [PrayerName] = []
    var selectedAlarmPrayers: [PrayerName] = PrayerName.allCases
    var alarmStrictness: AlarmStrictness = .strict
    var alarmSoundName: String = AlarmSoundOption.makkahLoud.rawValue
    var cameraPermissionState: PermissionState = .notDetermined
    var matSetupCompleted: Bool = false
    var firstPrayerCompletedAt: Date? = nil
    var onboardingCompletedAt: Date? = nil
    var lastCompletedScreen: String = OnboardingScreenID.screen0.rawValue
}

enum AgeRange: String, Codable, CaseIterable {
    case unset
    case r14_24
    case r25_34
    case r35_44
    case r45_54
    case r55plus

    var displayLabel: String {
        switch self {
        case .unset: return ""
        case .r14_24: return "14 - 24"
        case .r25_34: return "25 - 34"
        case .r35_44: return "35 - 44"
        case .r45_54: return "45 - 54"
        case .r55plus: return "55+"
        }
    }
}

enum PrayerFrequency: String, Codable, CaseIterable {
    case unset
    case fiveTimes
    case threeToFour
    case oneToTwo
    case none

    var displayLabel: String {
        switch self {
        case .unset: return ""
        case .fiveTimes: return L10n.text("five times a day")
        case .threeToFour: return L10n.text("three to four times a day")
        case .oneToTwo: return L10n.text("one to two times a day")
        case .none: return L10n.text("i currently don't pray at all")
        }
    }

    var habitSummary: String {
        switch self {
        case .unset: return ""
        case .fiveTimes: return L10n.text("You already show up for salah daily and want stronger consistency.")
        case .threeToFour: return L10n.text("You pray often and want to close the gap to full consistency.")
        case .oneToTwo: return L10n.text("You are rebuilding the habit and need more structure around prayer.")
        case .none: return L10n.text("You are at the beginning of your prayer journey and need a simple first step.")
        }
    }
}

enum PhoneUsageRange: String, Codable, CaseIterable {
    case unset
    case r1_2
    case r2_3
    case r3_4
    case r4_5
    case r6plus

    var displayLabel: String {
        switch self {
        case .unset: return ""
        case .r1_2: return "1 - 2 hours"
        case .r2_3: return "2 - 3 hours"
        case .r3_4: return "3 - 4 hours"
        case .r4_5: return "4 - 5 hours"
        case .r6plus: return "6+ hours"
        }
    }
}

enum UserGoal: String, Codable, CaseIterable {
    case allahFirst
    case consistentPrayer
    case deepenRelationship
    case fajrMornings
    case findPeace
    case strengthenImaan

    var emoji: String {
        switch self {
        case .allahFirst: return "🤲"
        case .consistentPrayer: return "🕌"
        case .deepenRelationship: return "💚"
        case .fajrMornings: return "☀️"
        case .findPeace: return "🌍"
        case .strengthenImaan: return "📿"
        }
    }

    var displayLabel: String {
        switch self {
        case .allahFirst: return L10n.text("put Allah first, before my phone")
        case .consistentPrayer: return L10n.text("build a consistent prayer habit")
        case .deepenRelationship: return L10n.text("deepen my relationship with Allah")
        case .fajrMornings: return L10n.text("start my day with Fajr")
        case .findPeace: return L10n.text("find peace in a chaotic world")
        case .strengthenImaan: return L10n.text("strengthen my imaan")
        }
    }
}

enum UserObstacle: String, Codable, CaseIterable {
    case phoneSocialMedia
    case lowMotivation
    case busySchedule
    case wanderingThoughts
    case lackDiscipline
    case forgettingTimes

    var emoji: String {
        switch self {
        case .phoneSocialMedia: return "📱"
        case .lowMotivation: return "😴"
        case .busySchedule: return "⏰"
        case .wanderingThoughts: return "🧠"
        case .lackDiscipline: return "💪"
        case .forgettingTimes: return "😶"
        }
    }

    var displayLabel: String {
        switch self {
        case .phoneSocialMedia: return L10n.text("phone & social media distraction")
        case .lowMotivation: return L10n.text("low motivation or tiredness")
        case .busySchedule: return L10n.text("busy schedule, no time")
        case .wanderingThoughts: return L10n.text("wandering thoughts during salah")
        case .lackDiscipline: return L10n.text("lack of discipline")
        case .forgettingTimes: return L10n.text("forgetting prayer times")
        }
    }
}

enum RelationshipState: String, Codable, CaseIterable {
    case unset
    case upsAndDowns
    case feelingDistant
    case rebuilding
    case closeAndConsistent

    var emoji: String {
        switch self {
        case .unset: return ""
        case .upsAndDowns: return "📈"
        case .feelingDistant: return "😔"
        case .rebuilding: return "🌱"
        case .closeAndConsistent: return "🤲"
        }
    }

    var displayLabel: String {
        switch self {
        case .unset: return ""
        case .upsAndDowns: return L10n.text("it has its ups and downs")
        case .feelingDistant: return L10n.text("feeling a bit distant lately")
        case .rebuilding: return L10n.text("i'm trying to rebuild my connection")
        case .closeAndConsistent: return L10n.text("close and consistent, Alhamdulillah")
        }
    }
}

enum DeeperStruggle: String, Codable, CaseIterable {
    case temptations
    case anxiety
    case spirituallyEmpty
    case pride
    case prayersNotAccepted

    var emoji: String {
        switch self {
        case .temptations: return "🔥"
        case .anxiety: return "😰"
        case .spirituallyEmpty: return "😞"
        case .pride: return "💪"
        case .prayersNotAccepted: return "😶"
        }
    }

    var displayLabel: String {
        switch self {
        case .temptations: return L10n.text("struggling with temptations")
        case .anxiety: return L10n.text("constant worry or anxiety")
        case .spirituallyEmpty: return L10n.text("feeling spiritually empty")
        case .pride: return L10n.text("pride or relying only on myself")
        case .prayersNotAccepted: return L10n.text("I don't feel like my prayers are accepted")
        }
    }
}

enum MuslimBackground: String, Codable, CaseIterable {
    case unset
    case sunni
    case shia
    case justMuslim
    case revert
    case preferNotSay

    var displayLabel: String {
        switch self {
        case .unset: return ""
        case .sunni: return L10n.text("Sunni")
        case .shia: return L10n.text("Shia")
        case .justMuslim: return L10n.text("Just Muslim")
        case .revert: return L10n.text("Revert / New to Islam")
        case .preferNotSay: return L10n.text("Prefer not to say")
        }
    }
}

enum UserGender: String, Codable, CaseIterable {
    case unset
    case man
    case woman
    case preferNotSay

    var displayLabel: String {
        switch self {
        case .unset: return ""
        case .man: return L10n.text("Man")
        case .woman: return L10n.text("Woman")
        case .preferNotSay: return L10n.text("Prefer not to say")
        }
    }
}

enum CommitmentLevel: String, Codable, CaseIterable {
    case unset
    case extremelyCommitted
    case veryCommitted
    case committed
    case startingJourney
    case justExploring

    var emoji: String {
        switch self {
        case .unset: return ""
        case .extremelyCommitted: return "🔥"
        case .veryCommitted: return "💪"
        case .committed: return "🤲"
        case .startingJourney: return "🌱"
        case .justExploring: return "🙂"
        }
    }

    var displayLabel: String {
        switch self {
        case .unset: return ""
        case .extremelyCommitted: return L10n.text("Extremely committed")
        case .veryCommitted: return L10n.text("Very committed")
        case .committed: return L10n.text("Committed")
        case .startingJourney: return L10n.text("Starting my journey")
        case .justExploring: return L10n.text("Just exploring for now")
        }
    }

    var description: String {
        switch self {
        case .unset: return ""
        case .extremelyCommitted: return L10n.text("I want all five prayers, daily")
        case .veryCommitted: return L10n.text("I want to improve my consistency")
        case .committed: return L10n.text("I'm trying to pray more often")
        case .startingJourney: return L10n.text("I want to build the habit")
        case .justExploring: return L10n.text("I'm still exploring for now")
        }
    }

    var progressPercentage: Double {
        switch self {
        case .unset: return 0
        case .extremelyCommitted: return 1
        case .veryCommitted: return 0.82
        case .committed: return 0.64
        case .startingJourney: return 0.42
        case .justExploring: return 0.18
        }
    }
}

enum PermissionState: String, Codable {
    case notDetermined
    case granted
    case denied
    case skipped
}
