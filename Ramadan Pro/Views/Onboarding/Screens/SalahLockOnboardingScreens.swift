//
//  SalahLockOnboardingScreens.swift
//  Ramadan Pro
//

import SwiftUI
import FirebaseAnalytics
import CoreLocation
import PostHog

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
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.slTextPrimary)
                                .frame(width: 44, height: 44)
                        }
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                    Spacer()
                    LanguagePickerButton()
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

/// Lightweight celebration used when the second-spin yearly offer is revealed.
private struct SLConfettiView: View {
    private let colors: [Color] = [AppColors.slGreen, AppColors.slGold, Color(hex: "#2E3A8C"), Color(hex: "#D84A5B")]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<52 {
                    let seed = Double(index)
                    let progress = (elapsed * (0.34 + seed.truncatingRemainder(dividingBy: 5) * 0.035) + seed * 0.071)
                        .truncatingRemainder(dividingBy: 1)
                    let x = size.width * (0.04 + (seed * 0.137).truncatingRemainder(dividingBy: 0.92))
                    let y = size.height * progress
                    let rotation = Angle.degrees(seed * 41 + progress * 540)
                    let rect = CGRect(x: x, y: y, width: 7, height: 12)

                    context.opacity = 1 - progress * 0.35
                    context.translateBy(x: rect.midX, y: rect.midY)
                    context.rotate(by: rotation)
                    context.fill(Path(CGRect(x: -3.5, y: -6, width: 7, height: 12)), with: .color(colors[index % colors.count]))
                    context.translateBy(x: -rect.midX, y: -rect.midY)
                }
            }
        }
        .frame(height: 220)
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
        .screen18
    }

    /// Set when the user already bought on the paywall and is here to save it to an account
    private var isSavingPurchase: Bool {
        AppState.shared.needsAccountAfterPurchase
            && (RevenueCatService.shared.subscriptionStatus.isActive
                || UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.isSubscribed))
    }

    var body: some View {
        SLScreenContainer(vm: vm, showBack: false) {
            // Small screens and long translations scroll instead of clipping.
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    signUpContent
                        .frame(minHeight: proxy.size.height)
                }
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
            FunnelAnalytics.shared.track(.signupStarted)
        }
    }

    private var signUpContent: some View {
            VStack(spacing: 0) {
                Spacer(minLength: 12)
                // Brand center section
                VStack(spacing: 0) {
                    SalahLockBrandMark(size: 88)
                    Text("SalahAlarm")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.slGreen)
                        .padding(.top, 12)
                    Spacer().frame(height: 32)
                    Text(L10n.text(isSavingPurchase ? "You're In. Save Your Subscription." : "A Simpler Path Back to Every Salah."))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                    Text(L10n.text(isSavingPurchase ? "Create your account so your subscription, streaks and alarms stay with you on any device." : "Your plan is ready. Save it to keep your routine with you."))
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.slTextSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 20)
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
                Button("continue without an account") {
                    FunnelAnalytics.shared.track(.signupSkipped)
                    vm.skipTo(.screen17A)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.slTextSecondary)
                .padding(.top, 16)
                if vm.authViewModel.showError, let message = vm.authViewModel.errorMessage {
                    Text(L10n.text(message))
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

    @MainActor
    private func handleAuthSuccess(provider: String) async {
        Analytics.logEvent("onboarding_auth_success", parameters: ["provider": provider])
        isTransitioningAfterAuth = true
        print("✅ [ONBOARDING] Auth success for \(provider), moving to \(postAuthScreen.rawValue)")
        vm.mergeProfileAfterAuth()
        if let userID = FirebaseAuthService.shared.currentUser?.userId { FunnelAnalytics.shared.identify(userID: userID) }
        FunnelAnalytics.shared.signupCompleted(method: provider)
        // Attach a purchase made before sign-up (or an existing account's subscription) to this user
        await RevenueCatService.shared.linkPurchasesToSignedInUser()
        let alreadySubscribed = isSavingPurchase || RevenueCatService.shared.subscriptionStatus.isActive
        AppState.shared.needsAccountAfterPurchase = false
        if alreadySubscribed {
            // RootRouterView shows the main app once the user is signed in and subscribed
            vm.completeOnboarding()
            return
        }
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
            Text(L10n.text(title))
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
                SLPrimaryButton(title: vm.isLoading ? "loading..." : "Continue", isEnabled: !vm.isLoading, isLoading: vm.isLoading) {
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
            VStack(alignment: .leading, spacing: 18) {
                Spacer().frame(height: 20)

                Text("Muslims Are Building a\nStronger Salah Habit.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)

                VStack(spacing: 8) {
                    Text("★★★★★")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.slGold)
                    Text("4.8 on the App Store")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text("Real accountability for the prayers that matter most.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 20).fill(AppColors.slCream))

                proofCard(
                    icon: "alarm.waves.left.and.right.fill",
                    title: "Wake up for Fajr",
                    body: "Your alarm keeps you accountable until you're at your prayer mat."
                )
                proofCard(
                    icon: "checkmark.seal.fill",
                    title: "Stay consistent",
                    body: "Prayer tracking and streaks turn good intentions into a daily habit."
                )
                Spacer()
                SLPrimaryButton(title: "see my plan") { vm.advance() }
                    .padding(.bottom, 24)
            }
            .padding(24)
        }
    }

    private func proofCard(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.slGreen)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text(body)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.slTextSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    Text("Make Room for ").foregroundColor(.white)
                    + Text("Salah").foregroundColor(AppColors.slGold)
                    + Text(" in Your Day.").foregroundColor(.white)
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
                Text("Review the price and billing period before subscribing.\n\nIf a free trial is available to you, its length and annual renewal price will be shown before you confirm.\n\nSubscriptions renew automatically unless cancelled in App Store subscription settings.")
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
    var onExit: (() -> Void)? = nil
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var subscriptionVM = SubscriptionViewModel()
    @ObservedObject private var trialService = RevenueCatService.shared
    @State private var selectedPlan: SubscriptionPlanType?
    @State private var errorMessage: String?
    @State private var hasAttemptedLoad = false
    @State private var hasTrackedPaywallImpression = false

    private let conversionPaywallID = "current_swiftui_paywall"

    @State private var showWinBackModal = false
    @State private var hasShownWinBackOfferForThisVisit = false
    @State private var paywallViewID = UUID().uuidString
    @State private var hasAttemptedPurchase = false
    @State private var lastCheckoutOutcome = "not_attempted"
    @State private var showExitFeedback = false
    @State private var hasSubmittedExitFeedback = false
    @State private var discountExitAction = "no_thanks"
    @State private var purchaseTaskRunning = false
    @State private var submittedExitReason = "not_provided"
    @State private var showTrialOffer = false
    @State private var isCheckingTrial = false
    @State private var hasCheckedTrialForThisVisit = false
    @State private var presentedTrialPlan: SubscriptionPlanDetails?
    @State private var feedbackOfferStage = "final_discount"

    private var currentOfferStage: String {
        if showExitFeedback { return feedbackOfferStage }
        return showTrialOffer || isCheckingTrial ? "final_trial" : (showWinBackModal ? "final_discount" : "main")
    }

    private func paywallContext(stage: String = "main") -> [String: Any] {
        ["paywall_id": conversionPaywallID,
         "paywall_view_id": paywallViewID,
         "paywall_placement": onExit == nil ? "post_onboarding" : "feature_gate",
         "offer_stage": stage,
         "final_offer_shown": hasShownWinBackOfferForThisVisit,
         "offer_product_id": stage == "final_trial" ? (presentedTrialPlan?.productId ?? "") : (stage == "final_discount" ? (discountedYearlyPlanDetails?.productId ?? "") : (selectedPlanDetails?.productId ?? "")),
         "had_purchase_attempt": hasAttemptedPurchase,
         "last_checkout_outcome": lastCheckoutOutcome]
    }

    private var displayedPlans: [SubscriptionPlanDetails] {
        subscriptionVM.availablePlans
    }

    /// Presents the live weekly plan, the regular yearly plan and, when the
    /// offering has one, the lifetime unlock. The monthly plan is intentionally not offered.
    private var firstStagePlans: [SubscriptionPlanDetails] {
        let plans = displayedPlans.filter { plan in
            plan.type == .weekly || plan.type == .lifetime || (plan.type == .yearly && !isDiscountedYearly(plan))
        }
        // Yearly first (selected by default), then weekly, then lifetime
        let order: [SubscriptionPlanType] = [.yearly, .weekly, .lifetime]
        return plans.sorted { first, second in
            (order.firstIndex(of: first.type) ?? Int.max) < (order.firstIndex(of: second.type) ?? Int.max)
        }
    }

    private func isDiscountedYearly(_ plan: SubscriptionPlanDetails) -> Bool {
        guard plan.type == .yearly else { return false }
        return plan.productId?.lowercased().contains("discount") == true
    }

    private var discountedYearlyPlanDetails: SubscriptionPlanDetails? {
        guard let regular = regularYearlyPlanDetails else { return nil }
        return displayedPlans.first {
            $0.productId == "yearlydiscounted" && $0.price > 0 && $0.price < regular.price
                && $0.currencyCode == regular.currencyCode
        }
    }

    private var regularYearlyPlanDetails: SubscriptionPlanDetails? {
        firstStagePlans.first(where: { $0.type == .yearly })
    }

    private func winBackSavingsPercent(for plan: SubscriptionPlanDetails) -> Int? {
        guard let regular = regularYearlyPlanDetails, regular.price > plan.price else { return nil }
        return Int(((regular.price - plan.price) / regular.price * 100).rounded())
    }


    private var selectedPlanDetails: SubscriptionPlanDetails? {
        guard let selectedPlan else { return nil }
        return firstStagePlans.first(where: { $0.type == selectedPlan })
    }

    private var paywallTitle: String { "help us keep\nbuilding SalahAlarm" }

    private var ctaTitle: String {
        subscriptionVM.isProcessingPurchase ? "processing..." : "continue"
    }

    private var footerCopy: String {
        selectedPlan == .lifetime ? "one-time payment · no subscription" : "cancel anytime"
    }

    private func trackPlanSelection(_ plan: SubscriptionPlanDetails, source: String) {
        var properties = paywallContext()
        properties["plan_id"] = plan.productId ?? ""
        properties["plan_name"] = plan.type.rawValue
        properties["billing_period"] = plan.type.rawValue
        properties["price_billed"] = plan.priceString
        properties["price_amount"] = plan.price
        properties["currency"] = plan.currencyCode ?? ""
        properties["selection_source"] = source
        if plan.type == .yearly {
            properties["price_monthly_equivalent"] = plan.formatAmount(plan.price / 12)
        }
        FunnelAnalytics.shared.track(.pricingPlanSelected, properties)
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
                    // A stalled App Store request must not leave the paywall loading forever.
                    // The retry state shows instead, and plans still appear if the request finishes.
                    Task {
                        try? await Task.sleep(nanoseconds: 12_000_000_000)
                        guard !hasAttemptedLoad else { return }
                        hasAttemptedLoad = true
                        trackPaywallImpressionIfNeeded()
                    }
                    await subscriptionVM.loadAvailablePlans()
                    selectedPlan = firstStagePlans.first?.type
                    if let selectedPlanDetails {
                        trackPlanSelection(selectedPlanDetails, source: "default_on_load")
                    }
                    hasAttemptedLoad = true
                    trackPaywallImpressionIfNeeded()
                }
            } else if firstStagePlans.isEmpty {
                unavailablePlansStage
            } else {
                ZStack {
                    ScrollView(showsIndicators: false) {
                        plansStage
                    }
                    .accessibilityHidden(showWinBackModal || showTrialOffer || isCheckingTrial)

                    if showWinBackModal {
                        winBackModalOverlay
                            .accessibilityHidden(showTrialOffer || isCheckingTrial)
                    }
                    if showTrialOffer || isCheckingTrial {
                        trialOfferOverlay
                    }
                }
            }
        }
        // This screen contains public offer copy/pricing only, never account fields.
        // All other screens retain the SDK's default masking.
        .postHogNoMask()
        .sheet(isPresented: $showExitFeedback, onDismiss: finishOfferExit) {
            exitFeedbackSheet
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .background else { return }
            var properties = paywallContext(stage: currentOfferStage)
            properties["checkout_in_progress"] = purchaseTaskRunning || subscriptionVM.isProcessingPurchase
            properties["reason_source"] = "not_inferred"
            // Backgrounding includes system authentication; it is not a decline.
            FunnelAnalytics.shared.track(.paywallBackgrounded, properties)
        }
    }

    // MARK: - Stage 1: weekly + yearly

    private var plansStage: some View {
        ScrollView(showsIndicators: false) {
            plansContent
        }
    }

    private var plansContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                closeButton {
                    guard !subscriptionVM.isProcessingPurchase else { return }
                    var context = paywallContext()
                    context["exit_action"] = "close_button"
                    FunnelAnalytics.shared.track(.paywallCloseTapped, context)
                    Analytics.logEvent("paywall_close_tapped", parameters: ["stage": "plans" as NSString])
                    if !hasShownWinBackOfferForThisVisit && discountedYearlyPlanDetails != nil {
                        hasShownWinBackOfferForThisVisit = true
                        var offer = paywallContext(stage: "final_discount")
                        offer["is_final_offer"] = true
                        offer["price_billed"] = discountedYearlyPlanDetails?.priceString ?? ""
                        offer["currency"] = discountedYearlyPlanDetails?.currencyCode ?? ""
                        offer["trigger"] = "main_paywall_close"
                        FunnelAnalytics.shared.track(.winBackModalShown, offer)
                        withAnimation { showWinBackModal = true }
                    } else {
                        if !hasShownWinBackOfferForThisVisit {
                            var properties = paywallContext(stage: "final_discount")
                            let loadedOffer = displayedPlans.first { $0.productId == "yearlydiscounted" }
                            properties["unavailable_reason"] = loadedOffer == nil ? "product_not_loaded" : "not_a_lower_price_in_same_currency"
                            FunnelAnalytics.shared.track(.winBackOfferUnavailable, properties)
                        }
                        exitWithoutPurchase()
                    }
                }
            }
            Text(L10n.text(paywallTitle))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.slTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("your subscription supports the app,\nfuture updates, and continued improvements")
                .font(.system(size: 13))
                .foregroundColor(AppColors.slTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            premiumFeaturesBlock
            choosePlanHeader

            VStack(spacing: 12) {
                // Yearly plan first, selected by default.
                if let yearly = firstStagePlans.first(where: { $0.type == .yearly }) {
                    planCard(
                        title: "Yearly plan",
                        priceLine1: L10n.format("%@/mo", yearly.formatAmount(yearly.price / 12)),
                        priceLine2: L10n.format("Billed %@ annually", yearly.priceString),
                        badge: "BEST VALUE",
                        isSelected: selectedPlan == .yearly
                    ) {
                        selectedPlan = .yearly
                        trackPlanSelection(yearly, source: "user")
                    }
                }

                // Weekly plan second
                if let weekly = firstStagePlans.first(where: { $0.type == .weekly }) {
                    planCard(
                        title: "Weekly",
                        priceLine1: L10n.format("%@/week", weekly.priceString),
                        priceLine2: L10n.format("Billed %@ weekly", weekly.priceString),
                        isSelected: selectedPlan == .weekly
                    ) {
                        selectedPlan = .weekly
                        trackPlanSelection(weekly, source: "user")
                    }
                }

                // Lifetime last, only when the offering includes it
                if let lifetime = firstStagePlans.first(where: { $0.type == .lifetime }) {
                    planCard(
                        title: "Lifetime",
                        priceLine1: "\(lifetime.priceString) once",
                        priceLine2: "Pay once, yours forever",
                        isSelected: selectedPlan == .lifetime
                    ) {
                        selectedPlan = .lifetime
                        trackPlanSelection(lifetime, source: "user")
                    }
                }
            }
            SLPrimaryButton(title: ctaTitle, isEnabled: !subscriptionVM.isProcessingPurchase && selectedPlanDetails != nil, isLoading: subscriptionVM.isProcessingPurchase) {
                if let selectedPlanDetails {
                    purchase(selectedPlanDetails)
                }
            }
            Text(L10n.text(footerCopy))
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
                Text(L10n.text(errorMessage))
                    .font(.system(size: 13))
                    .foregroundColor(subscriptionVM.lastPurchaseOutcome == .pending ? AppColors.slTextSecondary : .red)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var winBackModalOverlay: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if let plan = discountedYearlyPlanDetails {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        HStack {
                            Spacer()
                            closeButton {
                                declineWinBackOffer(action: "close_button")
                            }
                        }

                        VStack(spacing: 5) {
                            (
                                Text("Support ")
                                    .foregroundColor(AppColors.slTextPrimary)
                                + Text("SalahAlarm")
                                    .foregroundColor(AppColors.slDeepGreen)
                            )
                            .font(.system(size: 27, weight: .bold))

                            Text("Your subscription helps us keep improving the app\nand building more Islamic features you love. 💚")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.slTextSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(AppColors.slGreen)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock All Premium Features")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppColors.slTextPrimary)
                                    Text("Get full access to everything in SalahAlarm")
                                        .font(.system(size: 10))
                                        .foregroundColor(AppColors.slTextSecondary)
                                }
                                Spacer()
                            }

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)
                                ],
                                spacing: 10
                            ) {
                                winBackFeature(icon: "lock.fill", title: "SalahLock", subtitle: "Stay focused on your salah")
                                winBackFeature(icon: "clock.fill", title: "Accurate Times", subtitle: "Always on time")
                                winBackFeature(icon: "book.fill", title: "Quran & Duas", subtitle: "Read, listen & reflect")
                                winBackFeature(icon: "flame.fill", title: "Prayer Streaks", subtitle: "Build consistency")
                                winBackFeature(icon: "square.grid.2x2.fill", title: "Premium Widgets", subtitle: "Beautiful at a glance")
                                winBackFeature(icon: "location.north.fill", title: "Qibla Compass", subtitle: "Find the right direction")
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("LIMITED TIME OFFER", systemImage: "sun.max.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(AppColors.slGold)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(AppColors.slGold.opacity(0.12)))

                                    Text("Special Annual Offer")
                                        .font(.system(size: 21, weight: .bold))
                                        .foregroundColor(AppColors.slTextPrimary)

                                    Text("More value. Less cost. Strengthen your Deen daily.")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppColors.slTextSecondary)
                                }

                                Spacer()

                                if let savings = winBackSavingsPercent(for: plan) {
                                    Text("\(savings)%\nOFF")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 58, height: 58)
                                        .background(Circle().fill(AppColors.slGreen))
                                }
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 7) {
                                Text(L10n.format("%@/month", plan.formatAmount(plan.price / 12)))
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(AppColors.slTextPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)

                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(L10n.format("Billed %@ annually", plan.priceString))
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(AppColors.slTextPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)

                                    if let regular = regularYearlyPlanDetails {
                                        Text(regular.priceString)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(AppColors.slTextSecondary)
                                            .strikethrough()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            SLPrimaryButton(
                                title: subscriptionVM.isProcessingPurchase ? "processing..." : "Get Premium Annual Access",
                                isEnabled: !subscriptionVM.isProcessingPurchase,
                                isLoading: subscriptionVM.isProcessingPurchase
                            ) {
                                var properties = paywallContext(stage: "final_discount")
                                properties["plan_id"] = plan.productId ?? ""
                                properties["price_billed"] = plan.priceString
                                properties["currency"] = plan.currencyCode ?? ""
                                properties["is_final_offer"] = true
                                FunnelAnalytics.shared.track(.winBackOfferAccepted, properties)
                                showWinBackModal = false
                                purchase(plan)
                            }

                            HStack(spacing: 5) {
                                Image(systemName: "shield.checkered")
                                Text("Secure & private")
                                Text("•")
                                Text("Cancel anytime")
                            }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppColors.slTextSecondary)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(15)
                        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(AppColors.slGreen.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: AppColors.slGreen.opacity(0.08), radius: 10, x: 0, y: 5)

                        Button("No thanks") {
                            declineWinBackOffer()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.slTextSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 22)
                }
            }
        }
        .transition(.opacity)
    }

    private func winBackFeature(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.slGreen)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.slGreen.opacity(0.11)))

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text(title))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                    .lineLimit(1)
                Text(L10n.text(subtitle))
                    .font(.system(size: 8))
                    .foregroundColor(AppColors.slTextSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
    }

    private func declineWinBackOffer(action: String = "no_thanks") {
        guard !subscriptionVM.isProcessingPurchase else { return }
        discountExitAction = action
        var properties = paywallContext(stage: "final_discount")
        properties["exit_action"] = action
        properties["decline_type"] = "offer_declined"
        properties["decline_reason"] = "not_provided"
        properties["reason_source"] = "not_collected"
        properties["is_final_offer"] = true
        FunnelAnalytics.shared.track(.winBackOfferDeclined, properties)
        showWinBackModal = false
        errorMessage = nil
        presentTrialAfterDiscountDecline()
    }

    private var exitFeedbackSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What stopped you?").font(.title2.bold())
            Text("Optional—this helps us improve. You can skip.")
                .foregroundColor(.secondary)
            ForEach([
                ("price_too_high", "The price is too high"),
                ("not_ready", "I'm not ready to subscribe"),
                ("want_to_try_first", "I want to try the app first"),
                ("checkout_problem", "Checkout didn't work"),
                ("other", "Another reason")
            ], id: \.0) { reason, label in
                Button(L10n.text(label)) {
                    submitExitFeedback(reason)
                    showExitFeedback = false
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            Button("Skip") { showExitFeedback = false }
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .presentationDetents([.medium, .large])
        // Responses remain structured events; do not reveal survey choices in pixels.
        .postHogMask()
    }

    private func submitExitFeedback(_ reason: String) {
        guard !hasSubmittedExitFeedback else { return }
        hasSubmittedExitFeedback = true
        submittedExitReason = reason
        var properties = paywallContext(stage: feedbackOfferStage)
        properties["decline_reason"] = reason
        properties["reason_source"] = reason == "not_provided" ? "skipped" : "user_reported"
        properties["is_final_offer"] = true
        // A user-reported checkout problem is not a verified bank decline.
        FunnelAnalytics.shared.track(.paywallExitReasonSubmitted, properties)
    }

    private func finishOfferExit() {
        submitExitFeedback("not_provided")
        exitWithoutPurchase(stage: feedbackOfferStage, action: discountExitAction)
    }

    private func presentTrialAfterDiscountDecline() {
        guard !hasCheckedTrialForThisVisit else {
            showExitFeedback = true
            return
        }
        hasCheckedTrialForThisVisit = true
        isCheckingTrial = true
        Task { @MainActor in
            let plan = await trialService.refreshAnnualTrialEligibility()
            isCheckingTrial = false
            guard let plan else {
                var properties = paywallContext(stage: "final_trial")
                properties["unavailable_reason"] = trialService.annualTrialUnavailableReason
                FunnelAnalytics.shared.track(.trialOfferUnavailable, properties)
                showExitFeedback = true
                return
            }
            presentedTrialPlan = plan
            showTrialOffer = true
            var properties = trialContext(plan)
            properties["trigger"] = "discount_offer_declined"
            FunnelAnalytics.shared.track(.trialOfferShown, properties)
        }
    }

    private func trialContext(_ plan: SubscriptionPlanDetails) -> [String: Any] {
        var properties = paywallContext(stage: "final_trial")
        properties["trial_days"] = plan.introductoryTrialDays ?? 0
        properties["auto_renews"] = true
        properties["plan_id"] = plan.productId ?? ""
        properties["price_amount"] = plan.price
        properties["currency"] = plan.currencyCode ?? ""
        properties["price_billed"] = plan.priceString
        properties["price_monthly_equivalent"] = plan.formatAmount(plan.price / 12)
        return properties
    }

    private func declineTrialOffer() {
        guard !purchaseTaskRunning, !subscriptionVM.isProcessingPurchase else { return }
        if let plan = presentedTrialPlan {
            var properties = trialContext(plan)
            properties["decline_type"] = "offer_declined"
            properties["reason_source"] = "not_collected"
            FunnelAnalytics.shared.track(.trialOfferDeclined, properties)
        }
        discountExitAction = "trial_no_thanks"
        feedbackOfferStage = "final_trial"
        showTrialOffer = false
        errorMessage = nil
        showExitFeedback = true
    }

    private var trialOfferOverlay: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            if isCheckingTrial {
                VStack(spacing: 16) {
                    ProgressView().tint(AppColors.slGreen)
                    Text(L10n.text("Checking your free trial…")).font(.body)
                }
            } else if let plan = presentedTrialPlan {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Spacer()
                            Button(action: declineTrialOffer) {
                                Image(systemName: "xmark")
                                    .font(.body.bold())
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel(L10n.text("Decline free trial"))
                            .disabled(purchaseTaskRunning || subscriptionVM.isProcessingPurchase)
                        }
                        Image(systemName: "moon.stars.fill")
                            .font(.largeTitle)
                            .foregroundStyle(AppColors.slGreen)
                            .accessibilityHidden(true)
                        Text(L10n.text("Take the first step, on us."))
                            .font(.largeTitle.bold())
                        Text(L10n.text("Enjoy 7 days of SalahAlarm as you build a routine around salah. Start with one prayer, one day at a time."))
                            .font(.body)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.text("7 days free")).font(.title.bold())
                            Text(L10n.text("Then a yearly subscription"))
                                .font(.headline)
                            Text(L10n.format("%@ / month equivalent", plan.formatAmount(plan.price / 12)))
                                .font(.title2.bold())
                            Text(L10n.format("Billed %@ once a year after your trial.", plan.priceString))
                                .font(.body.weight(.semibold))
                            Text(L10n.text("Not a monthly plan. Renews automatically each year unless cancelled. Cancel in App Store subscription settings at least 24 hours before the trial ends to avoid being charged."))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(AppColors.slGreen.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.slGreen.opacity(0.6)))
                        Button {
                            guard !purchaseTaskRunning, !subscriptionVM.isProcessingPurchase else { return }
                            FunnelAnalytics.shared.track(.trialOfferAccepted, trialContext(plan))
                            purchase(plan)
                        } label: {
                            HStack {
                                Spacer()
                                if purchaseTaskRunning { ProgressView().tint(.white) }
                                Text(L10n.text(purchaseTaskRunning ? "Processing…" : "Start my 7-day free trial"))
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.vertical, 17)
                            .padding(.horizontal, 12)
                            .foregroundStyle(.white)
                            .background(AppColors.slGreen, in: RoundedRectangle(cornerRadius: 20))
                        }
                        .disabled(purchaseTaskRunning || subscriptionVM.isProcessingPurchase)
                        if let errorMessage {
                            Text(L10n.text(errorMessage)).font(.body).foregroundStyle(.secondary)
                        }
                        Button(L10n.text("No thanks"), action: declineTrialOffer)
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .disabled(purchaseTaskRunning || subscriptionVM.isProcessingPurchase)
                        HStack(spacing: 20) {
                            Button(L10n.text("Restore")) { restorePurchases() }
                            Button(L10n.text("Privacy")) { openExternalURL("https://ramadan-pro.lovable.app/privacy") }
                            Button(L10n.text("Terms")) { openExternalURL("https://ramadan-pro.lovable.app/terms") }
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .disabled(purchaseTaskRunning || subscriptionVM.isProcessingPurchase)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(24)
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private var unavailablePlansStage: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34))
                .foregroundColor(AppColors.slGreen)
            Text("plans are unavailable")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.slTextPrimary)
            Text("We couldn't load your App Store pricing. Please try again.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.slTextSecondary)
                .multilineTextAlignment(.center)
            SLPrimaryButton(title: "try again", isLoading: subscriptionVM.isLoading) {
                Task {
                    hasAttemptedLoad = false
                }
            }
            Spacer()
        }
        .padding(24)
    }

    // MARK: - Stage 2: spin wheel
    /* Deprecated multi-step offer flow removed for App Review 5.6.

    private var spinStage: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 8)
            Text("before you go...")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.slGold)
            Text("Spin the Wheel 🎡")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.slTextPrimary)
            Text("we want you closer to your faith,\nnot further from it.\neveryone wins something today.")
                .font(.system(size: 15))
                .foregroundColor(AppColors.slTextSecondary)
                .multilineTextAlignment(.center)

            SLSpinWheelView {
                Analytics.logEvent("paywall_spin_won", parameters: nil)
                withAnimation(.spring()) { stage = .deal }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stage 3: discounted yearly deal

    private var dealStage: AnyView {
        guard let discountedPlan = discountedYearlyPlanDetails else {
            return AnyView(unavailablePlansStage)
        }
        let perMonth = discountedPlan.price / 12

        return AnyView(VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                closeButton {
                    Analytics.logEvent("paywall_close_tapped", parameters: ["stage": "deal" as NSString])
                    withAnimation { showDealFaithCheck = true }
                }
            }

            Text("🎁 you unlocked your second-spin deal")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColors.slGold)
            Text(L10n.text("Discounted Yearly"))
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(AppColors.slTextPrimary)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.text("Monthly"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.slTextSecondary)
                        Text(discountedPlan.formatAmount(perMonth))
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(AppColors.slTextPrimary)
                        Text(L10n.text("per month"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.slTextSecondary)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(L10n.text("Discounted Yearly"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.slTextPrimary)
                        Text(L10n.text("Billed annually"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.slGreen)
                        Text(discountedPlan.priceString)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColors.slTextPrimary)
                        Text(L10n.text("per year"))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.slTextSecondary)
                    }
                }

                Divider()
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 10) {
                    Text("your second-spin reward:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.slTextSecondary)
                    if let discountedYearlySavings {
                    Text(L10n.format("Save %@%%", String(discountedYearlySavings)))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppColors.slGreen)
                    }
            Text(L10n.text("12 months of full access for one yearly payment."))
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.slTextSecondary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.slGreen.opacity(0.06)))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppColors.slGreen, lineWidth: 2))
            .shadow(color: AppColors.slGreen.opacity(0.18), radius: 12, x: 0, y: 6)

            SLPrimaryButton(title: subscriptionVM.isProcessingPurchase ? "processing..." : "claim my second-spin deal 🎁", isEnabled: !subscriptionVM.isProcessingPurchase, isLoading: subscriptionVM.isProcessingPurchase) {
                Analytics.logEvent("paywall_deal_claimed", parameters: nil)
                purchase(discountedPlan)
            }

            Text(L10n.text("one payment. a full year of SalahLock, alarms, duas, and every future feature. cancel anytime."))
                .font(.system(size: 12))
                .foregroundColor(AppColors.slTextSecondary)

            if let errorMessage {
                Text(L10n.text(errorMessage))
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .overlay(alignment: .top) {
            SLConfettiView()
                .allowsHitTesting(false)
                .padding(.top, 12)
        })
    }

    */
    // MARK: - Loop helpers

    private func savingsBadge(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "tag.fill")
                .font(.system(size: 11, weight: .bold))
            Text(L10n.text(text))
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(AppColors.slGreen)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(AppColors.slGreen.opacity(0.10)))
    }

    private func closeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColors.slTextSecondary.opacity(0.6))
                .frame(width: 32, height: 32)
                .background(Circle().fill(AppColors.slCream))
        }
        .buttonStyle(.plain)
    }

    private func faithCheckOverlay(
        title: String,
        message: String,
        stayTitle: String,
        leaveTitle: String,
        onStay: @escaping () -> Void,
        onLeave: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.text(title))
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text(L10n.text(message))
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.slTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                SLPrimaryButton(title: stayTitle, action: onStay)
                Button(action: onLeave) {
                    Text(L10n.text(leaveTitle))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.slTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 26).fill(Color.white))
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
    }

    private func exitWithoutPurchase(stage: String = "main", action: String = "close_button") {
        var context = paywallContext(stage: stage)
        context["plan_last_selected"] = selectedPlan?.rawValue ?? ""
        context["exit_action"] = action
        context["reason_source"] = "not_inferred"
        if stage == "final_discount" || stage == "final_trial" {
            context["decline_reason"] = submittedExitReason
            context["reason_source"] = submittedExitReason == "not_provided" ? "skipped" : "user_reported"
        }
        FunnelAnalytics.shared.track(.paywallExited, context)
        if let onExit {
            onExit()
            return
        }
        appState.onboardingComplete = false
        vm.skipTo(.screen17)
    }

    /// Records the actual paywall impression once the plans have loaded and the
    /// paywall is visible. RevenueCat records the resulting transaction; this
    /// Firebase event supplies the denominator needed for paywall conversion.
    private func trackPaywallImpressionIfNeeded() {
        guard !hasTrackedPaywallImpression else { return }
        hasTrackedPaywallImpression = true

        Analytics.logEvent("paywall_impression", parameters: [
            "paywall_id": conversionPaywallID as NSString,
            "entry_point": (onExit == nil ? "onboarding" : "in_app") as NSString
        ])
        var context = paywallContext()
        context["available_plan_ids"] = displayedPlans.compactMap(\.productId).joined(separator: ",")
        context["final_offer_available"] = discountedYearlyPlanDetails != nil
        context["plans_loaded"] = !firstStagePlans.isEmpty
        FunnelAnalytics.shared.track(.paywallViewed, context)

    }

    private func purchase(_ plan: SubscriptionPlanDetails) {
        guard !subscriptionVM.isProcessingPurchase, !purchaseTaskRunning else { return }
        purchaseTaskRunning = true
        hasAttemptedPurchase = true
        let attemptID = UUID().uuidString
        let isTrial = plan.productId == RevenueCatService.annualTrialProductIdentifier
        let stage = isTrial ? "final_trial" : (plan.productId == "yearlydiscounted" ? "final_discount" : "main")
        var attemptProperties = paywallContext(stage: stage)
        attemptProperties["purchase_attempt_id"] = attemptID
        attemptProperties["is_final_offer"] = stage != "main"
        attemptProperties["trial_requested"] = isTrial
        if isTrial { attemptProperties["trial_days"] = plan.introductoryTrialDays ?? 0 }
        attemptProperties["price_amount"] = plan.price
        attemptProperties["currency"] = plan.currencyCode ?? ""
        attemptProperties["plan_id"] = plan.productId ?? ""
        attemptProperties["billing_period"] = plan.type.rawValue
        attemptProperties["price_billed"] = plan.priceString
        let productID = plan.productId ?? ""
        let parameters: [String: Any] = [
            "paywall_id": conversionPaywallID as NSString,
            "paywall_placement": (onExit == nil ? "post_onboarding" : "feature_gate") as NSString,
            "plan_type": plan.type.rawValue as NSString,
            "product_id": productID as NSString
        ]
        FunnelAnalytics.shared.track(.purchaseInitiated, attemptProperties)

        Analytics.logEvent("paywall_cta_tapped", parameters: parameters)
        Analytics.logEvent("paywall_purchase_started", parameters: parameters)

        // Set before checkout so RootRouterView keeps a new buyer on onboarding (for account creation)
        // instead of switching to the main app as soon as the entitlement arrives.
        let buyingBeforeSignUp = beginPurchaseBeforeSignUpIfNeeded()
        Task {
            defer { purchaseTaskRunning = false }
            let success = await subscriptionVM.purchasePlan(plan, analyticsContext: attemptProperties)
            if !success && buyingBeforeSignUp { appState.needsAccountAfterPurchase = false }
            lastCheckoutOutcome = subscriptionVM.lastPurchaseOutcome.rawValue
            var resultProperties = attemptProperties
            resultProperties["last_checkout_outcome"] = lastCheckoutOutcome
            if success {
                let verifiedTrial = trialService.subscriptionStatus.isInTrial
                resultProperties["subscription_period_type"] = verifiedTrial ? "trial" : "normal"
                resultProperties["charge_status"] = verifiedTrial ? "free_trial" : "not_reported"
                Analytics.logEvent("paywall_purchase_success", parameters: parameters)
                FunnelAnalytics.shared.track(.purchaseCompleted, resultProperties)
                if verifiedTrial {
                    var trialProperties = resultProperties
                    trialProperties["trial_end_at"] = trialService.subscriptionStatus.trialEndDate.map { ISO8601DateFormatter().string(from: $0) } ?? ""
                    trialProperties["charge_status"] = "free_trial"
                    FunnelAnalytics.shared.track(.trialStarted, trialProperties)
                }
                // A free trial is not paid annual revenue. Report conversion to
                // paid through verified RevenueCat renewal/webhook events.
                AppsFlyerService.shared.logEvent(verifiedTrial ? "af_start_trial" : "af_purchase", parameters: [
                    "af_revenue": verifiedTrial ? 0 : plan.price,
                    "af_currency": plan.currencyCode ?? "",
                    "af_content_id": productID,
                    "af_subscription": plan.type != .lifetime
                ])
                finishPurchase()
                print("🏠 SLPaywallScreen: Purchase successful → exiting onboarding")
            } else {
                let event: FunnelEvent
                let analyticsEvent: String
                switch subscriptionVM.lastPurchaseOutcome {
                case .cancelled:
                    event = .purchaseCancelled
                    analyticsEvent = "paywall_purchase_cancelled"
                case .pending:
                    event = .purchasePending
                    analyticsEvent = "paywall_purchase_pending"
                case .notAllowed:
                    event = .purchaseNotAllowed
                    analyticsEvent = "paywall_purchase_not_allowed"
                default:
                    event = .purchaseFailed
                    analyticsEvent = "paywall_purchase_failed"
                }
                var outcomeProperties = resultProperties
                subscriptionVM.purchaseErrorProperties.forEach { outcomeProperties[$0.key] = $0.value }
                FunnelAnalytics.shared.track(event, outcomeProperties)
                var outcomeParameters = parameters
                subscriptionVM.purchaseErrorProperties.forEach { outcomeParameters[$0.key] = $0.value as NSString }
                Analytics.logEvent(analyticsEvent, parameters: outcomeParameters)
                errorMessage = subscriptionVM.lastPurchaseOutcome == .cancelled ? nil : subscriptionVM.errorMessage
            }
        }
    }

    private func restorePurchases() {
        let buyingBeforeSignUp = beginPurchaseBeforeSignUpIfNeeded()
        Task {
            let success = await subscriptionVM.restorePurchases()
            if !success && buyingBeforeSignUp { appState.needsAccountAfterPurchase = false }
            if success {
                finishPurchase()
                print("🏠 SLPaywallScreen: Restore successful → exiting onboarding")
            } else {
                errorMessage = subscriptionVM.errorMessage ?? "Restore failed"
            }
        }
    }

    /// Unlocks access after a purchase or restore. Someone who bought before creating an
    /// account goes to the account screen next, so the subscription is saved to their account.
    private func finishPurchase() {
        vm.completeOnboarding()
        UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
        WidgetConfig.saveIsSubscribed(true)
        appState.onboardingComplete = true
        appState.shouldExitOnboarding = true
        if appState.needsAccountAfterPurchase && !FirebaseAuthService.shared.isAuthenticated {
            vm.skipTo(.screen17)
            return
        }
        onExit?()
    }

    /// Onboarding paywall only: marks that a signed-out user is buying, so they create an account afterwards.
    private func beginPurchaseBeforeSignUpIfNeeded() -> Bool {
        guard onExit == nil, !FirebaseAuthService.shared.isAuthenticated else { return false }
        appState.needsAccountAfterPurchase = true
        return true
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
                title: L10n.text("unlock all premium features"),
                subtitle: L10n.text("get full access to every tool in SalahAlarm")
            )
            Divider().padding(.leading, 64)
            paywallFeatureRow(
                icon: "leaf",
                title: L10n.text("support future development"),
                subtitle: L10n.text("your support helps us build new features")
            )
            Divider().padding(.leading, 64)
            paywallFeatureRow(
                icon: "heart",
                title: L10n.text("help us improve the experience"),
                subtitle: L10n.text("so we can keep making the app better for you")
            )
        }
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.white))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var choosePlanHeader: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(AppColors.slGreen.opacity(0.25))
                .frame(height: 1)
            Text(L10n.text("choose your plan"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.slGreen)
                .fixedSize(horizontal: true, vertical: false)
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
                Text(L10n.text(title))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.slTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.text(subtitle))
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.slTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func timelineBlock(title: String, points: [String]) -> some View {
        EmptyView()
    }

    private func planCard(title: String, priceLine1: String, priceLine2: String, badge: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(L10n.text(title))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                    if let badge {
                        Text(L10n.text(badge))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppColors.slGreen))
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text(priceLine1))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(AppColors.slTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(L10n.text(priceLine2))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(AppColors.slTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24).fill(isSelected ? AppColors.slGreen.opacity(0.06) : Color.white))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.slGreen, lineWidth: isSelected ? 2 : 1))
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: isSelected ? 10 : 4, x: 0, y: isSelected ? 8 : 2)
        }
        .buttonStyle(.plain)
    }

    private func legacyPlanCard(title: String, price: String, subtitle: String?, badge: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                if let badge {
                    Text(L10n.text(badge))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.slGold)
                }
                Text(L10n.text(title))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text(price)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.slTextPrimary)
                if let subtitle {
                    Text(L10n.text(subtitle))
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
