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

struct SalahAlarmOnboardingView: View {
    @StateObject private var vm = OnboardingFlowViewModel()
    @ObservedObject private var authService = FirebaseAuthService.shared
    @State private var showFileImporter = false
    private let alarmAudioService = AlarmAudioService.shared

    var body: some View {
        ZStack {
            AppColors.slBackground.ignoresSafeArea()

            switch vm.currentScreen {
            case .screen0:
                SLScreen0SignUp(vm: vm)
            case .screen1:
                splashScreen
            case .screen2:
                messageScreen(
                    eyebrow: "",
                    title: "How Many Prayers Passed You By This Week?",
                    body: "not because you stopped caring.\n\nthe day gets busy.\nyour phone is always there.\nand before you know it,\nanother salah slips past.\n\nyou're not alone.\nand it doesn't have to stay this way.",
                    cta: "continue"
                )
            case .screen3:
                featuresScreen
            case .screen4:
                nameScreen
            case .screen5:
                prayerFrequencyScreen
            case .screen6:
                alarmPrayerSelectionScreen
            case .screen7A:
                goalsScreen
            case .screen7B:
                alarmDemoScreen
            case .screen8:
                commitmentScreen
            case .screen9:
                loaderScreen
            case .screen10:
                planReadyScreen
            case .screen10A:
                reviewRequestScreen
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
            if let savedScreen = vm.loadSavedProgress() {
                let allowed: Set<OnboardingScreenID> = [
                    .screen0, .screen1, .screen2, .screen3, .screen4, .screen5, .screen6,
                    .screen7A, .screen7B, .screen8, .screen9, .screen10, .screen11,
                    .screen12, .screen13, .screen14, .screen15, .screen16, .screen17,
                    .screen17A, .screen17B, .screen17C, .screen17D, .screen17E, .screen18
                ]
                let resolvedScreen = allowed.contains(savedScreen) ? savedScreen : .screen1
                if resolvedScreen == .screen0 && !authService.isAuthenticated {
                    vm.currentScreen = .screen1
                } else if authService.isAuthenticated && resolvedScreen == .screen17 {
                    // If they are on screen17 (signup) but already authenticated, they should move to the next step.
                    // We advance them to 17A to start the 3-step payment onboarding.
                    vm.currentScreen = .screen17A
                } else {
                    vm.currentScreen = resolvedScreen
                }
            } else {
                vm.currentScreen = .screen1
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.currentScreen)
    }

    private var splashScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false, background: AnyView(
            LinearGradient(colors: [AppColors.slGradientTop, AppColors.slDeepGreen], startPoint: .top, endPoint: .bottom)
        )) {
            VStack(spacing: 20) {
                Spacer()
                SalahLockBrandMark(size: 126)
                Text("Assalamu Alaikum")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("السَّلامُ عَلَيْكُم")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                Spacer()
                Text("tap to begin ->")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .onTapGesture { vm.advance() }
        }
    }

    private var featuresScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("SalahAlarm Helps You")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text("Show Up for Every Prayer")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.slGold)
                (
                    Text("it's simple. an alarm rings.\nit doesn't stop until you ")
                    + Text("scan your prayer mat").foregroundColor(AppColors.slGreen)
                    + Text(".\nthis is how the habit forms.")
                )
                .font(.system(size: 15))
                .foregroundColor(AppColors.slTextSecondary)

                VStack(spacing: 14) {
                    SLFeatureRow(icon: "bell.fill", title: "Prayer Alarms That Don't Quit", description: "rings until you take action — no silencing, no scrolling")
                    SLFeatureRow(icon: "camera.fill", title: "Mat Scan to Dismiss", description: "physically reaching your mat is half the prayer already done")
                    SLFeatureRow(icon: "flame.fill", title: "Streak and Prayer History", description: "watch your consistency grow, one prayer at a time")
                    SLFeatureRow(icon: "book.fill", title: "Full Quran", description: "read and reflect between prayers")
                    SLFeatureRow(icon: "location.north.fill", title: "Qibla Directions", description: "accurate compass to find the qibla")
                }

                Spacer()

                SLPrimaryButton(title: "get started") {
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(24)
        }
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

