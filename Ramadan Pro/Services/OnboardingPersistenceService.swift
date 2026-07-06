//
//  OnboardingPersistenceService.swift
//  Ramadan Pro
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct OnboardingLocalCache: Codable {
    let profile: OnboardingProfile
    let plan: OnboardingDerivedPlan
    let lastScreen: String
}

final class OnboardingPersistenceService {
    private let localKey = "salahalarm_onboarding_cache"
    private let db = Firestore.firestore()

    func saveLocal(profile: OnboardingProfile, plan: OnboardingDerivedPlan, lastScreen: String) {
        let payload = OnboardingLocalCache(profile: profile, plan: plan, lastScreen: lastScreen)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: localKey)
    }

    func loadLocal() -> OnboardingLocalCache? {
        guard let data = UserDefaults.standard.data(forKey: localKey),
              let cache = try? JSONDecoder().decode(OnboardingLocalCache.self, from: data) else {
            return nil
        }
        return cache
    }

    func clearLocal() {
        UserDefaults.standard.removeObject(forKey: localKey)
    }

    func saveToFirestore(profile: OnboardingProfile, plan: OnboardingDerivedPlan) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let profileData = Self.encodeProfile(profile)
        let planData = Self.encodePlan(plan)

        do {
            try await db.collection("users").document(userId).setData([
                "onboardingProfile": profileData,
                "onboardingDerivedPlan": planData,
                "onboardingLastScreen": profile.lastCompletedScreen,
                "onboardingCompletedAt": profile.onboardingCompletedAt as Any
            ], merge: true)
        } catch {
            print("⚠️ OnboardingPersistenceService: Failed saving onboarding to Firestore - \(error.localizedDescription)")
        }
    }

    static func encodeProfile(_ profile: OnboardingProfile) -> [String: Any] {
        [
            "displayName": profile.displayName,
            "ageRange": profile.ageRange.rawValue,
            "prayerFrequency": profile.prayerFrequency.rawValue,
            "dailyPhoneUsageRange": profile.dailyPhoneUsageRange.rawValue,
            "goals": profile.goals.map(\.rawValue),
            "obstacles": profile.obstacles.map(\.rawValue),
            "relationshipWithAllah": profile.relationshipWithAllah.rawValue,
            "deeperStruggles": profile.deeperStruggles.map(\.rawValue),
            "muslimBackground": profile.muslimBackground.rawValue,
            "gender": profile.gender.rawValue,
            "commitmentLevel": profile.commitmentLevel.rawValue,
            "notificationsPermissionState": profile.notificationsPermissionState.rawValue,
            "locationPermissionState": profile.locationPermissionState.rawValue,
            "missedPrayerFocus": profile.missedPrayerFocus.map(\.rawValue),
            "selectedAlarmPrayers": profile.selectedAlarmPrayers.map(\.rawValue),
            "alarmStrictness": profile.alarmStrictness.rawValue,
            "alarmSoundName": profile.alarmSoundName,
            "cameraPermissionState": profile.cameraPermissionState.rawValue,
            "matSetupCompleted": profile.matSetupCompleted,
            "firstPrayerCompletedAt": profile.firstPrayerCompletedAt as Any,
            "onboardingCompletedAt": profile.onboardingCompletedAt as Any,
            "lastCompletedScreen": profile.lastCompletedScreen
        ]
    }

    static func encodePlan(_ plan: OnboardingDerivedPlan) -> [String: Any] {
        [
            "annualPhoneHours": plan.annualPhoneHours,
            "annualPhoneDays": plan.annualPhoneDays,
            "lifetimePhoneYears": plan.lifetimePhoneYears,
            "currentHabitSummary": plan.currentHabitSummary,
            "strengthStatement": plan.strengthStatement,
            "targetConsistencyDate": plan.targetConsistencyDate,
            "commitmentProgressPct": plan.commitmentProgressPct,
            "primaryGoal": plan.primaryGoal,
            "topGoals": plan.topGoals,
            "alarmCount": plan.alarmCount,
            "alarmPrayerNames": plan.alarmPrayerNames,
            "topObstacles": plan.topObstacles,
            "yearlySalahMoments": plan.yearlySalahMoments
        ]
    }
}
