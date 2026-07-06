//
//  SalahLockOnboardingScreens.swift
//  Ramadan Pro
//

import SwiftUI
import FirebaseAnalytics
import CoreLocation

private struct SLScreenContainer<Content: View>: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    var background: AnyView = AnyView(Color.white)
    var showBack: Bool = true
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 0) {
                SLProgressBar(progress: vm.progressValue)
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            Analytics.logEvent("onboarding_screen_viewed", parameters: ["screen_id": vm.currentScreen.rawValue as NSString])
        }
    }
}

struct SLScreen0SignUp: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    @State private var authMode: AuthMode = .signup
    @State private var showEmailForm = false
    @State private var emailName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isTransitioningAfterAuth = false

    private enum AuthMode {
        case signup
        case signin
    }

    private var postAuthScreen: OnboardingScreenID {
        authMode == .signup ? .screen17A : .screen18
    }

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack(spacing: 0) {
                Spacer()
                // Brand center section
                VStack(spacing: 0) {
                    SalahLockBrandMark(size: 88)
                    Text("SalahAlarm")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.slGreen)
                        .padding(.top, 12)
                    Spacer().frame(height: 32)
                    Text("Never Miss a Prayer Again.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Text("join thousands of Muslims building\na consistent salah habit.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.slTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                Spacer()
                // Auth buttons
                VStack(spacing: 12) {
                    SLAuthButton(provider: .google) {
                        Task {
                            let success = await vm.authViewModel.signInWithGoogle()
                            if success {
                                await handleAuthSuccess(provider: "google")
                            }
                        }
                    }
                    SLAuthButton(provider: .apple) {
                        Task {
                            let success = await vm.authViewModel.signInWithApple()
                            if success {
                                await handleAuthSuccess(provider: "apple")
                            }
                        }
                    }
                    SLAuthButton(provider: .email) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            authMode = .signup
                            showEmailForm = true
                            vm.authViewModel.clearError()
                        }
                    }
                }
                .padding(.horizontal, 24)

                if showEmailForm {
                    VStack(spacing: 12) {
                        if authMode == .signup {
                            textField(title: "Name", text: $emailName, secure: false, keyboard: .default)
                        }
                        textField(title: "Email", text: $email, secure: false, keyboard: .emailAddress)
                        textField(title: "Password", text: $password, secure: true, keyboard: .default)
                        if authMode == .signup {
                            textField(title: "Confirm Password", text: $confirmPassword, secure: true, keyboard: .default)
                        }
                        SLPrimaryButton(
                            title: authMode == .signup ? "create account" : "sign in",
                            isEnabled: authMode == .signup ? canSignUp : canSignIn,
                            isLoading: vm.authViewModel.isLoading || isTransitioningAfterAuth
                        ) {
                            Task {
                                vm.authViewModel.name = emailName
                                vm.authViewModel.email = email
                                vm.authViewModel.password = password
                                vm.authViewModel.confirmPassword = confirmPassword
                                isTransitioningAfterAuth = true
                                let modeLabel = authMode == .signup ? "signup" : "signin"
                                print("🔐 [ONBOARDING] Email auth submitted (\(modeLabel))")
                                let success = authMode == .signup ? await vm.authViewModel.signUp() : await vm.authViewModel.signIn()
                                if success {
                                    await handleAuthSuccess(provider: authMode == .signup ? "email_signup" : "email_signin")
                                } else {
                                    isTransitioningAfterAuth = false
                                    print("⚠️ [ONBOARDING] Email auth failed, staying on screen0")
                                }
                            }
                        }
                        Button(authMode == .signup ? "already have an account? sign in" : "need an account? sign up") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                authMode = authMode == .signup ? .signin : .signup
                                vm.authViewModel.clearError()
                            }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.slGreen)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                }
                Spacer().frame(height: 16)
                HStack {
                    Rectangle().fill(AppColors.slBorderDefault).frame(height: 1)
                    Text("already have an account?")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.slTextSecondary)
                        .fixedSize()
                    Rectangle().fill(AppColors.slBorderDefault).frame(height: 1)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                Button("sign in") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showEmailForm = true
                        authMode = .signin
                    }
                }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.slGreen)
                    .underline()
                if vm.authViewModel.showError, let message = vm.authViewModel.errorMessage {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                }
                if isTransitioningAfterAuth {
                    Text("Signing you in...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.slGreen)
                        .padding(.top, 10)
                }
                Spacer().frame(height: 24)
            }
        }
        .loadingOverlay(
            isLoading: vm.authViewModel.isLoading || isTransitioningAfterAuth,
            message: isTransitioningAfterAuth ? "Redirecting to your plan..." : "Creating account..."
        )
        .onAppear {
            authMode = .signup
            showEmailForm = false
            isTransitioningAfterAuth = false
            vm.authViewModel.clearFields()
            emailName = vm.authViewModel.name
            email = vm.authViewModel.email
            password = vm.authViewModel.password
            confirmPassword = vm.authViewModel.confirmPassword
        }
    }

    @MainActor
    private func handleAuthSuccess(provider: String) async {
        Analytics.logEvent("onboarding_auth_success", parameters: ["provider": provider])
        isTransitioningAfterAuth = true
        print("✅ [ONBOARDING] Auth success for \(provider), moving to \(postAuthScreen.rawValue)")
        vm.mergeProfileAfterAuth()
        try? await Task.sleep(nanoseconds: 500_000_000)
        vm.skipTo(postAuthScreen)
    }


    private var canSignIn: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".") && password.count >= 6
    }

    private var canSignUp: Bool {
        !emailName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && canSignIn && confirmPassword == password
    }

    @ViewBuilder
    private func textField(title: String, text: Binding<String>, secure: Bool, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.slTextPrimary)
            Group {
                if secure {
                    SecureField("", text: text)
                        .foregroundColor(.black)
                        .tint(.black)
                } else {
                    TextField("", text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundColor(.black)
                        .tint(.black)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.slBorderDefault, lineWidth: 1))
        }
    }
}

