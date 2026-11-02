//
//  ChallengeService.swift
//  Ramadan Pro
//
//  Joining the 90-Day Ramadan Ready challenge, invite codes, and referral
//  capture. Joining is free and does not need a subscription.
//
//  Firestore layout (shared with the salahalarm.com challenge page):
//    users/<uid>.challenge          = { joinedAt, code, invitedBy }
//    referrals/<CODE>               = { ownerUid, createdAt, joinedCount }
//    challengeStats/global          = { joinedCount }
//
//  Rewards (3 friends = 1 month, 10 friends = 1 year) are granted server-side
//  in v2, counting only friends who completed Day 1.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ChallengeService: ObservableObject {
    static let shared = ChallengeService()

    @Published private(set) var enrollment: ChallengeEnrollment?
    @Published private(set) var friendsJoined: Int = 0
    @Published private(set) var globalJoinedCount: Int?
    @Published private(set) var isJoining = false
    @Published var lastError: String?

    private let db = Firestore.firestore()
    private static let enrollmentKey = "ramadan_challenge_enrollment"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.enrollmentKey),
           let saved = try? JSONDecoder().decode(ChallengeEnrollment.self, from: data) {
            enrollment = saved
        }
    }

    var isEnrolled: Bool { enrollment != nil }

    var inviteURL: URL? {
        enrollment.flatMap { RamadanChallenge.inviteURL(for: $0.code) }
    }

    // MARK: - Joining

    /// Joins the challenge. Requires a signed-in account so progress syncs to
    /// the web profile. Returns true on success.
    @discardableResult
    func join(invitedBy typedCode: String? = nil) async -> Bool {
        if enrollment != nil { return true }
        guard let uid = Auth.auth().currentUser?.uid else {
            lastError = L10n.text("Sign in first so your progress is saved.")
            return false
        }
        isJoining = true
        lastError = nil
        defer { isJoining = false }

        // Restore if this account already joined on another device.
        if let existing = await fetchRemoteEnrollment(uid: uid) {
            save(existing)
            return true
        }

        let invitedBy = typedCode.flatMap(ChallengeInvite.normalizedCode) ?? ChallengeInvite.pendingCode
        var ownCode: String?
        for _ in 0..<5 {
            let candidate = ChallengeInvite.randomCode()
            do {
                // Rules allow create only, so an existing code fails and we retry.
                try await db.collection("referrals").document(candidate).setData([
                    "ownerUid": uid,
                    "createdAt": FieldValue.serverTimestamp(),
                    "joinedCount": 0
                ])
                ownCode = candidate
                break
            } catch {
                continue
            }
        }
        guard let code = ownCode else {
            lastError = L10n.text("Couldn't join right now. Check your connection and try again.")
            return false
        }

        let validInviter = (invitedBy != nil && invitedBy != code) ? invitedBy : nil
        let newEnrollment = ChallengeEnrollment(joinedAt: Date(), code: code, invitedBy: validInviter)
        var challengeData: [String: Any] = [
            "joinedAt": Timestamp(date: newEnrollment.joinedAt),
            "code": code
        ]
        if let validInviter { challengeData["invitedBy"] = validInviter }

        do {
            try await db.collection("users").document(uid).setData(["challenge": challengeData], merge: true)
        } catch {
            lastError = L10n.text("Couldn't join right now. Check your connection and try again.")
            return false
        }

        save(newEnrollment)
        ChallengeInvite.clearPendingCode()

        // Counters are best effort; the server recounts them for rewards.
        try? await db.collection("challengeStats").document("global").setData(
            ["joinedCount": FieldValue.increment(Int64(1))], merge: true)
        if let validInviter {
            try? await db.collection("referrals").document(validInviter).updateData(
                ["joinedCount": FieldValue.increment(Int64(1))])
        }

        AppsFlyerService.shared.logEvent("challenge_joined", parameters: ["invited": validInviter != nil])
        await refreshCounts()
        return true
    }

    /// Pulls the enrollment from Firestore when this device has none (reinstall,
    /// second device). Safe to call on every launch.
    func restoreIfNeeded() async {
        guard enrollment == nil, let uid = Auth.auth().currentUser?.uid else { return }
        if let existing = await fetchRemoteEnrollment(uid: uid) {
            save(existing)
        }
    }

    func refreshCounts() async {
        if let snapshot = try? await db.collection("challengeStats").document("global").getDocument(),
           let count = snapshot.data()?["joinedCount"] as? Int {
            globalJoinedCount = count
        }
        if let code = enrollment?.code,
           let snapshot = try? await db.collection("referrals").document(code).getDocument(),
           let count = snapshot.data()?["joinedCount"] as? Int {
            friendsJoined = count
        }
    }

    func logShare() {
        AppsFlyerService.shared.logEvent("challenge_shared", parameters: nil)
    }

    // MARK: - Private

    private func fetchRemoteEnrollment(uid: String) async -> ChallengeEnrollment? {
        guard let snapshot = try? await db.collection("users").document(uid).getDocument(),
              let challenge = snapshot.data()?["challenge"] as? [String: Any],
              let code = challenge["code"] as? String else { return nil }
        let joinedAt = (challenge["joinedAt"] as? Timestamp)?.dateValue() ?? Date()
        return ChallengeEnrollment(joinedAt: joinedAt, code: code, invitedBy: challenge["invitedBy"] as? String)
    }

    private func save(_ value: ChallengeEnrollment) {
        enrollment = value
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: Self.enrollmentKey)
        }
    }

}

