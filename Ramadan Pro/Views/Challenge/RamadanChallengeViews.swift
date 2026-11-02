//
//  RamadanChallengeViews.swift
//  Ramadan Pro
//
//  UI for the free 90-Day Ramadan Ready challenge: the Home card, the
//  details sheet (progress, invite link, rewards, rules) and the free home
//  screen for people who joined without a subscription.
//

import SwiftUI
import UIKit

// MARK: - Home card

struct RamadanChallengeCard: View {
    @ObservedObject private var challenge = ChallengeService.shared
    @ObservedObject private var prayerLog = PrayerLogViewModel.shared
    @State private var showDetails = false

    var body: some View {
        Button { showDetails = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("🌙")
                        .font(.system(size: 22))
                    Text(L10n.text("90-Day Ramadan Ready challenge"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.slTextSecondary)
                }
                if let enrollment = challenge.enrollment {
                    joinedSummary(ChallengeProgress.compute(enrollment: enrollment, logs: prayerLog.weeklyLogs))
                } else {
                    Text(headline)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                    Text(L10n.text("Join free"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.slGreen, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.slGold.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetails) {
            RamadanChallengeSheet()
        }
        .task { await challenge.refreshCounts() }
    }

    private var headline: String {
        let start = RamadanChallenge.daysUntilStart()
        if start > 0 {
            return L10n.format("Starts in %d days. Ramadan is in %d days.", start, RamadanChallenge.daysUntilRamadan())
        }
        return L10n.format("Ramadan is in %d days. Lock in all five prayers and walk in ready.", RamadanChallenge.daysUntilRamadan())
    }

    @ViewBuilder
    private func joinedSummary(_ progress: ChallengeProgress) -> some View {
        if progress.day == 0 {
            Text(L10n.format("You're in. Day 1 starts in %d days.", RamadanChallenge.daysUntilStart()))
                .font(.system(size: 14))
                .foregroundColor(AppColors.slTextSecondary)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(L10n.format("Day %d", progress.day))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.slGold)
                Text(L10n.format("of %d", RamadanChallenge.lengthInDays))
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.slTextSecondary)
                Spacer()
                Text(progress.todayComplete ? L10n.text("Today done") : L10n.text("Today in progress"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(progress.todayComplete ? AppColors.slGreen : AppColors.slTextSecondary)
            }
            ProgressView(value: Double(progress.day), total: Double(RamadanChallenge.lengthInDays))
                .tint(AppColors.slGreen)
            Text(progress.isOnTrack
                 ? L10n.format("%@ · %d grace days left", RamadanChallenge.phaseTitle(progress.phase), progress.graceLeftThisPhase)
                 : L10n.text("Off track for Ramadan Ready, but keep going for Silver and Bronze."))
                .font(.system(size: 13))
                .foregroundColor(AppColors.slTextSecondary)
        }
    }
}

// MARK: - Details sheet

struct RamadanChallengeSheet: View {
    @ObservedObject private var challenge = ChallengeService.shared
    @ObservedObject private var prayerLog = PrayerLogViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var typedInviteCode = ChallengeInvite.pendingCode ?? ""
    @State private var shareImage: Image?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let enrollment = challenge.enrollment {
                        progressSection(enrollment)
                        inviteSection(enrollment)
                    } else {
                        joinSection
                    }
                    rewardsSection
                    phasesSection
                    rulesSection
                }
                .padding(20)
            }
            .background(AppColors.slCream.ignoresSafeArea())
            .navigationTitle(L10n.text("Ramadan Ready"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Done")) { dismiss() }
                }
            }
        }
        .task {
            await challenge.refreshCounts()
            renderShareImage()
        }
        .onChange(of: challenge.enrollment) { _ in renderShareImage() }
    }

    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("Be Ramadan ready in 90 days"))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.slTextPrimary)
            Text(L10n.text("Pray all five prayers on time every day from 10 November to 7 February, starting with Fajr. Free to join. No purchase needed."))
                .font(.system(size: 15))
                .foregroundColor(AppColors.slTextSecondary)
            if let count = challenge.globalJoinedCount, count > 0 {
                Text(L10n.format("%d people have joined", count))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.slGreen)
            }
            TextField(L10n.text("Got an invite code? (optional)"), text: $typedInviteCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            Button {
                Task { await challenge.join(invitedBy: typedInviteCode.isEmpty ? nil : typedInviteCode) }
            } label: {
                HStack {
                    if challenge.isJoining { ProgressView().tint(.white) }
                    Text(L10n.text("Join the challenge free"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppColors.slGreen, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(challenge.isJoining)
            if let error = challenge.lastError {
                Text(error).font(.system(size: 13)).foregroundColor(.red)
            }
        }
    }

    private func progressSection(_ enrollment: ChallengeEnrollment) -> some View {
        let progress = ChallengeProgress.compute(enrollment: enrollment, logs: prayerLog.weeklyLogs)
        return VStack(alignment: .leading, spacing: 8) {
            Text(progress.day == 0
                 ? L10n.format("Day 1 starts in %d days", RamadanChallenge.daysUntilStart())
                 : L10n.format("Day %d of %d", progress.day, RamadanChallenge.lengthInDays))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.slTextPrimary)
            HStack(spacing: 16) {
                stat(L10n.text("Days done"), "\(progress.completedDays)")
                stat(L10n.text("Missed"), "\(progress.missedDays)")
                stat(L10n.text("Grace left"), "\(progress.graceLeftThisPhase)")
            }
            Text(L10n.format("Current tier: %@", progress.tier.title))
                .font(.system(size: 14))
                .foregroundColor(AppColors.slTextSecondary)
        }
    }

    private func inviteSection(_ enrollment: ChallengeEnrollment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("Invite friends"))
                .font(.system(size: 18, weight: .bold))
            Text(L10n.format("Your code: %@", enrollment.code))
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
            Text(L10n.format("%d friends joined with your link", challenge.friendsJoined))
                .font(.system(size: 14))
                .foregroundColor(AppColors.slTextSecondary)
            if let url = RamadanChallenge.inviteURL(for: enrollment.code) {
                let message = L10n.format("I'm getting Ramadan ready in 90 days. Join me free: %@ %@", url.absoluteString, RamadanChallenge.hashtag)
                if let shareImage {
                    ShareLink(item: shareImage,
                              subject: Text(L10n.text("Join me in the Ramadan Ready challenge")),
                              message: Text(message),
                              preview: SharePreview(L10n.text("Ramadan Ready"), image: shareImage)) {
                        shareLabel
                    }
                    .simultaneousGesture(TapGesture().onEnded { challenge.logShare() })
                } else {
                    ShareLink(item: url, message: Text(message)) { shareLabel }
                        .simultaneousGesture(TapGesture().onEnded { challenge.logShare() })
                }
                Button {
                    UIPasteboard.general.string = url.absoluteString
                    challenge.logShare()
                } label: {
                    Text(L10n.text("Copy invite link"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.slGreen)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private var shareLabel: some View {
        Label(L10n.text("Share my invite"), systemImage: "square.and.arrow.up")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(AppColors.slGreen, in: RoundedRectangle(cornerRadius: 14))
    }

    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("Rewards"))
                .font(.system(size: 18, weight: .bold))
            bullet(L10n.text("3 friends join with your link and complete Day 1: 1 month of premium free"))
            bullet(L10n.text("10 friends join with your link and complete Day 1: 1 year of premium free"))
            bullet(L10n.text("Finish all 90 days: Ramadan Ready badge and a finisher reward"))
            Text(L10n.text("Rewards are added from early December and count every friend from Day 1."))
                .font(.system(size: 12))
                .foregroundColor(AppColors.slTextSecondary)
        }
    }

    private var phasesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("How it works"))
                .font(.system(size: 18, weight: .bold))
            bullet(L10n.text("Days 1 to 30: build Fajr, and log all five prayers"))
            bullet(L10n.text("Days 31 to 60: all five prayers on time, plus a page of Quran"))
            bullet(L10n.text("Days 61 to 90: Monday and Thursday sunnah fasts to train for Ramadan"))
            bullet(L10n.format("%d grace days per phase, so one missed day doesn't end your challenge", RamadanChallenge.graceDaysPerPhase))
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Link(L10n.text("Official rules"), destination: RamadanChallenge.rulesURL)
                .font(.system(size: 15, weight: .semibold))
            Text(L10n.text("Free to join. No purchase necessary, and a purchase does not improve your chances. Apple is not a sponsor of, and is not involved in, this challenge."))
                .font(.system(size: 12))
                .foregroundColor(AppColors.slTextSecondary)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(AppColors.slGold)
            Text(title).font(.system(size: 12)).foregroundColor(AppColors.slTextSecondary)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundColor(AppColors.slGreen)
            Text(text).font(.system(size: 14)).foregroundColor(AppColors.slTextPrimary)
        }
    }

    @MainActor
    private func renderShareImage() {
        guard let enrollment = challenge.enrollment else { return }
        let progress = ChallengeProgress.compute(enrollment: enrollment, logs: prayerLog.weeklyLogs)
        let renderer = ImageRenderer(content: ChallengeShareCard(progress: progress, code: enrollment.code))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }
}