struct SLTapMessageScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    let background: LinearGradient
    let title: String
    let titleColor: Color
    let subtitle: String
    let subtitleColor: Color
    let bodyLines: [String]
    let footer: String
    let footerColor: Color
    let iconScale: CGFloat

    var body: some View {
        SLScreenContainer(vm: vm, background: AnyView(background), showBack: false) {
            VStack {
                Spacer()
                SalahLockBrandMark(size: iconScale)
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(titleColor)
                    .padding(.top, 20)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 22))
                        .foregroundColor(subtitleColor)
                        .padding(.top, 8)
                }
                ForEach(bodyLines, id: \.self) { line in
                    Text(line)
                        .foregroundColor(titleColor)
                }
                Spacer()
                Text(footer)
                    .font(.system(size: 14))
                    .foregroundColor(footerColor)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .onTapGesture { vm.advance() }
        }
    }
}

struct SLProblemScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading) {
                Spacer().frame(height: 40)
                Group {
                    Text("ever feel like your phone gets more attention\nthan ")
                    + Text("Allah").foregroundColor(AppColors.slGold)
                    + Text("?")
                }
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.slTextPrimary)
                Spacer().frame(height: 40)
                VStack(alignment: .leading, spacing: 6) {
                    Text("you're not alone.")
                    Text("distractions are everywhere,")
                    Text("quietly pulling you away")
                    Text("from the peace you're looking for.")
                }
                .font(.system(size: 16))
                .foregroundColor(AppColors.slTextSecondary)
                Spacer()
                Text("tap to continue →")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.slGreen)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .onTapGesture { vm.advance() }
            .background(alignment: .trailing) {
                Image(systemName: "building.columns")
                    .font(.system(size: 180))
                    .foregroundColor(AppColors.slGreen.opacity(0.05))
                    .offset(x: 55, y: 20)
            }
        }
    }
}

struct SLSolutionScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Spacer().frame(height: 20)
                Text("SalahAlarm helps you")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text("protect your prayer time")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppColors.slGold)
                (
                    Text("it's simple. set your alarm.\n")
                    + Text("pray").foregroundColor(AppColors.slGreen).fontWeight(.bold)
                    + Text(" after your reminder keeps you accountable.")
                )
                .font(.system(size: 15))
                .foregroundColor(AppColors.slTextSecondary)
                Rectangle()
                    .fill(AppColors.slGold.opacity(0.4))
                    .frame(height: 1)
                VStack(spacing: 14) {
                    SLFeatureRow(icon: "bell.fill", title: "prayer alarms that keep ringing", description: "alarm-first reminders help you get up and pray on time")
                    SLFeatureRow(icon: "flame.fill", title: "prayer streak tracker", description: "build momentum with a daily salah streak")
                    SLFeatureRow(icon: "building.columns.fill", title: "prayer times + home widget", description: "accurate reminders + a widget on your home screen")
                    SLFeatureRow(icon: "book.fill", title: "quran reader", description: "read and reflect between prayers")
                    SLFeatureRow(icon: "location.north.line.fill", title: "qibla compass", description: "face the right direction, every time")
                }
                Spacer()
                SLPrimaryButton(title: "get started") { vm.advance() }
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct SLNameScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    @State private var name: String = ""

    var body: some View {
        SLScreenContainer(vm: vm) {
            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 12)
                Text("first things first")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.slTextSecondary)
                Text("what should we call you?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Spacer()
                TextField("your name...", text: $name)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(AppColors.slBorderDefault, lineWidth: 1))
                Spacer()
                SLPrimaryButton(title: "continue", isEnabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    vm.setName(name)
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .onAppear { name = vm.profile.displayName }
        }
    }
}

enum SLSelectableItem {
    case text(String, String)
    case emoji(String, String, String)
    case emojiSubtitle(String, String, String, String)

    var id: String {
        switch self {
        case .text(_, let id), .emoji(_, _, let id), .emojiSubtitle(_, _, _, let id): return id
        }
    }
}

