// Onboarding answers from the web flow, stored in users/{uid} with the same
// field names and raw values the iOS app writes (OnboardingPersistenceService).

const PRAYERS = ["fajr", "dhuhr", "asr", "maghrib", "isha"];
const GOALS = ["allahFirst", "consistentPrayer", "deepenRelationship", "fajrMornings", "findPeace", "strengthenImaan"];
const COMMITMENT = ["unset", "extremelyCommitted", "veryCommitted", "committed", "startingJourney", "justExploring"];
const STRICTNESS = ["strict", "moderate", "relaxed"];
const SOUNDS = ["Makkah Adhan Loud", "Madinah Adhan Loud", "Fajr Adhan Loud", "Takbir Alarm Loud"];

const pick = (value, allowed, fallback) => (allowed.includes(value) ? value : fallback);
const list = (value, allowed) => (Array.isArray(value) ? [...new Set(value.filter((v) => allowed.includes(v)))] : []);

export function sanitizeProfile(body = {}) {
  const p = body.profile || {};
  const selectedAlarmPrayers = list(p.selectedAlarmPrayers, PRAYERS);
  const goals = list(p.goals, GOALS).slice(0, 3);
  const profile = {
    displayName: String(p.displayName || "").slice(0, 60),
    ageRange: "unset",
    prayerFrequency: "unset",
    dailyPhoneUsageRange: "unset",
    goals,
    obstacles: [],
    relationshipWithAllah: "unset",
    deeperStruggles: [],
    muslimBackground: "unset",
    gender: "unset",
    commitmentLevel: pick(p.commitmentLevel, COMMITMENT, "unset"),
    notificationsPermissionState: "notDetermined",
    locationPermissionState: "notDetermined",
    missedPrayerFocus: [],
    selectedAlarmPrayers: selectedAlarmPrayers.length ? selectedAlarmPrayers : PRAYERS,
    alarmStrictness: pick(p.alarmStrictness, STRICTNESS, "strict"),
    alarmSoundName: pick(p.alarmSoundName, SOUNDS, SOUNDS[0]),
    cameraPermissionState: "notDetermined",
    matSetupCompleted: false,
    lastCompletedScreen: String(p.lastCompletedScreen || "screen17").slice(0, 20),
  };
  const plan = {
    primaryGoal: goals[0] || "consistentPrayer",
    topGoals: goals,
    alarmCount: profile.selectedAlarmPrayers.length,
    alarmPrayerNames: profile.selectedAlarmPrayers,
    yearlySalahMoments: profile.selectedAlarmPrayers.length * 365,
  };
  return { profile, plan };
}
