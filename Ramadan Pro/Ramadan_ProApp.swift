//
//  Ramadan_ProApp.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import SwiftUI
import WidgetKit
import UserNotifications
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import RevenueCat
import FirebaseAnalytics

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Treat a fresh install (after deleting the app) as a full local reset.
        let defaults = UserDefaults.standard
        let firstLaunchKey = "hasCompletedInitialInstall"
        if defaults.bool(forKey: firstLaunchKey) == false {
            defaults.set(true, forKey: firstLaunchKey)
            
            if Auth.auth().currentUser != nil {
                do {
                    try Auth.auth().signOut()
                    print("🧹 [FIRST_LAUNCH] Signed out persisted Firebase user on fresh install")
                } catch {
                    print("⚠️ [FIRST_LAUNCH] Failed to sign out persisted Firebase user: \(error.localizedDescription)")
                }
            }
            
            defaults.set(false, forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
            defaults.set(false, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
            WidgetConfig.saveIsSubscribed(false)
            print("🧹 [FIRST_LAUNCH] Cleared local login and subscription flags on fresh install")
        }
        
        // Configure Google Sign-In with Firebase client ID
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            fatalError("Firebase client ID not found")
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Initialize RevenueCat
        RevenueCatService.configure()

        FunnelAnalytics.shared.configure()
        // Configure attribution before emitting install or onboarding events.
        AppsFlyerService.shared.configure()

        FunnelAnalytics.shared.trackInstallIfNeeded()

        // Initialize TikTok ads measurement.
        TikTokAdsService.shared.configure()

        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // Register background tasks for prayer alarm rescheduling
        BGTaskManager.shared.registerTasks()
        BGTaskManager.shared.scheduleNextRefresh()
        
        return true
    }
}