struct SLSingleChoiceScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    let title: String
    let label: String?
    let options: [SLSelectableItem]
    let selection: String
    var continueTitle: String = "continue"
    let onSelect: (String) -> Void

    @State private var selected: String = ""

    init(vm: OnboardingFlowViewModel, title: String, label: String?, options: [SLSelectableItem], selection: String, continueTitle: String = "continue", onSelect: @escaping (String) -> Void) {
        self.vm = vm
        self.title = title
        self.label = label
        self.options = options
        self.selection = selection
        self.continueTitle = continueTitle
        self.onSelect = onSelect
    }

    var body: some View {
        SLScreenContainer(vm: vm) {
            VStack(alignment: .leading, spacing: 16) {
                if let label {
                    Text(label)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.slTextSecondary)
                }
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                VStack(spacing: 12) {
                    ForEach(options, id: \.id) { option in
                        optionView(option)
                    }
                }
                Spacer()
                SLPrimaryButton(title: continueTitle, isEnabled: !selected.isEmpty) {
                    onSelect(selected)
                    if vm.currentScreen != .screen7A {
                        vm.advance()
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .onAppear { selected = selection == "unset" ? "" : selection }
        }
    }

    @ViewBuilder
    private func optionView(_ option: SLSelectableItem) -> some View {
        switch option {
        case .text(let title, let id):
            SLOptionPill(emoji: nil, title: title, subtitle: nil, isSelected: selected == id) {
                selected = id
            }
        case .emoji(let emoji, let title, let id):
            SLOptionPill(emoji: emoji, title: title, subtitle: nil, isSelected: selected == id) {
                selected = id
            }
        case .emojiSubtitle(let emoji, let title, let subtitle, let id):
            SLOptionPill(emoji: emoji, title: title, subtitle: subtitle, isSelected: selected == id) {
                selected = id
            }
        }
    }
}

struct SLMultiChoiceScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    let title: String
    let subtitle: String
    let items: [SLSelectableItem]
    let selected: Set<String>
    let maxSelected: Int?
    let continueEnabled: Bool
    let onToggle: (String) -> Void

    var body: some View {
        SLScreenContainer(vm: vm) {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.slTextSecondary)
                if let maxSelected {
                    Text("\(selected.count) / \(maxSelected)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.slGreen)
                }
                VStack(spacing: 12) {
                    ForEach(items, id: \.id) { option in
                        let isSelected = selected.contains(option.id)
                        let isDisabled = maxSelected != nil && !isSelected && selected.count >= maxSelected!
                        switch option {
                        case .text(let title, _):
                            SLOptionPill(emoji: nil, title: title, subtitle: nil, isSelected: isSelected, isDisabled: isDisabled) {
                                onToggle(option.id)
                            }
                        case .emoji(let emoji, let title, _):
                            SLOptionPill(emoji: emoji, title: title, subtitle: nil, isSelected: isSelected, isDisabled: isDisabled) {
                                onToggle(option.id)
                            }
                        case .emojiSubtitle(let emoji, let title, let subtitle, _):
                            SLOptionPill(emoji: emoji, title: title, subtitle: subtitle, isSelected: isSelected, isDisabled: isDisabled) {
                                onToggle(option.id)
                            }
                        }
                    }
                }
                Spacer()
                SLPrimaryButton(title: "continue", isEnabled: continueEnabled) { vm.advance() }
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
    }
}

struct SLPhoneImpactScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading) {
                Spacer().frame(height: 44)
                Text("\(vm.profile.displayName.isEmpty ? "this year" : "\(vm.profile.displayName), this year") you'll spend")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text("\(vm.derivedPlan.annualPhoneHours) hours")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(AppColors.slGold)
                    .padding(.vertical, 4)
                Text("on your phone.")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Spacer().frame(height: 28)
                (
                    Text("that's ")
                    + Text("\(vm.derivedPlan.annualPhoneDays) days").fontWeight(.bold).foregroundColor(AppColors.slGold)
                    + Text(".")
                )
                .font(.system(size: 18))
                (
                    Text("or ")
                    + Text("\(vm.derivedPlan.lifetimePhoneYears) years").fontWeight(.bold).foregroundColor(AppColors.slGold)
                    + Text(" over your lifetime.")
                )
                .font(.system(size: 18))
                Spacer()
                (
                    Text("how much of that time\nbrings you closer to ")
                    + Text("Allah").foregroundColor(AppColors.slGold)
                    + Text("?")
                )
                .font(.system(size: 16))
                .foregroundColor(AppColors.slTextSecondary)
                Spacer()
                Text("tap to continue →")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.slGreen)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .onTapGesture { vm.advance() }
        }
    }
}

struct SLEncouragementScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("thank you for your honesty, \(vm.profile.displayName.isEmpty ? "friend" : vm.profile.displayName).")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.slGold)
                (
                    Text("struggles like these are part\nof walking with ")
                    + Text("faith").foregroundColor(AppColors.slGold)
                    + Text(" in a\nbroken world.")
                )
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.slTextPrimary)
                (
                    Text("Allah").foregroundColor(AppColors.slGold)
                    + Text(" is Most Merciful.\nEvery step back to prayer matters.")
                )
                .font(.system(size: 16))
                .foregroundColor(AppColors.slTextPrimary)
                SLQuoteCard(
                    quote: "The most beloved deeds to Allah are those done consistently, even if they are small.",
                    attribution: "— Prophet Muhammad ﷺ"
                )
                Text("SalahAlarm is here to help you protect your prayer time and build consistency again.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)
                Spacer()
                Text("tap to continue →")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.slGreen)
                    .padding(.bottom, 24)
            }
            .padding(24)
            .contentShape(Rectangle())
            .onTapGesture { vm.advance() }
        }
    }
}

struct SLJourneySummaryScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("thanks, \(vm.profile.displayName.isEmpty ? "friend" : vm.profile.displayName).")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.slGold)
                Text("based on what you've shared,\nlet's look at your journey.")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                SLSummaryCard(sectionLabel: "where you want to go", content: [vm.profile.goals.first.map { "\($0.emoji) \($0.displayLabel)" } ?? "Build a consistent prayer habit"])
                SLSummaryCard(sectionLabel: "where you are now", content: [vm.profile.relationshipWithAllah == .unset ? "📈 it has its ups and downs" : "\(vm.profile.relationshipWithAllah.emoji) \(vm.profile.relationshipWithAllah.displayLabel)"])
                SLSummaryCard(sectionLabel: "what's standing in the way", content: Array(vm.profile.obstacles.prefix(3)).map { "\($0.emoji) \($0.displayLabel)" })
                Text("We see where you are and where you want to go. Together, we can build a simple plan to protect your prayer time.")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.slTextSecondary)
                Spacer()
                SLPrimaryButton(title: "continue") { vm.advance() }
                    .padding(.bottom, 24)
            }
            .padding(24)
        }
    }
}

