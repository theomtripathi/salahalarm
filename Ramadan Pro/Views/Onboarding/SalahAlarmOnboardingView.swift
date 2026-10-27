//
//  SalahAlarmOnboardingView.swift
//  Ramadan Pro
//

import SwiftUI
import CoreLocation
import AVFoundation
import Charts
import UniformTypeIdentifiers
import StoreKit
import FamilyControls
import PostHog

struct SalahAlarmOnboardingView: View {
    @AppStorage(AppLanguage.confirmedKey) private var hasChosenLanguage = false
    @State private var didRestoreProgress = false
    @StateObject private var vm = OnboardingFlowViewModel()
    @ObservedObject private var authService = FirebaseAuthService.shared
    @State private var showFileImporter = false
    @State private var showOnboardingAppPicker = false
    @ObservedObject private var lockManager = AppLockManager.shared
    private let alarmAudioService = AlarmAudioService.shared

    var body: some View {
        Group {
            if hasChosenLanguage {
                onboardingContent
            } else {
                LanguagePickerView()
            }
        }
    }

    private var onboardingContent: some View {
        ZStack {
            AppColors.slBackground.ignoresSafeArea()

            switch vm.currentScreen {
            case .screen0:
                SLScreen0SignUp(vm: vm)
            case .screen1:
                splashScreen
                    .postHogNoMask()
            case .screen2:
                messageScreen(
                    eyebrow: "The part normal alarms miss",
                    title: "The Problem Isn't Setting an Alarm. It's How Easy It Is to Dismiss.",
                    body: "One tap, one snooze, and the moment passes. SalahAlarm adds a real action between the reminder and turning it off.",
                    cta: "see how it works"
                )
                .postHogNoMask()
            case .screen3:
                featuresScreen
                    .postHogNoMask()
            case .screen4:
                prayerFrequencyScreen
            case .screen5:
                phoneUsageScreen
            case .screen6:
                alarmPrayerSelectionScreen
            case .screen7A:
                goalsScreen
            case .screen7B:
                screenTimeInsightScreen
            case .screen8:
                commitmentScreen
            case .screen9:
                loaderScreen
            case .screen10:
                planReadyScreen
            case .screen10A:
                // Review prompt removed from onboarding; keep the case so users
                // with saved progress on this screen fall through to the next.
                notificationsScreen
            case .screen11:
                notificationsScreen
            case .screen12:
                soundSetupScreen
            case .screen13:
                silentModeScreen
            case .screen14:
                locationScreen
            case .screen15:
                cameraPermissionScreen
            case .screen16:
                matSetupScreen
            case .screen16A:
                lockIntroScreen
            case .screen16B:
                lockSetupScreen
            case .screen17:
                SLScreen0SignUp(vm: vm)
            case .screen17A:
                salahIsPowerfulScreen
            case .screen17B:
                futureHabitScreen
            case .screen17C:
                socialProofScreen
            case .screen17D:
                freeToTryScreen
            case .screen17E:
                trialReminderScreen
            case .screen17F:
                whyWeNeedSupportScreen
            case .screen18:
                SLPaywallScreen(vm: vm)
            default:
                splashScreen
                    .onAppear {
                        vm.currentScreen = .screen1
                    }
            }
        }
        .onAppear {
            guard !didRestoreProgress else { return }
            didRestoreProgress = true
            #if DEBUG
            // Screenshot/QA hook: launch with `-SAOnboardingScreen screen14` to open a step directly.
            if let raw = UserDefaults.standard.string(forKey: "SAOnboardingScreen"),
               let screen = OnboardingScreenID(rawValue: raw) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { vm.currentScreen = screen }
                vm.startAnalytics()
                return
            }
            #endif
            if let savedScreen = vm.loadSavedProgress() {
                let allowed: Set<OnboardingScreenID> = [
                    .screen0, .screen1, .screen2, .screen3, .screen4, .screen5, .screen6,
                    .screen7A, .screen7B, .screen8, .screen9, .screen10, .screen11,
                    .screen12, .screen13, .screen14, .screen15, .screen16, .screen16A,
                    .screen16B, .screen17,
                    .screen17A, .screen17B, .screen17C, .screen17D, .screen17E, .screen17F, .screen18
                ]
                let resolvedScreen = allowed.contains(savedScreen) ? savedScreen : .screen1
                if resolvedScreen == .screen0 && !authService.isAuthenticated {
                    vm.currentScreen = .screen1
                } else if authService.isAuthenticated && resolvedScreen == .screen17 {
                    // If they are on screen17 (signup) but already authenticated, they should move to the next step.
                    // We advance them to 17A to start the 3-step payment onboarding.
                    vm.currentScreen = .screen18
                } else {
                    vm.currentScreen = resolvedScreen
                }
            } else {
                vm.currentScreen = .screen1
            }
            vm.startAnalytics()
        }
        .animation(.easeInOut(duration: 0.25), value: vm.currentScreen)
    }

    private var splashScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        SalahLockBrandMark(size: 38)
                        Text("SalahAlarm")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(AppColors.slTextPrimary)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("YOUR NEXT SALAH CAN BE DIFFERENT")
                            .font(.caption.weight(.bold))
                            .foregroundColor(AppColors.slDeepGreen)

                        Text("Set an alarm you can't dismiss from bed.")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundColor(AppColors.slTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("SalahAlarm keeps the reminder active until you get up and scan your prayer mat.")
                            .font(.body)
                            .foregroundColor(AppColors.slTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 0) {
                        firstAlarmStep(
                            icon: "bell.badge.fill",
                            title: "Your prayer alarm rings",
                            detail: "A clear interruption at prayer time"
                        )
                        Divider().padding(.leading, 58)
                        firstAlarmStep(
                            icon: "figure.walk",
                            title: "You get up",
                            detail: "No dismissing it half-asleep"
                        )
                        Divider().padding(.leading, 58)
                        firstAlarmStep(
                            icon: "camera.viewfinder",
                            title: "Scan your prayer mat",
                            detail: "The alarm stops and your salah is logged"
                        )
                    }
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(AppColors.slGreen.opacity(0.07))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(AppColors.slGreen.opacity(0.18), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    SLPrimaryButton(title: "set up my first alarm") {
                        vm.advance()
                    }

                    Text("You can adjust these preferences after setup.")
                        .font(.footnote)
                        .foregroundColor(AppColors.slTextSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(Color.white)
            }
        }
    }

    private func firstAlarmStep(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.slGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text(L10n.text(detail))
                    .font(.caption)
                    .foregroundColor(AppColors.slTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private var featuresScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pray First.")
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(AppColors.slTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Then Unlock\nYour Apps.")
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(AppColors.slGreen)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Then unlock your apps.")

                        Text("A simple loop that turns prayer time into action.")
                            .font(.body)
                            .foregroundColor(AppColors.slTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {
                        mechanismStep(
                            number: 1,
                            icon: "bell.badge.fill",
                            title: "Prayer time arrives",
                            detail: "A persistent alarm interrupts the scroll."
                        )
                        mechanismStep(
                            number: 2,
                            icon: "app.badge.fill",
                            title: "Distractions pause",
                            detail: "The apps you choose stay blocked."
                        )
                        mechanismStep(
                            number: 3,
                            icon: "camera.viewfinder",
                            title: "Scan your prayer mat",
                            detail: "The alarm ends, apps unlock, and salah is logged."
                        )
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.slGreen)
                        Text("No complicated setup. Just one clear next step.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.slTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.slGreen.opacity(0.08)))
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 18)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                SLPrimaryButton(title: "personalize my plan") {
                    vm.advance()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(Color.white)
            }
        }
    }

    private func mechanismStep(number: Int, icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.slGreen.opacity(0.11))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppColors.slGreen)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.format("STEP %d", number))
                    .font(.caption2.weight(.bold))
                    .foregroundColor(AppColors.slGold)
                Text(L10n.text(title))
                    .font(.headline)
                    .foregroundColor(AppColors.slTextPrimary)
                Text(L10n.text(detail))
                    .font(.subheadline)
                    .foregroundColor(AppColors.slTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.slBorderDefault, lineWidth: 1))
    }

    private var nameScreen: some View {
        SAOnboardingContainer(vm: vm) {
            VStack(alignment: .leading, spacing: 18) {
                Text("first things first")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.slTextSecondary)
                Text("What Should We Call You?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                ZStack(alignment: .leading) {
                    if vm.profile.displayName.isEmpty {
                        Text("your name...")
                            .foregroundColor(AppColors.slTextPrimary)
                            .padding(.horizontal, 16)
                    }
                    TextField("", text: Binding(
                        get: { vm.profile.displayName },
                        set: { vm.setName($0) }
                    ))
                    .foregroundColor(AppColors.slTextPrimary)
                    .padding(.horizontal, 16)
                }
                .frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.slBorderDefault, lineWidth: 1))



                Spacer()

                SLPrimaryButton(title: "continue", isEnabled: !vm.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(24)
        }
        .dismissKeyboardOnTap()
    }

    private var prayerFrequencyScreen: some View {
        choiceScreen(
            title: "How Often Do You Currently Pray?",
            subtitle: "be honest — we're not judging.\nthis helps us build the right plan for you.",
            options: PrayerFrequency.allCases.filter { $0 != .unset }.map {
                ($0.displayLabel, nil, $0.rawValue)
            },
            selection: vm.profile.prayerFrequency.rawValue,
            onSelect: { raw in
                vm.setPrayerFrequency(PrayerFrequency(rawValue: raw) ?? .unset)
            }
        )
    }
    private var phoneUsageScreen: some View {
        choiceScreen(
            title: "About How Much Time Do You Spend on Your Phone Each Day?",
            subtitle: "A quick estimate is enough. This helps SalahAlarm create a realistic interruption plan.",
            options: PhoneUsageRange.allCases.filter { $0 != .unset }.map {
                ($0.displayLabel, nil, $0.rawValue)
            },
            selection: vm.profile.dailyPhoneUsageRange.rawValue,
            onSelect: { raw in
                vm.setPhoneUsage(PhoneUsageRange(rawValue: raw) ?? .unset)
            }
        )
    }



    private var alarmPrayerSelectionScreen: some View {
        SAOnboardingContainer(vm: vm) {
            ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Which Prayers Do You Want Alarms For?")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("choose the ones you miss most.\nwe'll only ring when you actually need it.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    presetPill("all five", isSelected: vm.profile.selectedAlarmPrayers.count == PrayerName.allCases.count) {
                        vm.setSelectedAlarmPrayers(PrayerName.allCases)
                    }
                    presetPill("just fajr", isSelected: vm.profile.selectedAlarmPrayers == [.fajr]) {
                        vm.setSelectedAlarmPrayers([.fajr])
                    }
                    presetPill("custom", isSelected: !vm.profile.selectedAlarmPrayers.isEmpty && vm.profile.selectedAlarmPrayers.count != 1 && vm.profile.selectedAlarmPrayers.count != PrayerName.allCases.count) {
                    }
                }

                VStack(spacing: 12) {
                    ForEach(PrayerName.allCases) { prayer in
                        SLOptionPill(
                            emoji: nil,
                            title: prayer.displayName,
                            // The Arabic name would repeat the title in Arabic-script languages.
                            subtitle: AppLanguage.current.isRightToLeft ? nil : prayer.arabicName,
                            isSelected: vm.profile.selectedAlarmPrayers.contains(prayer)
                        ) {
                            vm.toggleSelectedAlarmPrayer(prayer)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 18)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                pinnedFooter {
                    SLPrimaryButton(title: "continue", isEnabled: !vm.profile.selectedAlarmPrayers.isEmpty) {
                        vm.advance()
                    }
                }
            }
        }
    }

    /// Bottom action bar that stays visible while the content above it scrolls.
    private func pinnedFooter<Footer: View>(@ViewBuilder _ footer: () -> Footer) -> some View {
        VStack(spacing: 8) {
            footer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.white)
    }

    private var goalsScreen: some View {
        multiChoiceScreen(
            title: "What Does Consistency Look Like for You?",
            subtitle: "choose up to 3.\nwe'll build your habit plan around these.",
            options: UserGoal.allCases.map { ("\($0.emoji) \(L10n.text($0.displayLabel))", nil, $0.rawValue) },
            selected: Set(vm.profile.goals.map(\.rawValue)),
            continueEnabled: !vm.profile.goals.isEmpty
        ) { raw in
            if let goal = UserGoal(rawValue: raw) {
                vm.toggleGoal(goal)
            }
        }
    }

    private var screenTimeInsightScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Your Attention Can Make Room for Salah.")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(AppColors.slTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.format("You estimated %@ of phone time each day.", L10n.text(vm.profile.dailyPhoneUsageRange.displayLabel)))
                    .font(.body)
                    .foregroundColor(AppColors.slTextSecondary)

                VStack(spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("60+")
                            .font(.system(size: 58, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.slGreen)
                        Text("focused hours")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(AppColors.slTextPrimary)
                    }
                    .frame(maxWidth: .infinity)

                    Text("Reclaiming only 10 minutes a day creates more than 60 hours a year for prayer, Quran, and reflection.")
                        .font(.body)
                        .foregroundColor(AppColors.slTextSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        ForEach(PrayerName.allCases) { prayer in
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(AppColors.slGreen.opacity(0.12))
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        Image(systemName: "moon.stars.fill")
                                            .font(.caption)
                                            .foregroundColor(AppColors.slGreen)
                                    )
                                Text(L10n.text(prayer.displayName))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(AppColors.slTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 26).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(AppColors.slBorderDefault, lineWidth: 1))

                Text("The goal isn't more screen time control. It's an easier return to salah.")
                    .font(.headline)
                    .foregroundColor(AppColors.slTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                SLPrimaryButton(title: "build that rhythm") {
                    vm.advance()
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }

    private var commitmentScreen: some View {
        SAOnboardingContainer(vm: vm) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Picture 30 Days of Showing Up.")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(AppColors.slTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Choose a pace that feels sustainable. It can be changed anytime.")
                        .font(.body)
                        .foregroundColor(AppColors.slTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                        spacing: 8
                    ) {
                        ForEach(1...30, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(day <= 7 ? AppColors.slGreen : AppColors.slGreen.opacity(0.10))
                                .frame(height: 34)
                                .overlay(
                                    Text("\(day)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(day <= 7 ? .white : AppColors.slDeepGreen)
                                )
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.slBorderDefault, lineWidth: 1))

                    VStack(spacing: 10) {
                        commitmentOption(
                            title: "Strong structure",
                            subtitle: "Persistent alarms and strict app blocking",
                            level: .extremelyCommitted,
                            strictness: .strict
                        )
                        commitmentOption(
                            title: "Balanced support",
                            subtitle: "Consistent reminders with a practical routine",
                            level: .committed,
                            strictness: .moderate
                        )
                        commitmentOption(
                            title: "Gentle beginning",
                            subtitle: "Start small and strengthen the habit over time",
                            level: .startingJourney,
                            strictness: .relaxed
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 18)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                pinnedFooter {
                    SLPrimaryButton(
                        title: "create my plan",
                        isEnabled: vm.profile.commitmentLevel != .unset
                    ) {
                        vm.advance()
                    }
                }
            }
        }
    }

    private func commitmentOption(title: String, subtitle: String, level: CommitmentLevel, strictness: AlarmStrictness) -> some View {
        SLOptionPill(
            emoji: level.emoji,
            title: title,
            subtitle: subtitle,
            isSelected: vm.profile.commitmentLevel == level
        ) {
            vm.setCommitment(level)
            vm.setAlarmStrictness(strictness)
        }
    }

    private var loaderScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(spacing: 22) {
                Spacer()
                ProgressView()
                    .scaleEffect(1.8)
                    .tint(AppColors.slGreen)
                Text(L10n.text("We're Building\nYour Prayer Plan..."))
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 10) {
                    Text("✅  setting up alarms for your city")
                    Text("✅  calibrating your alarm intensity")
                    Text("✅  preparing your first-week target")
                }
                .font(.system(size: 16))
                .foregroundColor(AppColors.slTextSecondary)
                Spacer()
            }
            .padding(24)
            .task {
                guard vm.currentScreen == .screen9 else { return }
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                vm.advance()
            }
        }
    }

    private var planReadyScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Label("PERSONALIZED PLAN READY", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundColor(AppColors.slDeepGreen)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(AppColors.slGreen.opacity(0.11)))

                    Text("A Simpler Path Back to Every Salah.")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(AppColors.slTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("You can adjust these preferences after setup.")
                        .font(.body)
                        .foregroundColor(AppColors.slTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 0) {
                        if let firstAlarm = vm.firstAlarm {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "alarm.fill")
                                    .font(.headline)
                                    .foregroundColor(AppColors.slGreen)
                                    .frame(width: 34, height: 34)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.slGreen.opacity(0.10)))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(L10n.text("Your first alarm"))
                                        .font(.caption)
                                        .foregroundColor(AppColors.slTextSecondary)
                                    Text(L10n.format("%@ at %@", L10n.text(firstAlarm.prayer.displayName), firstAlarm.time.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(AppLanguage.current.locale))))
                                        .font(.headline)
                                        .foregroundColor(AppColors.slTextPrimary)
                                    Text(L10n.text("Calculated for your location. It keeps ringing until you reach your mat."))
                                        .font(.caption)
                                        .foregroundColor(AppColors.slTextSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                            Divider().padding(.leading, 58)
                        }
                        planSummaryRow(
                            icon: "bell.fill",
                            title: "Prayer coverage",
                            value: L10n.format("%d prayers", vm.profile.selectedAlarmPrayers.count),
                            detail: vm.profile.selectedAlarmPrayers.map { L10n.text($0.displayName) }.joined(separator: " · ")
                        )
                        Divider().padding(.leading, 58)
                        planSummaryRow(
                            icon: "shield.lefthalf.filled",
                            title: "Support level",
                            value: vm.profile.alarmStrictness.displayLabel,
                            detail: vm.profile.alarmStrictness.detailText
                        )
                        Divider().padding(.leading, 58)
                        planSummaryRow(
                            icon: "target",
                            title: "Primary goal",
                            value: vm.profile.goals.first?.displayLabel ?? "build prayer consistency",
                            detail: "Your reminders and progress will reinforce this goal."
                        )
                    }
                    .background(RoundedRectangle(cornerRadius: 24).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.slBorderDefault, lineWidth: 1))

                    HStack(spacing: 12) {
                        outcomePill(icon: "lock.fill", title: "Pause distractions")
                        outcomePill(icon: "camera.viewfinder", title: "Reach your mat")
                        outcomePill(icon: "flame.fill", title: "Build the streak")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 18)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                pinnedFooter {
                    SLPrimaryButton(title: "continue with my plan") {
                        vm.advance()
                    }
                }
            }
        }
    }

    private func planSummaryRow(icon: String, title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(AppColors.slGreen)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.slGreen.opacity(0.10)))

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text(title))
                    .font(.caption)
                    .foregroundColor(AppColors.slTextSecondary)
                Text(L10n.text(value))
                    .font(.headline)
                    .foregroundColor(AppColors.slTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.text(detail))
                    .font(.caption)
                    .foregroundColor(AppColors.slTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private func outcomePill(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(AppColors.slGreen)
            Text(L10n.text(title))
                .font(.caption2.weight(.semibold))
                .foregroundColor(AppColors.slTextPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 72)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.slGreen.opacity(0.08)))
    }

    private var notificationsScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Allow SalahAlarm to Reach You")
                        .font(.system(size: 28, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("without notifications, your alarms can't ring.\n\nwe'll send two notifications per prayer:\na heads-up reminder, then the alarm itself.")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.slTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 10) {
                        SLNotificationPreviewCard(title: "SalahAlarm", message: "Fajr is in 10 minutes. get ready.")
                        SLNotificationPreviewCard(title: "🔔 SalahAlarm", message: "it's time for Fajr. scan your mat to confirm.")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 18)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                pinnedFooter {
                    SLPrimaryButton(title: "allow") {
                        FunnelAnalytics.shared.onboardingAction(action: "permission_requested", screen: vm.currentScreen)
                        Task {
                            let granted = await NotificationManager.shared.requestAuthorization()
                            vm.setNotificationsPermission(granted)
                            if granted { vm.scheduleSelectedPrayerReminders() }
                            vm.advance()
                        }
                    }
                    SLSecondaryButton(title: "skip for now") {
                        vm.skipNotificationsPermission()
                        vm.advance()
                    }
                }
            }
        }
    }

    private var soundSetupScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Choose your alarm sound")
                        .font(.system(size: 28, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("pick something you won't sleep through.\nthis matters most for Fajr.\nyou can change it later in settings.")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.slTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 12) {
                        ForEach(AlarmSoundOption.onboardingOptions, id: \.rawValue) { option in
                            soundChoiceCard(option)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 18)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                pinnedFooter {
                    SLPrimaryButton(title: "continue") {
                        alarmAudioService.stop()
                        vm.advance()
                    }
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                do {
                    try alarmAudioService.saveCustomAudio(from: url)
                    vm.setAlarmSound(AlarmSoundOption.custom.rawValue)
                    alarmAudioService.playPreview(soundName: AlarmSoundOption.custom.rawValue)
                    FunnelAnalytics.shared.onboardingSoundPreviewed(sound: "custom")
                } catch {
                    print("Failed to save custom audio: \(error)")
                }
            case .failure(let error):
                print("Failed to import custom audio: \(error)")
            }
        }
    }

    private func soundChoiceCard(_ option: AlarmSoundOption) -> some View {
        let isSelected = vm.profile.alarmSoundName == option.rawValue

        return Button {
            if option == .custom {
                showFileImporter = true
            } else {
                vm.setAlarmSound(option.rawValue)
                alarmAudioService.playPreview(soundName: option.rawValue)
                FunnelAnalytics.shared.onboardingSoundPreviewed(sound: AlarmSoundOption.analyticsID(for: option.rawValue))
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(L10n.text(option.displayName))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.slTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if option != .custom {
                            Text("LOUD")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.saAlarmRed)
                                .clipShape(Capsule())
                        }
                    }
                    Text(L10n.text(option.description))
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? AppColors.slGreen : AppColors.slBorderDefault)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppColors.slGreen : AppColors.slBorderDefault, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var silentModeScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("One Thing Before Your Alarms Work")
                    .font(.system(size: 30, weight: .bold))
                Text("until we have full alarm access,\nyour phone needs to be ready to ring.\nthree quick things:")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)
                soundChecklist

                Spacer()
                SLPrimaryButton(title: "got it →") {
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
        }
    }

    private var locationScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Let Us Find Your Prayer Times")
                    .font(.system(size: 28, weight: .bold))
                Text("we use your location for two things only.\nnothing else. nothing stored.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)
                VStack(spacing: 14) {
                    SLFeatureRow(icon: "sun.max.fill", title: "Accurate Local Prayer Times", description: "your city's schedule, calculated automatically")
                    SLFeatureRow(icon: "location.north.fill", title: "Qibla Direction", description: "so you face the right way when you pray")
                }
                Text("we never track you outside the app.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.slTextSecondary)
                Spacer()
                SLPrimaryButton(title: vm.isLoading ? "loading..." : "Continue", isEnabled: !vm.isLoading, isLoading: vm.isLoading) {
                    requestLocationPermission()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
        }
        .onDisappear {
            alarmAudioService.stop()
        }
    }

    private var cameraPermissionScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Allow Camera for Mat Scanning")
                    .font(.system(size: 28, weight: .bold))
                Text("your camera is used for one thing:\nscanning your prayer mat to dismiss the alarm.\n\nno photos are stored.\nnothing leaves your phone.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)
                RoundedRectangle(cornerRadius: 22)
                    .fill(AppColors.slCream)
                    .frame(height: 220)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundColor(AppColors.slGreen)
                            Text("scan your prayer mat before the alarm stops.")
                                .font(.system(size: 16, weight: .semibold))
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                    }
                Spacer()
                SLPrimaryButton(title: "Continue") {
                    requestCameraPermission()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
        }
    }

    private var matSetupScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Set Up Your Prayer Mat")
                    .font(.system(size: 28, weight: .bold))
                Text("when your alarm rings, you'll reach for your mat.\nthat reaching is already the first step of the prayer.\nmake it easy to do.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)

                VStack(spacing: 14) {
                    SLFeatureRow(icon: "bed.double.fill", title: "Keep It Near Where You Sleep", description: "so you can reach it quickly for Fajr and late-night prayers")
                    SLFeatureRow(icon: "camera.viewfinder", title: "Give It Enough Light", description: "the scan works best when the mat is clearly visible")
                    SLFeatureRow(icon: "checkmark.seal.fill", title: "This Is Your Dismiss Step", description: "the alarm stops only after you complete the mat check")
                }

                Spacer()

                SLPrimaryButton(title: "my mat is ready →") {
                    vm.setMatSetupCompleted(true)
                    vm.advance()
                }
                SLSecondaryButton(title: "set this up later") {
                    vm.setMatSetupCompleted(false)
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
        }
    }

    private var lockIntroScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("pray first.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text("then unlock your apps.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(AppColors.slGold)
                Text("SalahLock is the strongest habit tool we have.\nyour most distracting apps stay locked\nuntil you confirm you've prayed.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)

                VStack(spacing: 0) {
                    SLTimelineRow(number: 1, title: "prayer time arrives", isLast: false)
                    SLTimelineRow(number: 2, title: "your chosen apps get locked", isLast: false)
                    SLTimelineRow(number: 3, title: "you pray", isLast: false)
                    SLTimelineRow(number: 4, title: "confirm prayer to unlock", isLast: true)
                }

                Text("SalahAlarm uses Apple's Screen Time to temporarily block selected apps. nothing is tracked, nothing leaves your phone.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.slTextSecondary)

                Spacer()

                SLPrimaryButton(title: "set up my lock") {
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(24)
        }
    }

    private var lockSetupScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Which Apps Distract You the Most?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text("choose the apps you want locked until you've prayed. you can change them anytime in the Lock tab.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)

                VStack(spacing: 14) {
                    SLFeatureRow(icon: "lock.fill", title: lockManager.hasSelection ? "Apps Selected" : "No Apps Selected Yet", description: lockManager.hasSelection ? lockManager.selectionSummary : "tap below to connect Screen Time and pick apps")
                    SLFeatureRow(icon: "sunrise.fill", title: "Starts With Fajr", description: "apps lock at Fajr and unlock once you confirm you prayed")
                }

                Spacer()

                SLPrimaryButton(title: lockManager.hasSelection ? "continue with these apps" : "choose apps to lock") {
                    if lockManager.hasSelection {
                        vm.profile.screenTimePermissionState = .granted
                        vm.saveLocal()
                        vm.advance()
                    } else {
                        Task {
                            let authorized = await lockManager.requestAuthorization()
                            if authorized {
                                showOnboardingAppPicker = true
                            } else {
                                vm.profile.screenTimePermissionState = .denied
                                vm.saveLocal()
                                vm.advance()
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(24)
        }
        .familyActivityPicker(isPresented: $showOnboardingAppPicker, selection: $lockManager.selection)
        .onChange(of: showOnboardingAppPicker) { isPresented in
            if !isPresented && lockManager.hasSelection {
                vm.profile.screenTimePermissionState = .granted
                vm.saveLocal()
            }
        }
    }

    private var salahIsPowerfulScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("everything you need\nto protect your salah")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text("one focused system for prayer, consistency, and returning to what matters")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.slTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    onboardingPoint(icon: "bell", text: "persistent prayer alarms")
                    onboardingPoint(icon: "viewfinder", text: "mat scan + distraction blocking")
                    onboardingPoint(icon: "flame", text: "streaks, qibla, Quran + widgets")
                }

                HStack(spacing: 8) {
                    Circle().fill(AppColors.slGreen).frame(width: 8, height: 8)
                    Circle().fill(AppColors.slBorderDefault).frame(width: 8, height: 8)
                    Circle().fill(AppColors.slBorderDefault).frame(width: 8, height: 8)
                }
                .padding(.top, 4)

                Spacer(minLength: 2)

                SLPrimaryButton(title: "continue") {
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }

    private var futureHabitScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("help us keep\nbuilding SalahAlarm")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text("your subscription keeps these tools maintained, improving, and available every day")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.slTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    onboardingPoint(icon: "lock.shield", text: "full access to every premium feature")
                    onboardingPoint(icon: "sparkles", text: "new features and continued improvements")
                    onboardingPoint(icon: "heart", text: "support the team behind SalahAlarm")
                }

                HStack(spacing: 10) {
                    Image(systemName: "heart")
                        .foregroundColor(AppColors.slGreen)
                    Text("we’d love your support in helping SalahAlarm grow")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Circle().fill(AppColors.slBorderDefault).frame(width: 8, height: 8)
                    Circle().fill(AppColors.slGreen).frame(width: 8, height: 8)
                    Circle().fill(AppColors.slBorderDefault).frame(width: 8, height: 8)
                }
                .padding(.top, 2)

                Spacer(minLength: 2)

                SLPrimaryButton(title: "continue") {
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }

    private func onboardingPoint(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.slGreen.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(AppColors.slGreen)
            }
            Text(L10n.text(text))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.slTextPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 68)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private var socialProofScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Muslims Are Building a\nStronger Salah Habit.")
                        .font(.system(size: 30, weight: .bold))

                    VStack(spacing: 8) {
                        Text("★★★★★")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColors.slGold)
                        Text("4.8 on the App Store")
                            .font(.system(size: 19, weight: .bold))
                        Text("Real accountability for the prayers that matter most.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.slTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.slCream)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    ratingBenefitCard(icon: "alarm.waves.left.and.right.fill", title: "Wake up for Fajr", body: "Your alarm keeps you accountable until you're at your prayer mat.")
                    ratingBenefitCard(icon: "checkmark.seal.fill", title: "Stay consistent", body: "Prayer tracking and streaks turn good intentions into a daily habit.")

                    SLPrimaryButton(title: "see my plan") {
                        vm.advance()
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .padding(24)
            }
        }
    }

    private var freeToTryScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false, background: AnyView(
            LinearGradient(colors: [AppColors.slGradientTop, AppColors.slDeepGreen], startPoint: .top, endPoint: .bottom)
        )) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    floatingValueCard(icon: "🕊", title: "spiritual consistency", body: "five prayers. every day.")
                    Text("VS")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                    floatingValueCard(icon: "🌙", title: "clear subscription choices", body: "shown before you subscribe")
                }

                (
                    Text("Make Room for ").foregroundColor(.white)
                    + Text("Salah").foregroundColor(AppColors.slGold)
                    + Text(" in Your Day.").foregroundColor(.white)
                )
                .font(.system(size: 30, weight: .bold))

                Text("we built SalahAlarm to solve the problem\nevery Muslim knows but rarely talks about —\n\nthe alarm that gets silenced.\nthe prayer that gets delayed.\nthe habit that never quite forms.\n\na few minutes of real discipline each day\nchanges everything.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.94))

                Text("simple pricing policy")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.slGold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())

                Text("we depend on support from Muslims like you\nto keep building tools that put prayer first.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                SLPrimaryButton(title: "sounds good →", backgroundColor: .white, foregroundColor: AppColors.slGreen) {
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(24)
        }
    }

    private var trialReminderScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(spacing: 18) {
                Spacer().frame(height: 48)
                Image(systemName: "bell.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(AppColors.slGreen)
                    .frame(maxWidth: .infinity)

                Text("Clear Billing.\nNo Surprises.")
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Review the price and billing period before subscribing.\n\nIf a free trial is available to you, its length and annual renewal price will be shown before you confirm.\n\nSubscriptions renew automatically unless cancelled in App Store subscription settings.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)
                    .multilineTextAlignment(.center)

                Spacer()

                SLPrimaryButton(title: "continue →") {
                    vm.advance()
                }

                Text("cancel anytime.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.slTextSecondary)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
    }

    private var whyWeNeedSupportScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Spacer().frame(height: 24)

                Text("Why We Need Your Support")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)

                Text("SalahAlarm is the most complete prayer app for Muslims.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.slGreen)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 14) {
                    SLFeatureRow(icon: "clock.fill", title: "Accurate Prayer Times", description: "automatically calculated for your location, updated daily")
                    SLFeatureRow(icon: "book.fill", title: "Complete Quran", description: "entire Quran with translations and detailed verse info")
                    SLFeatureRow(icon: "location.fill", title: "Qibla Compass", description: "precise direction to Makkah using your device sensors")
                    SLFeatureRow(icon: "lock.fill", title: "SalahLock", description: "keep distracting apps locked until you've prayed")
                    SLFeatureRow(icon: "quote.bubble.fill", title: "Daily Duas", description: "99+ rotating duas from Quran and Hadith")
                }
                .padding(.top, 12)

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Building and maintaining this app takes real resources.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                    Text("Your subscription supports our small team, keeps servers running, and funds new features to help you stay accountable to your salah.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.slCream))

                SLPrimaryButton(title: "see our plans") {
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
    }

    private var soundChecklist: some View {
        VStack(spacing: 14) {
            SLFeatureRow(icon: "bell.slash.fill", title: "Turn Off Silent Mode", description: "silent phones bury alarms — especially at Fajr")
            SLFeatureRow(icon: "moon.zzz.fill", title: "Allow Notifications Through Focus", description: "do not disturb should never suppress prayer alarms")
            SLFeatureRow(icon: "speaker.wave.3.fill", title: "Raise Your Ringer Volume", description: "especially the night before, when Fajr is coming")
        }
    }

    private func messageScreen(eyebrow: String, title: String, body: String, cta: String) -> some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 20) {
                Spacer(minLength: 8)

                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(AppColors.slGreen.opacity(0.09))
                        .frame(height: 260)

                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white)
                            .frame(width: 154, height: 214)
                            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)

                        VStack(spacing: 18) {
                            Image(systemName: "bell.and.waves.left.and.right.fill")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundColor(AppColors.slGreen)
                            Text("Prayer time")
                                .font(.headline)
                                .foregroundColor(AppColors.slTextPrimary)
                            Label("Apps paused", systemImage: "lock.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.slDeepGreen)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(AppColors.slGreen.opacity(0.10)))
                        }
                    }
                }

                Text(L10n.text(eyebrow))
                    .font(.caption.weight(.bold))
                    .foregroundColor(AppColors.slGold)

                Text(L10n.text(title))
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(AppColors.slTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text(body))
                    .font(.body)
                    .foregroundColor(AppColors.slTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                SLPrimaryButton(title: cta) {
                    vm.advance()
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
    }

    private func choiceScreen(
        title: String,
        subtitle: String?,
        options: [(String, String?, String)],
        selection: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        SAOnboardingContainer(vm: vm) {
            VStack(alignment: .leading, spacing: 22) {
                Text(L10n.text(title))
                    .font(.system(size: 30, weight: .bold))
                if let subtitle {
                    Text(L10n.text(subtitle))
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                }
                VStack(spacing: 12) {
                    ForEach(options, id: \.2) { option in
                        SLOptionPill(
                            emoji: nil,
                            title: option.0,
                            subtitle: option.1,
                            isSelected: selection == option.2
                        ) {
                            onSelect(option.2)
                        }
                    }
                }
                Spacer()
                SLPrimaryButton(title: "continue", isEnabled: !selection.isEmpty && selection != "unset") {
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
        }
    }

    private func multiChoiceScreen(
        title: String,
        subtitle: String?,
        options: [(String, String?, String)],
        selected: Set<String>,
        continueEnabled: Bool,
        onToggle: @escaping (String) -> Void
    ) -> some View {
        SAOnboardingContainer(vm: vm) {
            ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text(L10n.text(title))
                    .font(.system(size: 30, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(L10n.text(subtitle))
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 12) {
                    ForEach(options, id: \.2) { option in
                        SLOptionPill(
                            emoji: nil,
                            title: option.0,
                            subtitle: option.1,
                            isSelected: selected.contains(option.2)
                        ) {
                            onToggle(option.2)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 18)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                pinnedFooter {
                    SLPrimaryButton(title: "continue", isEnabled: continueEnabled) {
                        vm.advance()
                    }
                }
            }
        }
    }

    private func presetPill(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(L10n.text(title))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : AppColors.slGreen)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? AppColors.slGreen : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.slGreen.opacity(isSelected ? 0 : 0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func requestLocationPermission() {
        FunnelAnalytics.shared.onboardingAction(action: "permission_requested", screen: vm.currentScreen)
        Task {
            vm.isLoading = true
            LocationManager.shared.requestWhenInUseAuthorization()
            var status = LocationManager.shared.authorizationStatus
            if status == .notDetermined {
                for _ in 0..<40 {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    status = LocationManager.shared.authorizationStatus
                    if status != .notDetermined { break }
                }
            }
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                vm.setLocationPermission(.granted)
                await vm.loadLocationAndPrayerTimes()
            } else {
                vm.setLocationPermission(.denied)
            }
            vm.isLoading = false
            vm.advance()
        }
    }

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                vm.setCameraPermission(granted ? .granted : .denied)
                vm.advance()
            }
        }
    }

    private func ratingBenefitCard(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.slGreen)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.text(title))
                    .font(.system(size: 16, weight: .bold))
                Text(L10n.text(body))
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.slTextSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func offerPill(_ title: String) -> some View {
        Text(L10n.text(title))
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func miniBenefitCard(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(icon)
                .font(.system(size: 20))
            Text(L10n.text(title))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.slTextPrimary)
            Text(L10n.text(body))
                .font(.system(size: 11))
                .foregroundColor(AppColors.slTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func floatingValueCard(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(icon)
                .font(.system(size: 22))
            Text(L10n.text(title))
                .font(.system(size: 13, weight: .semibold))
            Text(L10n.text(body))
                .font(.system(size: 12))
                .foregroundColor(AppColors.slTextSecondary)
        }
        .foregroundColor(AppColors.slTextPrimary)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var formattedConsistencyDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: vm.derivedPlan.targetConsistencyDate)
    }

    private var progressChartPoints: [ProgressChartPoint] {
        [
            ProgressChartPoint(week: "week 1", value: 28),
            ProgressChartPoint(week: "week 2", value: 58),
            ProgressChartPoint(week: "week 3", value: 90)
        ]
    }
}

private struct ProgressChartPoint: Identifiable {
    let id = UUID()
    let week: String
    let value: Double
}

private struct SAOnboardingContainer<Content: View>: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    var showBack: Bool = true
    var background: AnyView = AnyView(Color.white)
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 0) {
                SLProgressBar(progress: OnboardingRouter.progress(for: vm.currentScreen))
                HStack {
                    if showBack && !OnboardingRouter.noBackScreens.contains(vm.currentScreen) {
                        Button(action: vm.back) {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.slTextPrimary)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(L10n.text("Back"))
                    } else {
                        Color.clear.frame(width: 18, height: 18)
                    }
                    Spacer()
                    LanguagePickerButton()
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}