@main
struct Ramadan_ProApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage(AppLanguage.preferenceKey) private var languageCode = AppLanguage.current.rawValue
    
    @StateObject private var appState = AppState.shared
    @StateObject private var onboardingState = OnboardingState.shared
    @StateObject private var authService = FirebaseAuthService.shared
    
    var body: some Scene {
        WindowGroup {
            RootRouterView()
                .environment(\.locale, (AppLanguage(rawValue: languageCode) ?? .current).locale)
                .environment(\.layoutDirection, (AppLanguage(rawValue: languageCode) ?? .current).isRightToLeft ? .rightToLeft : .leftToRight)
                .appTypesetting(AppLanguage(rawValue: languageCode) ?? .current)
                .environmentObject(appState)
                .environmentObject(onboardingState)
                .environmentObject(authService)
            .onOpenURL { url in
                if ComebackOfferService.shared.handle(url: url) { return }
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}

struct RootRouterView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var revenueCatService = RevenueCatService.shared
    @ObservedObject private var comebackOffer = ComebackOfferService.shared
    /// Set only after the subscription check has run for the signed-in account,
    /// so a paying customer who signs in again never sees the discount.
    @State private var comebackOfferVerified = false

    @AppStorage(AppConstants.UserDefaultsKeys.isSubscribed) private var isSubscribed: Bool = false

    private var hasSubscription: Bool {
        revenueCatService.subscriptionStatus.isActive || isSubscribed
    }

    /// Launch-only QA routing; unavailable in release builds and never bypasses payment.
    private var replayVerificationView: AnyView? {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if environment["POSTHOG_REPLAY_VERIFICATION_ID"] != nil {
            switch environment["POSTHOG_REPLAY_QA_SCREEN"] {
            case "paywall": return AnyView(SLPaywallScreen(vm: OnboardingFlowViewModel()))
            case "privacy": return AnyView(LoginView())
            default: break
            }
        }
        #endif
        return nil
    }

    private var showsComebackOffer: Binding<Bool> {
        Binding(
            get: {
                replayVerificationView == nil && comebackOfferVerified && comebackOffer.shouldPresent(
                    isAuthenticated: authService.isAuthenticated,
                    hasSubscription: hasSubscription
                )
            },
            set: { isPresented in
                if !isPresented {
                    comebackOfferVerified = false
                    comebackOffer.clear()
                }
            }
        )
    }

    /// Confirms the signed-in account has no active subscription before the offer shows.
    private func verifyComebackOffer() async {
        comebackOfferVerified = false
        guard comebackOffer.pendingSource != nil,
              authService.isAuthenticated,
              let userId = authService.currentUser?.userId else { return }
        do {
            try await RevenueCatService.shared.setUserID(userId)
        } catch {
            print("⚠️ RootRouterView: Comeback offer could not confirm the account - \(error.localizedDescription)")
            return
        }
        // Fail closed: if RevenueCat can't be reached, a reinstalled subscriber's
        // local flag may still be false, so don't show the discount.
        guard await RevenueCatService.shared.checkSubscriptionStatus() else { return }
        comebackOfferVerified = !hasSubscription
        if hasSubscription { comebackOffer.clear() }
    }

    var body: some View {
        Group {
            if let replayVerificationView {
                replayVerificationView
            } else if hasSubscription {
                MainTabView()
                    .environmentObject(appState)
            } else if authService.isAuthenticated && appState.onboardingComplete {
                SLPaywallScreen(vm: OnboardingFlowViewModel())
            } else {
                SalahAlarmOnboardingView()
            }
        }
        .task {
            guard authService.isAuthenticated, let userId = authService.currentUser?.userId else { return }
            do {
                try await RevenueCatService.shared.setUserID(userId)
                await RevenueCatService.shared.checkSubscriptionStatus()
            } catch {
                print("⚠️ RootRouterView: Failed to initialize subscription state - \(error.localizedDescription)")
            }
        }
        .onAppear {
            FunnelAnalytics.shared.applicationDidBecomeActive()
            if hasSubscription {
                RatingPromptManager.shared.recordAppActivation()
            }
        }
        .fullScreenCover(isPresented: showsComebackOffer) {
            ComebackOfferView()
        }
        .task(id: "\(comebackOffer.pendingSource ?? "")|\(authService.isAuthenticated)|\(authService.currentUser?.userId ?? "")") {
            await verifyComebackOffer()
        }
        .onChange(of: revenueCatService.subscriptionStatus.isActive) { isActive in
            if isActive { comebackOffer.clear() }
            UserDefaults.standard.set(isActive, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
            WidgetConfig.saveIsSubscribed(isActive)
            if isActive {
                appState.onboardingComplete = true
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background { FunnelAnalytics.shared.applicationDidEnterBackground() }
            if newPhase == .active { FunnelAnalytics.shared.applicationDidBecomeActive() }
            guard newPhase == .active, authService.isAuthenticated else { return }
            if hasSubscription {
                RatingPromptManager.shared.recordAppActivation()
            }
            Task {
                await RevenueCatService.shared.checkSubscriptionStatus()
            }
        }
    }
}

// MARK: - Splash Screen Wrapper

/// Wrapper that shows splash first, then transitions to appropriate view
struct SplashScreenWrapper: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var onboardingState: OnboardingState
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var showSplash = true
    @State private var shouldShowOnboarding = false
    @State private var shouldShowMainApp = false
    @State private var hasInitialized = false
    
    // Stable view decision based on initial state - only computed once
    @ViewBuilder
    private var authDecisionView: some View {
        if shouldShowOnboarding {
            // User is not logged in - show onboarding starting at login
            OnboardingFlowView()
                .environmentObject(appState)
                .onAppear {
                    let isLoggedIn = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
                    let hasSubscription = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.isSubscribed)
                    
                    logAuthDecision(isLoggedIn: isLoggedIn, hasSubscription: hasSubscription)
                    print("📱 [AUTH_DECISION] OnboardingFlowView appeared - Ensuring correct starting step")
                    print("   - Current step is: \(onboardingState.currentStep)")
                    
                    if !isLoggedIn {
                        // Both false → start at login
                        if onboardingState.currentStep != .login {
                            print("   - Setting onboarding step to .login (user not logged in)")
                            onboardingState.currentStep = .login
                        }
                    } else if !hasSubscription {
                        // Logged in but not subscribed → start at subscription paywall
                        if onboardingState.currentStep != .mainPaywall {
                            print("   - Setting onboarding step to .mainPaywall (logged in, no subscription)")
                            onboardingState.currentStep = .mainPaywall
                        }
                    }
                }
        } else if shouldShowMainApp {
            // User is logged in - show main app
            MainTabView()
                .environmentObject(appState)
                .onAppear {
                    let hasSubscription = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.isSubscribed)
                    logAuthDecision(isLoggedIn: true, hasSubscription: hasSubscription)
                    print("💰 [AUTH_DECISION] Showing MainTabView (user is logged in)")
                }
        } else {
            // Initial state - will be set in .task
            Color.clear
                .onAppear {
                    print("⏳ [AUTH_DECISION] Waiting for initialization...")
                }
        }
    }
    
    // Helper function to log auth decision details
    private func logAuthDecision(isLoggedIn: Bool, hasSubscription: Bool? = nil) {
        let firebaseHasUser = Auth.auth().currentUser != nil
        let serviceIsAuthenticated = authService.isAuthenticated
        let currentStep = onboardingState.currentStep
        
        print("🔍 [AUTH_DECISION] Checking auth state:")
        print("   - UserDefaults isLoggedIn: \(isLoggedIn)")
        print("   - Firebase has user: \(firebaseHasUser)")
        print("   - Service isAuthenticated: \(serviceIsAuthenticated)")
        print("   - Current onboarding step: \(currentStep)")
        print("   - Service currentUser: \(authService.currentUser != nil ? "exists" : "nil")")
        if let user = authService.currentUser {
            print("   - User isSubscribed: \(user.isSubscribed)")
        }
        if let hasSubscription = hasSubscription {
            print("   - Decision: hasSubscription = \(hasSubscription)")
        }
        
        if !isLoggedIn {
            print("🚪 [AUTH_DECISION] User NOT logged in (UserDefaults) → Showing OnboardingFlowView at LOGIN step")
        } else if let hasSubscription = hasSubscription, hasSubscription {
            print("💰 [AUTH_DECISION] User has subscription → Showing MainTabView (skipping onboarding)")
        } else {
            print("⚠️ [AUTH_DECISION] User logged in but no subscription or data not loaded")
            print("   - Service authenticated: \(serviceIsAuthenticated)")
            print("   - Current step: \(currentStep)")
            print("   → Showing OnboardingFlowView (no auto-navigation)")
        }
    }
    
    var body: some View {
        Group {
            if showSplash {
                SplashScreenView(autoAdvance: false)
                    .onAppear {
                        // Simple test event so you can verify Analytics in DebugView
                        Analytics.logEvent("app_launch_test", parameters: nil)
                        
                        // Auto-advance after splash duration (typically 2-3 seconds)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation {
                                showSplash = false
                            }
                        }
                    }
                } else {
                    // After splash, check authentication and subscription status
                    authDecisionView
                }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplash)
        .task {
            // Initialize auth decision ONCE - this prevents re-evaluation
            if !hasInitialized {
                await initializeAuthDecision()
                hasInitialized = true
            }
            
            // Set RevenueCat user ID and check subscription when authenticated
            if authService.isAuthenticated, let userId = authService.currentUser?.userId {
                do {
                    try await RevenueCatService.shared.setUserID(userId)
                    // Check subscription status and sync with Firebase
                    // This will update UserDefaults with subscription status
                    await RevenueCatService.shared.checkSubscriptionStatus()
                    print("✅ [AUTH_DECISION] Subscription status checked and UserDefaults updated")
                } catch {
                    print("⚠️ Failed to set RevenueCat user ID: \(error.localizedDescription)")
                }
            }
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            // Only update if user is logging out (not logging in)
            // If user is already in MainTabView, don't change the view
            if !isAuthenticated && shouldShowMainApp {
                // User logged out - navigate to onboarding
                print("🚪 [AUTH_DECISION] User logged out while in app - navigating to onboarding")
                shouldShowMainApp = false
                shouldShowOnboarding = true
                UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
                WidgetConfig.saveIsSubscribed(false)
                print("🧹 [AUTH_DECISION] User logged out - cleared subscription status from UserDefaults")
            } else if isAuthenticated, let userId = authService.currentUser?.userId {
                // User logged in - update RevenueCat but don't change view if already in MainTabView
                Task {
                    do {
                        try await RevenueCatService.shared.setUserID(userId)
                        await RevenueCatService.shared.checkSubscriptionStatus()
                        print("✅ [AUTH_DECISION] Subscription status checked and UserDefaults updated (on auth change)")
                    } catch {
                        print("⚠️ Failed to set RevenueCat user ID: \(error.localizedDescription)")
                    }
                }
            }
        }
        .onChange(of: RevenueCatService.shared.subscriptionStatus.isActive) { isActive in
            // Update UserDefaults whenever subscription status changes
            UserDefaults.standard.set(isActive, forKey: AppConstants.UserDefaultsKeys.isSubscribed)
            WidgetConfig.saveIsSubscribed(isActive)
            print("💾 [AUTH_DECISION] Subscription status changed to \(isActive) - updated UserDefaults")

            // If user is authenticated and now has an active subscription, and we're still in onboarding,
            // automatically switch to the main app (handles cases like reinstall or delayed RevenueCat sync).
            if isActive && !shouldShowMainApp {
                let isLoggedIn = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
                if isLoggedIn {
                    print("✅ [AUTH_DECISION] Detected active subscription while in onboarding → Switching to MainTabView")
                    shouldShowOnboarding = false
                    shouldShowMainApp = true
                } else {
                    print("⚠️ [AUTH_DECISION] Subscription active but user not marked as logged in in UserDefaults")
                }
            }
        }
        .onChange(of: appState.shouldExitOnboarding) { shouldExit in
            // Handle navigation from ImpactIntroductionScreenView
            if shouldExit {
                print("🏠 [AUTH_DECISION] shouldExitOnboarding triggered - checking if should navigate to home")
                let isLoggedIn = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
                let hasSubscription = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.isSubscribed)
                
                if isLoggedIn && hasSubscription {
                    print("✅ [AUTH_DECISION] User has subscription - switching to MainTabView")
                    shouldShowOnboarding = false
                    shouldShowMainApp = true
                    appState.shouldExitOnboarding = false // Reset flag
                } else {
                    print("⚠️ [AUTH_DECISION] Cannot exit onboarding - user not logged in or no subscription")
                    appState.shouldExitOnboarding = false // Reset flag
                }
            }
        }
    }
    
    // Initialize auth decision once - this prevents unwanted navigation
    private func initializeAuthDecision() async {
        // Use ONLY UserDefaults to check login & subscription state - no Firebase or service checks
        let isLoggedIn = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.isLoggedIn)
        let hasSubscription = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.isSubscribed)
        
        print("🔍 [AUTH_DECISION] Initializing auth decision...")
        print("   - UserDefaults isLoggedIn: \(isLoggedIn)")
        print("   - UserDefaults hasSubscription: \(hasSubscription)")
        
        // Decide navigation based ONLY on these two flags:
        // - isLoggedIn == false, hasSubscription == false  → login screen
        // - isLoggedIn == true,  hasSubscription == false  → subscription paywall
        // - isLoggedIn == true,  hasSubscription == true   → main app
        
        if !isLoggedIn {
            print("🚪 [AUTH_DECISION] User NOT logged in → Showing OnboardingFlowView at LOGIN step")
            shouldShowOnboarding = true
            shouldShowMainApp = false
            onboardingState.currentStep = .login
        } else if !hasSubscription {
            print("💳 [AUTH_DECISION] User logged in but NO active subscription → Showing subscription paywall")
            shouldShowOnboarding = true
            shouldShowMainApp = false
            onboardingState.currentStep = .mainPaywall
        } else {
            // User is logged in AND has an active subscription – show main app
            // Once user is in MainTabView, they should stay there
            print("✅ [AUTH_DECISION] User IS logged in AND has subscription → Showing MainTabView")
            shouldShowMainApp = true
            shouldShowOnboarding = false
            // Disable Sadaq donation prompt popup
            AppState.shared.shouldShowSadaqPrompt = false
        }
    }
}

extension View {
    /// Plain-string Text carries no language, so Urdu otherwise mixes Nastaliq (localized
    /// keys) with Naskh, and Nastaliq lines collide. Tagging all text as Urdu gives one
    /// typeface and Nastaliq-sized line heights.
    @ViewBuilder
    func appTypesetting(_ language: AppLanguage) -> some View {
        if #available(iOS 17.0, *), language == .urdu {
            typesettingLanguage(Locale.Language(identifier: "ur"), isEnabled: true)
        } else {
            self
        }
    }
}