struct SLSalahPowerScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, background: AnyView(AppColors.slGreen), showBack: false) {
            VStack(spacing: 24) {
                Text("Salah Is Powerful.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(AppColors.slGold)
                    .padding(.top, 20)
                SalahLockGraphCard()
                .frame(height: 260)
                Text("every time you show up for salah,\nsomething shifts.\n\nthe discipline builds.\nthe peace comes back.\nand your relationship with Allah deepens —\none prayer at a time.")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                Spacer()
                Button("learn how SalahAlarm gets you there →") { vm.advance() }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.slGold)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct SLHowItWorksScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm) {
            VStack(alignment: .leading, spacing: 18) {
                Text("pray first.\nthen unlock your apps.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                VStack(spacing: 0) {
                    SLTimelineRow(number: 1, title: "prayer time begins", isLast: false)
                    SLTimelineRow(number: 2, title: "your prayer alarm rings", isLast: false)
                    SLTimelineRow(number: 3, title: "you pray salah", isLast: false)
                    SLTimelineRow(number: 4, title: "mark it complete and build your streak", isLast: true)
                }
                Text("SalahAlarm uses focused prayer alarms, reminders, and streaks to keep your salah routine consistent.")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.slTextSecondary)
                Spacer()
                SLPrimaryButton(title: "sounds good →") { vm.advance() }
                    .padding(.bottom, 24)
            }
            .padding(24)
        }
    }
}

struct SLCenteredAffirmationScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack {
                Spacer()
                Text("🔥").font(.system(size: 80))
                Text("you're committed —\nand that matters.")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.slTextPrimary)
                    .padding(.top, 12)
                Text("Strong habits begin with intention.\nYour commitment to salah is the\nfirst step toward a consistent\nprayer routine.\n\nLet's build that habit together.")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.slTextSecondary)
                    .padding(.top, 18)
                Spacer()
                SLPrimaryButton(title: "done ✓") {
                    vm.finalizeDerivedPlan()
                    vm.advance()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

struct SLPlanLoaderScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    @State private var started = false

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack {
                Spacer().frame(height: 70)
                ZStack {
                    Circle()
                        .stroke(AppColors.slGreen.opacity(0.2), lineWidth: 12)
                        .frame(width: 160, height: 160)
                    Circle()
                        .trim(from: 0, to: vm.loaderProgress)
                        .stroke(AppColors.slGold, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 160, height: 160)
                    Text("\(Int(vm.loaderProgress * 100))%")
                        .font(.system(size: 32, weight: .bold))
                }
                Text("building your salah consistency plan...")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                    .padding(.top, 24)
                VStack(alignment: .leading, spacing: 14) {
                    Text("✅  Setting up prayer reminders for your city")
                    Text("✅  Preparing your SalahAlarm reminders")
                    Text("✅  Building your personal habit plan")
                }
                .font(.system(size: 16))
                .foregroundColor(AppColors.slTextSecondary)
                .padding(.top, 24)
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { _ in
                        Circle().fill(AppColors.slGreen.opacity(0.3)).frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
            .task {
                guard !started else { return }
                started = true
                vm.finalizeDerivedPlan()
                withAnimation(.linear(duration: 2.5)) {
                    vm.loaderProgress = 1
                }
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                vm.advance()
            }
        }
    }
}

struct SLPlanReadyScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.slGreen)
                Text("alright \(vm.profile.displayName.isEmpty ? "friend" : vm.profile.displayName), your\nsalah plan is ready.")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text("based on your answers, here's where you are:")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.slTextSecondary)
                SLStatCard(label: "current prayer habit", value: "0 / 7 days this week", sublabel: nil)
                SLStatCard(label: "weekly time in salah", value: "2.5 hours", sublabel: "estimated from 5x daily prayer")
                VStack(alignment: .leading, spacing: 10) {
                    Text("commitment level")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.slTextSecondary)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.slBorderDefault)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(colors: [Color.gray.opacity(0.5), AppColors.slGreen], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geometry.size.width * vm.derivedPlan.commitmentProgressPct)
                        }
                    }
                    .frame(height: 12)
                    Text("\(Int(vm.derivedPlan.commitmentProgressPct * 100))%")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                Text("💪 your strength")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.slGreen)
                Text(vm.derivedPlan.strengthStatement)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.slTextSecondary)
                Spacer()
                SLPrimaryButton(title: "continue") { vm.advance() }
                    .padding(.bottom, 24)
            }
            .padding(24)
        }
    }
}