    private var alarmPrayerSelectionScreen: some View {
        SAOnboardingContainer(vm: vm) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Which Prayers Do You Want Alarms For?")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text("choose the ones you miss most.\nwe'll only ring when you actually need it.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)

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
                            subtitle: prayer.arabicName,
                            isSelected: vm.profile.selectedAlarmPrayers.contains(prayer)
                        ) {
                            vm.toggleSelectedAlarmPrayer(prayer)
                        }
                    }
                }

                Spacer()

                SLPrimaryButton(title: "continue", isEnabled: !vm.profile.selectedAlarmPrayers.isEmpty) {
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
        }
    }

    private var goalsScreen: some View {
        multiChoiceScreen(
            title: "What Does Consistency Look Like for You?",
            subtitle: "choose up to 3.\nwe'll build your habit plan around these.",
            options: UserGoal.allCases.map { ("\($0.emoji) \($0.displayLabel)", nil, $0.rawValue) },
            selected: Set(vm.profile.goals.map(\.rawValue)),
            continueEnabled: !vm.profile.goals.isEmpty
        ) { raw in
            if let goal = UserGoal(rawValue: raw) {
                vm.toggleGoal(goal)
            }
        }
    }

    private var alarmDemoScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(spacing: 22) {
                Text("How It Works")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)

                SAAlarmPulseView(color: AppColors.saAlarmRed)
                    .frame(height: 180)

                VStack(spacing: 0) {
                    SLTimelineRow(number: 1, title: "prayer time arrives", isLast: false)
                    SLTimelineRow(number: 2, title: "your alarm rings — and keeps ringing", isLast: false)
                    SLTimelineRow(number: 3, title: "you scan your prayer mat to dismiss it", isLast: false)
                    SLTimelineRow(number: 4, title: "the prayer is logged. the streak stays alive.", isLast: true)
                }

                Text("no silencing. no scrolling first.\njust you, your mat, and Allah.")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.slTextSecondary)
                    .multilineTextAlignment(.center)

                Spacer()

                SLPrimaryButton(title: "sounds good →") {
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(24)
        }
    }

    private var commitmentScreen: some View {
        choiceScreen(
            title: "How Serious Are You About This?",
            subtitle: "your alarm strictness is set based on this.\nyou can always adjust it in settings.",
            options: CommitmentLevel.allCases.filter { $0 != .unset }.map {
                ("\($0.emoji) \($0.displayLabel)", $0.description, $0.rawValue)
            },
            selection: vm.profile.commitmentLevel.rawValue,
            onSelect: { raw in
                vm.setCommitment(CommitmentLevel(rawValue: raw) ?? .unset)
            }
        )
    }

    private var loaderScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(spacing: 22) {
                Spacer()
                ProgressView()
                    .scaleEffect(1.8)
                    .tint(AppColors.slGreen)
                Text("\(vm.profile.displayName.isEmpty ? "" : "\(vm.profile.displayName), ")We're Building\nYour Prayer Plan...")
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
            VStack(alignment: .leading, spacing: 18) {
                Text("\(vm.profile.displayName.isEmpty ? "friend" : vm.profile.displayName), your plan is ready.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.slGold)
                Text("Here's What We Set Up for You.")
                    .font(.system(size: 28, weight: .bold))
                SLStatCard(label: "alarms selected", value: "\(vm.profile.selectedAlarmPrayers.count) prayers", sublabel: vm.profile.selectedAlarmPrayers.map(\.displayName).joined(separator: ", "))
                SLStatCard(label: "alarm mode", value: vm.profile.alarmStrictness.displayLabel, sublabel: vm.profile.alarmStrictness.detailText)
                SLSummaryCard(sectionLabel: "your goal", content: vm.profile.goals.prefix(3).map(\.displayLabel))
                Text("we see what you're working toward, \(vm.profile.displayName.isEmpty ? "friend" : vm.profile.displayName).\nlet's build this habit together —\none prayer at a time.")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.slTextSecondary)
                Spacer()
                SLPrimaryButton(title: "continue") {
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(24)
        }
    }

    private var reviewRequestScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("One Quick Favor?")
                    .font(.system(size: 28, weight: .bold))
                Text("we're a small team working hard to help Muslims stay consistent with their salah.\n\nplease take a second to leave us a 5-star review. it means the world to us and helps others find the app!")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)
                Spacer()
                SLPrimaryButton(title: "leave a 5-star review") {
                    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                    
                    // Automatically advance after a brief moment so they don't get stuck
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        vm.advance()
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
        }
    }

    private var notificationsScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Allow SalahAlarm to Reach You")
                    .font(.system(size: 28, weight: .bold))
                Text("without notifications, your alarms can't ring.\n\nwe'll send two notifications per prayer:\na heads-up reminder, then the alarm itself.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)
                VStack(spacing: 10) {
                    SLNotificationPreviewCard(title: "SalahAlarm", message: "Fajr is in 10 minutes. get ready.")
                    SLNotificationPreviewCard(title: "🔔 SalahAlarm", message: "it's time for Fajr. scan your mat to confirm.")
                }
                Spacer()
                SLPrimaryButton(title: "allow") {
                    Task {
                        let granted = await NotificationManager.shared.requestAuthorization()
                        vm.setNotificationsPermission(granted)
                        vm.advance()
                    }
                }
                SLSecondaryButton(title: "skip for now") {
                    vm.setNotificationsPermission(false)
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(24)
        }
    }

    private var soundSetupScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Choose your alarm sound")
                    .font(.system(size: 28, weight: .bold))
                Text("pick something you won't sleep through.\nthis matters most for Fajr.\nyou can change it later in settings.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)
                VStack(spacing: 12) {
                    ForEach(AlarmSoundOption.allCases, id: \.rawValue) { option in
                        soundChoiceCard(option)
                    }
                }
                Spacer()
                SLPrimaryButton(title: "continue") {
                    alarmAudioService.stop()
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                do {
                    try alarmAudioService.saveCustomAudio(from: url)
                    vm.setAlarmSound(AlarmSoundOption.custom.rawValue)
                    alarmAudioService.playPreview(soundName: AlarmSoundOption.custom.rawValue)
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
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(option.rawValue)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.slTextPrimary)
                        Text("LOUD")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.saAlarmRed)
                            .clipShape(Capsule())
                    }
                    Text(option.description)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                        .multilineTextAlignment(.leading)
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
                SLPrimaryButton(title: vm.isLoading ? "loading..." : "allow location", isEnabled: !vm.isLoading, isLoading: vm.isLoading) {
                    requestLocationPermission()
                }
                SLSecondaryButton(title: "skip for now") {
                    vm.setLocationPermission(.skipped)
                    vm.advance()
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
                SLPrimaryButton(title: "allow camera") {
                    requestCameraPermission()
                }
                SLSecondaryButton(title: "skip for now") {
                    vm.setCameraPermission(.skipped)
                    vm.advance()
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

    private var salahIsPowerfulScreen: some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("some days, even\nprayer feels difficult")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text("not because you don’t care\nlife just gets distracting")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.slTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    onboardingPoint(icon: "bell", text: "alarms that help you get up")
                    onboardingPoint(icon: "calendar", text: "reminders before every prayer")
                    onboardingPoint(icon: "chart.bar", text: "tools for consistency")
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
                    Text("SalahAlarm was\nbuilt for this")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text("to make returning to prayer feel easier,\ncalmer, and more consistent")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.slTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    onboardingPoint(icon: "viewfinder", text: "mat-scan dismissal")
                    onboardingPoint(icon: "flame", text: "streak tracking")
                    onboardingPoint(icon: "location.north.circle", text: "qibla compass + widgets")
                }

                HStack(spacing: 10) {
                    Image(systemName: "heart")
                        .foregroundColor(AppColors.slGreen)
                    Text("simple support for your daily salah")
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
            Text(text)
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
                    Text("SalahAlarm Was Built\nfor Muslims Like You.")
                        .font(.system(size: 30, weight: .bold))

                    Text("🏆  #1 prayer alarm app   ⭐⭐⭐⭐⭐   trusted by Muslims worldwide")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.slGold)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.slCream)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    reviewCard(title: "I FINALLY PRAY FAJR.", body: "I've tried everything — alarms, apps, asking my family. This is the only thing that actually works. The alarm doesn't stop until I'm on my mat. That's the whole game.")
                    reviewCard(title: "47 DAYS. ALL FIVE PRAYERS.", body: "I never thought I could do this. The streak kept me honest. The mat scan made it real.")

                    SLPrimaryButton(title: "join SalahAlarm 🤲") {
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
                    floatingValueCard(icon: "☕", title: "the cost of one coffee", body: "a month")
                }

                (
                    Text("SalahAlarm Is ").foregroundColor(.white)
                    + Text("Free").foregroundColor(AppColors.slGold)
                    + Text(" for You to Try.").foregroundColor(.white)
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

                Text("your selected plan starts right away.\n\nno surprise charges.\nno fine print tricks.\ncancel any time in Settings.")
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

    private var soundChecklist: some View {
        VStack(spacing: 14) {
            SLFeatureRow(icon: "bell.slash.fill", title: "Turn Off Silent Mode", description: "silent phones bury alarms — especially at Fajr")
            SLFeatureRow(icon: "moon.zzz.fill", title: "Allow Notifications Through Focus", description: "do not disturb should never suppress prayer alarms")
            SLFeatureRow(icon: "speaker.wave.3.fill", title: "Raise Your Ringer Volume", description: "especially the night before, when Fajr is coming")
        }
    }

    private func messageScreen(eyebrow: String, title: String, body: String, cta: String) -> some View {
        SAOnboardingContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Spacer().frame(height: 40)
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Rectangle()
                    .fill(AppColors.slBorderDefault)
                    .frame(width: 86, height: 1)
                    .padding(.vertical, 8)
                Text(body)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)
                Spacer(minLength: 0)
                Button(action: vm.advance) {
                    HStack(spacing: 6) {
                        Spacer()
                        Text("tap to continue")
                            .font(.system(size: 15, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(AppColors.slGold)
                }
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
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
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                if let subtitle {
                    Text(subtitle)
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
            VStack(alignment: .leading, spacing: 22) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
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
                Spacer()
                SLPrimaryButton(title: "continue", isEnabled: continueEnabled) {
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
        }
    }

    private func presetPill(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
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

    private func reviewCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("⭐⭐⭐⭐⭐")
            Text(title)
                .font(.system(size: 16, weight: .bold))
            Text(body)
                .font(.system(size: 14))
                .foregroundColor(AppColors.slTextSecondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func offerPill(_ title: String) -> some View {
        Text(title)
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
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.slTextPrimary)
            Text(body)
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
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(body)
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
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.slTextPrimary)
                        }
                    } else {
                        Color.clear.frame(width: 18, height: 18)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}