/// Invite code helpers. Not actor-isolated so the app delegate, URL handlers
/// and the AppsFlyer delegate can call them from any thread.
enum ChallengeInvite {
    static let codeLength = 6
    private static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    private static let pendingKey = "ramadan_challenge_pending_invite"

    /// Accepts "abc234", " ABC234 " etc. Returns nil if it is not a valid code.
    static func normalizedCode(_ raw: String) -> String? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleaned.count == codeLength, cleaned.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return cleaned
    }

    /// Reads a code from https://salahalarm.com/c/CODE or salahalarm://c/CODE.
    static func code(from url: URL) -> String? {
        var parts = url.pathComponents.filter { $0 != "/" }
        if url.scheme == "salahalarm", let host = url.host { parts.insert(host, at: 0) }
        guard let index = parts.firstIndex(where: { $0.lowercased() == "c" }), index + 1 < parts.count else { return nil }
        return normalizedCode(parts[index + 1])
    }

    /// Remembers an invite code until the user joins. The first code wins.
    static func storePendingCode(_ rawCode: String) {
        guard let code = normalizedCode(rawCode) else { return }
        if UserDefaults.standard.string(forKey: pendingKey) == nil {
            UserDefaults.standard.set(code, forKey: pendingKey)
        }
    }

    static var pendingCode: String? {
        UserDefaults.standard.string(forKey: pendingKey)
    }

    /// Set when a link asks the app to open the "Invite friends" screen
    /// (salahalarm.com/c/invite, OneLink deep_link_value=challenge_invite).
    private static let openInviteKey = "ramadan_challenge_open_invite"

    static func requestOpenInviteScreen() {
        UserDefaults.standard.set(true, forKey: openInviteKey)
    }

    /// Returns true once per request, then clears it.
    static func consumeOpenInviteRequest() -> Bool {
        guard UserDefaults.standard.bool(forKey: openInviteKey) else { return false }
        UserDefaults.standard.removeObject(forKey: openInviteKey)
        return true
    }

    /// Handles a challenge link. Returns true if the URL was a challenge link.
    @discardableResult
    static func handle(url: URL) -> Bool {
        var parts = url.pathComponents.filter { $0 != "/" }
        if url.scheme == "salahalarm", let host = url.host { parts.insert(host, at: 0) }
        guard let index = parts.firstIndex(where: { $0.lowercased() == "c" }), index + 1 < parts.count else { return false }
        let target = parts[index + 1].lowercased()
        if target == "invite" {
            requestOpenInviteScreen()
            return true
        }
        if target == "join" { return true }
        if let code = normalizedCode(parts[index + 1]) {
            storePendingCode(code)
            return true
        }
        return false
    }

    static func clearPendingCode() {
        UserDefaults.standard.removeObject(forKey: pendingKey)
    }

    static func randomCode() -> String {
        String((0..<codeLength).map { _ in alphabet.randomElement()! })
    }
}