struct SLFutureHabitScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(vm.profile.displayName.isEmpty ? "" : "\(vm.profile.displayName), ")you will have a consistent\nsalah habit by")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.slTextSecondary)
                        Text(dateFormatter.string(from: vm.derivedPlan.targetConsistencyDate))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppColors.slGold)
                        HStack(spacing: 12) {
                            miniCard(icon: "🕌", title: "all five prayers\non time, every day")
                            miniCard(icon: "🌅", title: "fajr — finally\nstart your mornings with Allah")
                            miniCard(icon: "🔥", title: "your streak\nmomentum that doesn't break")
                        }
                        Text("⏳ 1,825+ prayer moments this year.\nsmall daily habits build a life of salah.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.slGold)
                        Text("small daily habits build a life of salah.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.slTextSecondary)
                    }
                    .padding(16)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.slGold, lineWidth: 1))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("how SalahAlarm gets you there")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(AppColors.slTextPrimary)
                        SLFeatureRow(icon: "🔔", title: "an alarm that doesn't quit", description: "it rings until you scan your mat.\nno snoozing your way past salah.")
                        SLFeatureRow(icon: "🔥", title: "a system that builds the habit", description: "your streak grows every time you show up.\nmissing one prayer makes the next one matter more.")
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.slCream))
                    SLPrimaryButton(title: "begin my salah journey →") { vm.advance() }
                        .padding(.top, 10)
                }
                .padding(24)
            }
        }
    }

    private func miniCard(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Text(icon).font(.system(size: 22))
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.slTextPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
    }
}

struct SLNotificationsScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("allow SalahAlarm to\nsend you reminders")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text("We use notifications to remind you when prayer time begins in your city and when your next salah alarm is due.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)
                SLNotificationPreviewCard(title: "SalahAlarm", message: "🕌 it's time for salah. your alarm is ready.")
                Spacer()
                SLPrimaryButton(title: "allow") {
                    Task {
                        let granted = await NotificationManager.shared.requestAuthorization()
                        vm.setNotificationsPermission(granted)
                        Analytics.logEvent("onboarding_permission_result", parameters: ["permission": "notifications", "result": granted ? "granted" : "denied"])
                        vm.advance()
                    }
                }
                SLSecondaryButton(title: "skip for now") {
                    vm.profile.notificationsPermissionState = .skipped
                    vm.saveLocal()
                    Analytics.logEvent("onboarding_permission_result", parameters: ["permission": "notifications", "result": "skipped"])
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(24)
        }
    }
}

struct SLAppsScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    private let apps: [(String, String, Color)] = [
        ("instagram", "Instagram", .pink),
        ("tiktok", "TikTok", .black),
        ("youtube", "YouTube", .red),
        ("twitter", "X", .black),
        ("snapchat", "Snapchat", .yellow),
        ("reddit", "Reddit", .orange),
        ("whatsapp", "WhatsApp", .green)
    ]
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("which apps distract you the most?")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text("choose the apps you want locked during prayer time")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.slTextSecondary)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(apps, id: \.0) { app in
                            let selected = vm.profile.selectedDistractingApps.contains(app.0)
                            Button {
                                vm.toggleApp(app.0)
                            } label: {
                                VStack(spacing: 8) {
                                    ZStack(alignment: .topTrailing) {
                                        RoundedRectangle(cornerRadius: 18)
                                            .fill(app.2.opacity(0.16))
                                            .frame(height: 82)
                                            .overlay {
                                                Text(String(app.1.prefix(1)))
                                                    .font(.system(size: 28, weight: .bold))
                                                    .foregroundColor(app.2)
                                            }
                                        if selected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(AppColors.slGold)
                                                .padding(8)
                                        }
                                    }
                                    Text(app.1)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(AppColors.slTextPrimary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("This screen is deprecated in SalahAlarm and is skipped in the updated onboarding flow.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                    Spacer(minLength: 12)
                    SLPrimaryButton(title: "connect now") {
                        if !vm.profile.selectedDistractingApps.isEmpty {
                            vm.profile.screenTimePermissionState = .granted
                        }
                        vm.saveLocal()
                        Analytics.logEvent("onboarding_permission_result", parameters: ["permission": "screen_time", "result": vm.profile.selectedDistractingApps.isEmpty ? "skipped" : "selected"])
                        vm.advance()
                    }
                    SLSecondaryButton(title: "skip for now") {
                        vm.profile.screenTimePermissionState = .skipped
                        vm.saveLocal()
                        Analytics.logEvent("onboarding_permission_result", parameters: ["permission": "screen_time", "result": "skipped"])
                        vm.advance()
                    }
                    .padding(.bottom, 24)
                }
                .padding(24)
            }
        }
    }
}

struct SLLocationPermissionScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack(spacing: 20) {
                Spacer().frame(height: 30)
                Text("📍").font(.system(size: 72))
                Text("allow SalahAlarm to use\nyour location")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.slTextPrimary)
                Text("We use your location for two things:")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.slTextSecondary)
                VStack(spacing: 14) {
                    SLFeatureRow(icon: "🕌", title: "accurate prayer times for your city", description: "")
                    SLFeatureRow(icon: "🧭", title: "qibla direction so you face the right way", description: "")
                }
                Text("We never track you outside the app.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.slTextSecondary)
                Spacer()
                SLPrimaryButton(title: vm.isLoading ? "loading..." : "allow location", isEnabled: !vm.isLoading, isLoading: vm.isLoading) {
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
                        if status == .authorizedAlways || status == .authorizedWhenInUse {
                            vm.setLocationPermission(.granted)
                            Analytics.logEvent("onboarding_permission_result", parameters: ["permission": "location", "result": "granted"])
                            await vm.loadLocationAndPrayerTimes()
                        } else if status == .denied || status == .restricted {
                            vm.setLocationPermission(.denied)
                            Analytics.logEvent("onboarding_permission_result", parameters: ["permission": "location", "result": "denied"])
                        } else {
                            vm.isLoading = false
                            return
                        }
                        vm.isLoading = false
                        vm.advance()
                    }
                }
                SLSecondaryButton(title: "skip for now") {
                    vm.setLocationPermission(.skipped)
                    Analytics.logEvent("onboarding_permission_result", parameters: ["permission": "location", "result": "skipped"])
                    vm.advance()
                }
                .padding(.bottom, 24)
            }
            .padding(24)
        }
    }
}