// MARK: - Share card (rendered to an image for Stories and TikTok)

struct ChallengeShareCard: View {
    let progress: ChallengeProgress
    let code: String

    var body: some View {
        VStack(spacing: 14) {
            Text("🌙").font(.system(size: 48))
            Text(progress.day == 0
                 ? L10n.text("I'm in")
                 : L10n.format("Day %d of %d", progress.day, RamadanChallenge.lengthInDays))
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
            Text(L10n.format("%d days until Ramadan", RamadanChallenge.daysUntilRamadan()))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.slGold)
            Text(RamadanChallenge.hashtag)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text("salahalarm.com/c/\(code)")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(40)
        .frame(width: 360, height: 640)
        .background(
            LinearGradient(colors: [Color(hex: "#0F3D2E"), Color(hex: "#071A14")], startPoint: .top, endPoint: .bottom)
        )
    }
}

// MARK: - Free home (joined the challenge without a subscription)

struct ChallengeFreeHomeView: View {
    @ObservedObject private var prayerLog = PrayerLogViewModel.shared
    @StateObject private var prayerTimes = PrayerTimesViewModel()
    @State private var selectedPrayer: PrayerName?
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L10n.text("Today's prayers"))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                RamadanChallengeCard()
                VStack(spacing: 0) {
                    ForEach(PrayerName.allCases) { prayer in
                        prayerRow(prayer)
                        if prayer != .isha { Divider() }
                    }
                }
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                upgradeCard
            }
            .padding(20)
        }
        .background(AppColors.slCream.ignoresSafeArea())
        .task {
            await prayerTimes.loadPrayerTimes()
            await prayerLog.load()
            await ChallengeService.shared.refreshCounts()
        }
        .sheet(item: $selectedPrayer) { prayer in
            SLPrayerConfirmationSheet(
                prayer: prayer,
                onConfirm: {
                    Task {
                        await prayerLog.confirmPrayer(prayer)
                        selectedPrayer = nil
                    }
                },
                onDismiss: { selectedPrayer = nil }
            )
        }
        .fullScreenCover(isPresented: $showPaywall) {
            SLPaywallScreen(vm: OnboardingFlowViewModel(), onExit: { showPaywall = false })
        }
    }

    private func prayerRow(_ prayer: PrayerName) -> some View {
        let done = prayerLog.todayLog.isConfirmed(prayer)
        return Button {
            if !done { selectedPrayer = prayer }
        } label: {
            HStack {
                Text(prayer.emoji)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text(prayer.displayName))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.slTextPrimary)
                    if let time = prayerTimes.activeSchedule?.challengeTime(for: prayer) {
                        Text(time, style: .time)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.slTextSecondary)
                    }
                }
                Spacer()
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(done ? AppColors.slGreen : AppColors.slBorderDefault)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }

    private var upgradeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("Never sleep through Fajr"))
                .font(.system(size: 18, weight: .bold))
            Text(L10n.text("Premium adds the loud adhan alarm that won't stop until you're up, SalahLock, the Quran reader and widgets."))
                .font(.system(size: 14))
                .foregroundColor(AppColors.slTextSecondary)
            Button { showPaywall = true } label: {
                Text(L10n.text("Unlock premium"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(AppColors.slGold, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

extension DailyPrayerSchedule {
    func challengeTime(for prayer: PrayerName) -> Date? {
        switch prayer {
        case .fajr: return fajr
        case .dhuhr: return dhuhr
        case .asr: return asr
        case .maghrib: return maghrib
        case .isha: return isha
        }
    }
}
