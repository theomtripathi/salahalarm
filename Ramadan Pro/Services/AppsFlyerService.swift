//
//  AppsFlyerService.swift
//  Ramadan Pro
//
//  AppsFlyer attribution for ad campaigns. Configured at launch, started on
//  app-active (after waiting for the ATT prompt so the IDFA is included in
//  the install event). The AppsFlyer ID is also pushed to RevenueCat so
//  purchase/renewal events reach AppsFlyer server-to-server for ROAS.
//

import Foundation
import UIKit
import AppTrackingTransparency
import AppsFlyerLib
import RevenueCat

final class AppsFlyerService: NSObject {
    static let shared = AppsFlyerService()

    private static let devKey = "9rYhga6fQ3gno5G6tcXS76"
    private static let appleAppID = "6758457826"

    private var hasStarted = false
    private var pendingEvents: [(name: String, parameters: [String: Any]?)] = []
    private var hasReportedATTStatus = false

    private override init() {
        super.init()
    }

    /// Call once from application(_:didFinishLaunchingWithOptions:).
    func configure() {
        let af = AppsFlyerLib.shared()
        af.appsFlyerDevKey = Self.devKey
        af.appleAppID = Self.appleAppID
        af.delegate = self
        #if DEBUG
        af.isDebug = true
        #endif
        // Hold the install event until the ATT prompt is answered (or 60s
        // passes) so attribution includes the IDFA when the user allows it.
        af.waitForATTUserAuthorization(timeoutInterval: 60)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        print("✅ AppsFlyerService: configured (app id \(Self.appleAppID)), IDFV: \(UIDevice.current.identifierForVendor?.uuidString ?? "n/a")")
    }

    @objc private func appDidBecomeActive() {
        AppsFlyerLib.shared().start { [weak self] _, error in
            if let error {
                print("⚠️ AppsFlyerService: start failed: \(error.localizedDescription)")
                return
            }
            guard let self, !self.hasStarted else { return }
            self.hasStarted = true
            let queuedEvents = self.pendingEvents
            self.pendingEvents.removeAll()
            for event in queuedEvents {
                AppsFlyerLib.shared().logEvent(event.name, withValues: event.parameters)
            }
            // Link AppsFlyer <-> RevenueCat so subscription events flow to
            // AppsFlyer for campaign ROAS measurement.
            let appsFlyerID = AppsFlyerLib.shared().getAppsFlyerUID()
            Purchases.shared.attribution.setAppsflyerID(appsFlyerID)
            print("✅ AppsFlyerService: started, uid \(appsFlyerID)")
        }
    }

    /// Shows the ATT prompt if the user hasn't answered it yet.
    /// Safe to call from multiple places; iOS only ever shows it once.
    func requestTrackingAuthorizationIfNeeded() async {
        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        guard currentStatus == .notDetermined else {
            guard !hasReportedATTStatus else { return }
            hasReportedATTStatus = true
            logEvent("att_authorization_status", parameters: ["status": currentStatus.rawValue])
            return
        }
        let status = await ATTrackingManager.requestTrackingAuthorization()
        hasReportedATTStatus = true
        logEvent("att_authorization_status", parameters: ["status": status.rawValue])
        print("ℹ️ AppsFlyerService: ATT status = \(status.rawValue)")
    }

    /// Log an in-app event (e.g. onboarding milestones) to AppsFlyer.
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        if hasStarted {
            AppsFlyerLib.shared().logEvent(name, withValues: parameters)
        } else {
            pendingEvents.append((name, parameters))
        }
    }
}

extension AppsFlyerService: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        let status = conversionInfo["af_status"] as? String ?? "unknown"
        print("📈 AppsFlyerService: conversion data received, af_status = \(status)")
    }

    func onConversionDataFail(_ error: Error) {
        print("⚠️ AppsFlyerService: conversion data failed: \(error.localizedDescription)")
    }
}