struct SLQiblaPreviewScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    @StateObject private var compassManager = CompassManager()
    @State private var showFullQibla = false

    var body: some View {
        SLScreenContainer(vm: vm, background: AnyView(AppColors.slGreen), showBack: false) {
            VStack(spacing: 18) {
                Text("finding your qibla...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.slGold)
                    .padding(.top, 10)
                Text("face the right direction\nfor your salah")
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)

                ZStack {
                    Circle()
                        .stroke(AppColors.slGold.opacity(0.4), lineWidth: 2)
                        .frame(width: 220, height: 220)
                    ForEach(0..<12, id: \.self) { i in
                        Rectangle()
                            .fill(AppColors.slGold.opacity(0.7))
                            .frame(width: 2, height: i % 3 == 0 ? 14 : 8)
                            .offset(y: -102)
                            .rotationEffect(.degrees(Double(i) * 30))
                    }
                    Rectangle()
                        .fill(AppColors.slGold)
                        .frame(width: 4, height: 95)
                        .offset(y: -38)
                        .rotationEffect(.degrees(compassManager.qiblaBearing ?? 0))
                    Text("Qibla")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("\(Int(compassManager.qiblaBearing ?? 0))°")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.slGold)
                Text(distanceText)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                Text("point your phone flat,\nthen rotate slowly until the\nneedle aligns with north.\nface the direction shown.")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Today's Prayer Times")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppColors.slGreen)
                    ForEach(prayerRows(), id: \.0) { row in
                        HStack {
                            Text(row.0)
                            Spacer()
                            Text(row.1)
                            if row.2 {
                                Text("← next").foregroundColor(AppColors.slGold)
                            }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextPrimary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))

                Spacer()
                Button("open full qibla") {
                    showFullQibla = true
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                Button(action: { vm.advance() }) {
                    Text("ready to pray →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.slGreen)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            compassManager.startUpdates()
        }
        .onDisappear {
            compassManager.stopUpdates()
        }
        .sheet(isPresented: $showFullQibla) {
            NavigationStack {
                QiblaCompassView()
                    .environmentObject(NavigationCoordinator.shared)
                    .environmentObject(AppState.shared)
            }
        }
    }

    private func prayerRows() -> [(String, String, Bool)] {
        guard let schedule = vm.todaySchedule else {
            return [("Fajr", "—", false), ("Dhuhr", "—", false), ("Asr", "—", false), ("Maghrib", "—", false), ("Isha", "—", false)]
        }
        let prayers: [(String, Date)] = [("Fajr", schedule.fajr), ("Dhuhr", schedule.dhuhr), ("Asr", schedule.asr), ("Maghrib", schedule.maghrib), ("Isha", schedule.isha)]
        let next = prayers.first { $0.1 > Date() }?.0
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return prayers.map { ($0.0, formatter.string(from: $0.1), next == $0.0) }
    }

    private var distanceText: String {
        guard let distance = compassManager.distanceToMakkah else {
            return "enable location for qibla"
        }
        return "\(Int(distance / 1000)) km to the Kaaba 🕋"
    }
}

struct SLFirstPrayerScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    @State private var prayerVerse: Ayah?
    @State private var prayerVerseLabel: String = "Prayer Reflection"

    var body: some View {
        SLScreenContainer(vm: vm, background: AnyView(LinearGradient(colors: [AppColors.slGreen.opacity(0.92), AppColors.slGreen], startPoint: .top, endPoint: .bottom)), showBack: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("let's pray")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("tap 'i prayed 🤲' once your salah is complete")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                prayerCard(title: nil, body: "O Allah, guide me to remain consistent\nin my prayers.\nHelp me remember You throughout\nmy day and never delay my salah.\nStrengthen my discipline so that\nI always pray on time.\nAccept my prayers and keep my heart\nconnected to You.\nAmeen.")
                prayerCard(
                    title: prayerVerseLabel,
                    body: prayerVerse.map { "\($0.arabic)\n\n\($0.translation)" } ?? "Loading Arabic and English verse for your prayer..."
                )
                Spacer()
                Button(action: {
                    vm.confirmFirstPrayer()
                    vm.advance()
                }) {
                    Text("i prayed 🤲")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.slGreen)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                }
                .padding(.bottom, 24)
            }
            .padding(24)
            .task {
                await loadPrayerVerse()
            }
        }
    }

    private func prayerCard(title: String?, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.slGold)
            }
            Text(body)
                .font(.system(size: 15))
                .foregroundColor(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.14)))
    }

    private func loadPrayerVerse() async {
        let prayerType = relevantPrayerType()
        prayerVerseLabel = prayerType.displayName + " reflection"
        let reference = verseReference(for: prayerType)
        prayerVerse = try? await QuranAPIService.shared.fetchVerse(surahNumber: reference.0, ayahNumber: reference.1)
    }

    private func relevantPrayerType() -> PrayerType {
        guard let schedule = vm.todaySchedule else { return .fajr }
        let now = Date()
        let ordered: [(PrayerType, Date)] = [(.fajr, schedule.fajr), (.dhuhr, schedule.dhuhr), (.asr, schedule.asr), (.maghrib, schedule.maghrib), (.isha, schedule.isha)]
        if let next = ordered.first(where: { now < $0.1 }) {
            return next.0
        }
        return .fajr
    }

    private func verseReference(for prayer: PrayerType) -> (Int, Int) {
        switch prayer {
        case .fajr:
            return (17, 78)
        case .dhuhr:
            return (17, 78)
        case .asr:
            return (2, 238)
        case .maghrib:
            return (11, 114)
        case .isha:
            return (24, 58)
        case .imsak:
            return (17, 78)
        }
    }
}

struct SLAlhamdulillahScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack(spacing: 18) {
                Text("Alhamdulillah!")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(AppColors.slGold)
                Text("you completed your prayer 🤲")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)
                SLQuoteCard(quote: "\"O you who have believed, seek help through patience and prayer. Indeed, Allah is with the patient.\"", attribution: "— Quran 2:153")
                Text("Your prayers are recorded to help you build a consistent salah habit.")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.slTextSecondary)
                Spacer()
                SLPrimaryButton(title: "continue") { vm.advance() }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .padding(24)
        }
    }
}

struct SLSocialProofScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("SalahAlarm Was Built\nfor Muslims Like You.")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text("🏆 #1 prayer alarm app   ⭐⭐⭐⭐⭐   trusted by Muslims worldwide")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.slGold)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18).fill(AppColors.slCream))
                reviewCard(title: "I FINALLY PRAY FAJR.", body: "I've tried everything — alarms, apps, asking my family.\nThis is the only thing that actually works.\nThe alarm doesn't stop until I'm on my mat.\nThat's the whole game.")
                reviewCard(title: "47 DAYS. ALL FIVE PRAYERS.", body: "I never thought I could do this.\nThe streak kept me honest.\nThe mat scan made it real.")
                Spacer()
                SLPrimaryButton(title: "join SalahAlarm 🤲") { vm.advance() }
                    .padding(.bottom, 24)
            }
            .padding(24)
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
}

struct SLTrialOfferScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, background: AnyView(AppColors.slGreen), showBack: false) {
            VStack(spacing: 20) {
                Spacer().frame(height: 40)
                HStack(spacing: 24) {
                    VStack {
                        Image(systemName: "bird.fill")
                            .font(.system(size: 38))
                            .foregroundColor(.white)
                        Text("spiritual peace")
                            .font(.system(size: 13, weight: .medium))
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.14)))
                    }
                    Text("VS")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    VStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 38))
                            .foregroundColor(.white)
                        Text("one coffee a month")
                            .font(.system(size: 13, weight: .medium))
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.14)))
                    }
                }
                (
                    Text("SalahAlarm Is ").foregroundColor(.white)
                    + Text("Free").foregroundColor(AppColors.slGold)
                    + Text(" for You to Try.").foregroundColor(.white)
                )
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
                Text("we built SalahAlarm to solve the problem\nevery Muslim knows but rarely talks about —\n\nthe alarm that gets silenced.\nthe prayer that gets delayed.\nthe habit that never quite forms.\n\na few minutes of real discipline each day\nchanges everything.")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                Text("simple pricing policy")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.slGold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.slCream))
                Text("we depend on support from Muslims like you\nto keep building tools that put prayer first.")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { vm.advance() }) {
                    Text("sounds good →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.slGreen)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct SLReminderScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            VStack(spacing: 20) {
                Spacer().frame(height: 50)
                Text("🔔").font(.system(size: 80))
                Text("Clear Billing.\nNo Surprises.")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.slTextPrimary)
                Text("your selected plan starts right away.\n\nno surprise charges.\nno fine print tricks.\ncancel any time in Settings.")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.slTextSecondary)
                Spacer()
                SLPrimaryButton(title: "continue →") { vm.advance() }
                Text("cancel anytime.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.slTextSecondary)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct SLPaywallScreen: View {
    @ObservedObject var vm: OnboardingFlowViewModel
    @EnvironmentObject private var appState: AppState
    @StateObject private var subscriptionVM = SubscriptionViewModel()
    @State private var selectedPlan: SubscriptionPlanType = .yearly
    @State private var errorMessage: String?
    @State private var hasAttemptedLoad = false

    private var displayedPlans: [SubscriptionPlanDetails] {
        subscriptionVM.availablePlans.isEmpty ? fallbackPlans : subscriptionVM.availablePlans
    }

    private var selectedPlanDetails: SubscriptionPlanDetails {
        displayedPlans.first(where: { $0.type == selectedPlan }) ?? displayedPlans.first ?? fallbackPlans[0]
    }

    private var paywallTitle: String { "help us keep\nbuilding SalahAlarm" }

    private var ctaTitle: String {
        subscriptionVM.isProcessingPurchase ? "processing..." : "continue"
    }

    private var footerCopy: String { "cancel anytime" }

    private var fallbackPlans: [SubscriptionPlanDetails] {
        [
            SubscriptionPlanDetails(
                type: .weekly,
                price: 6.99,
                productId: "com.ramadanpro.weekly",
                billingPeriodLabel: "week",
                pricePerPeriodText: "$6.99 / week",
                trialLabel: nil,
                renewalDescription: "$6.99 / week. cancel anytime."
            ),
            SubscriptionPlanDetails(
                type: .yearly,
                price: 29.99,
                productId: "com.ramadanpro.yearly",
                billingPeriodLabel: "year",
                pricePerPeriodText: "$29.99 / year",
                trialLabel: nil,
                renewalDescription: "$29.99 / year. cancel anytime."
            )
        ]
    }

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            if !hasAttemptedLoad {
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView().scaleEffect(1.5).tint(AppColors.slGreen)
                    Text("loading deals...")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    Analytics.logEvent("onboarding_paywall_viewed", parameters: nil)
                    await subscriptionVM.loadAvailablePlans()
                    if let preferredPlan = subscriptionVM.availablePlans.first(where: \.isBestValue) ?? subscriptionVM.availablePlans.first {
                        selectedPlan = preferredPlan.type
                    }
                    hasAttemptedLoad = true
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(paywallTitle)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text("your subscription supports the app,\nfuture updates, and continued improvements")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.slTextSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    premiumFeaturesBlock
                    choosePlanHeader
                    HStack(spacing: 12) {
                        ForEach(displayedPlans) { plan in
                            planCard(
                                title: plan.type.displayName,
                                price: plan.priceString,
                                subtitle: "/ \(plan.billingPeriodLabel)",
                                badge: plan.type == .yearly ? "best value" : nil,
                                isSelected: selectedPlan == plan.type
                            ) {
                                selectedPlan = plan.type
                            }
                        }
                    }
                    SLPrimaryButton(title: ctaTitle, isEnabled: !subscriptionVM.isProcessingPurchase, isLoading: subscriptionVM.isProcessingPurchase) {
                        purchase()
                    }
                    Text(footerCopy)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.slTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    HStack(spacing: 16) {
                        Button("restore") {
                            restorePurchases()
                        }
                        Button("privacy") {
                            openExternalURL("https://ramadan-pro.lovable.app/privacy")
                        }
                        Button("terms") {
                            openExternalURL("https://ramadan-pro.lovable.app/terms")
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.slGreen)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
        }
    }

    private func purchase() {
        let plan = selectedPlanDetails
        Task {
            let success = await subscriptionVM.purchasePlan(plan)
            if success {
                Analytics.logEvent("onboarding_purchase_started", parameters: ["plan_type": selectedPlan.rawValue as NSString])
                vm.completeOnboarding()
                UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
                WidgetConfig.saveIsSubscribed(true)
                appState.onboardingComplete = true
                appState.shouldExitOnboarding = true
                print("🏠 SLPaywallScreen: Purchase successful → exiting onboarding")
            } else {
                errorMessage = subscriptionVM.errorMessage ?? "Purchase failed"
            }
        }
    }

    private func restorePurchases() {
        Task {
            let success = await subscriptionVM.restorePurchases()
            if success {
                vm.completeOnboarding()
                UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
                WidgetConfig.saveIsSubscribed(true)
                appState.onboardingComplete = true
                appState.shouldExitOnboarding = true
                print("🏠 SLPaywallScreen: Restore successful → exiting onboarding")
            } else {
                errorMessage = subscriptionVM.errorMessage ?? "Restore failed"
            }
        }
    }

    private func openExternalURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            errorMessage = "Link unavailable"
            return
        }
        UIApplication.shared.open(url)
    }

    private var premiumFeaturesBlock: some View {
        VStack(spacing: 0) {
            paywallFeatureRow(
                icon: "crown",
                title: "unlock all premium features",
                subtitle: "get full access to every tool in SalahAlarm"
            )
            Divider().padding(.leading, 64)
            paywallFeatureRow(
                icon: "leaf",
                title: "support future development",
                subtitle: "your support helps us build new features"
            )
            Divider().padding(.leading, 64)
            paywallFeatureRow(
                icon: "heart",
                title: "help us improve the experience",
                subtitle: "so we can keep making the app better for you"
            )
        }
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.white))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var choosePlanHeader: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(AppColors.slGreen.opacity(0.25))
                .frame(height: 1)
            Text("choose your plan")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.slGreen)
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.slGreen)
            Rectangle()
                .fill(AppColors.slGreen.opacity(0.25))
                .frame(height: 1)
        }
        .padding(.top, 4)
    }

    private func paywallFeatureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.slGreen.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColors.slGreen)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.slTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var monthlyValueText: String {
        guard let yearly = displayedPlans.first(where: { $0.type == .yearly }),
              yearly.price > 0 else { return "$4.17 / month" }
        return String(format: "$%.2f / month", yearly.price / 12.0)
    }

    private func timelineBlock(title: String, points: [String]) -> some View {
        EmptyView()
    }

    private func planCard(title: String, price: String, subtitle: String?, badge: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 10) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AppColors.slGreen))
                } else {
                    Color.clear.frame(height: 21)
                }

                ZStack {
                    Circle()
                        .fill(AppColors.slGreen.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.slGreen)
                }

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text(price)
                    .font(.system(size: 30, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .foregroundColor(AppColors.slTextPrimary)

                if let subtitle {
                    Text(subtitle.replacingOccurrences(of: " ", with: ""))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.slTextSecondary)
                }

                if title == "Yearly" {
                    Text(monthlyValueText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.slGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppColors.slGreen.opacity(0.10)))
                } else {
                    Color.clear.frame(height: 32)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 196)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(isSelected ? AppColors.slGreen : AppColors.slBorderDefault, lineWidth: isSelected ? 2 : 1))
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: isSelected ? 10 : 4, x: 0, y: isSelected ? 8 : 2)
        }
        .buttonStyle(.plain)
    }

    private func legacyPlanCard(title: String, price: String, subtitle: String?, badge: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.slGold)
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text(price)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.slTextPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.slGreen)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? AppColors.slGreen : AppColors.slBorderDefault, lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}
