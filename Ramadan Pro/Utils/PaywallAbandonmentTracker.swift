//
//  PaywallAbandonmentTracker.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import SwiftUI
import Combine

/// Tracks user behavior on paywall to detect abandonment intent
@MainActor
class PaywallAbandonmentTracker: ObservableObject {
    // MARK: - Published Properties
    
    @Published var timeOnScreen: TimeInterval = 0
    @Published var scrollOffset: CGFloat = 0
    @Published var hasInteractedWithPricing: Bool = false
    @Published var hasScrolledToBottom: Bool = false
    @Published var shouldShowDiscount: Bool = false
    
    // MARK: - Private Properties
    
    private var startTime: Date?
    private var timer: Timer?
    private let idleThreshold: TimeInterval = 15.0 // Show discount only after 15 seconds without purchase
    private let scrollThreshold: CGFloat = 0.85 // Show discount when scrolled 85% down
    private var lastInteractionTime: Date = Date()
    
    // MARK: - Public Methods
    
    /// Start tracking when paywall appears
    func startTracking() {
        startTime = Date()
        lastInteractionTime = Date()
        timeOnScreen = 0
        
        // Start timer to track time on screen
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateTracking()
        }
        
        print("📊 PaywallAbandonmentTracker: Started tracking")
    }
    
    /// Stop tracking when paywall disappears
    func stopTracking() {
        timer?.invalidate()
        timer = nil
        print("📊 PaywallAbandonmentTracker: Stopped tracking - Total time: \(timeOnScreen)s")
    }
    
    /// Record user interaction (tapping pricing cards, buttons, etc.)
    func recordInteraction() {
        lastInteractionTime = Date()
        hasInteractedWithPricing = true
        print("📊 PaywallAbandonmentTracker: User interaction recorded")
    }
    
    /// Update scroll position
    func updateScrollOffset(_ offset: CGFloat, contentHeight: CGFloat, screenHeight: CGFloat) {
        let scrollPercentage = offset / max(contentHeight - screenHeight, 1)
        scrollOffset = scrollPercentage
        
        // Check if user scrolled to bottom (near "No thanks" button)
        if scrollPercentage >= scrollThreshold && !hasScrolledToBottom {
            hasScrolledToBottom = true
            print("📊 PaywallAbandonmentTracker: User scrolled to bottom (abandonment signal)")
            checkAbandonmentSignals()
        }
    }
    
    /// Check if we should show discount based on abandonment signals
    func checkAbandonmentSignals() -> Bool {
        let timeSinceLastInteraction = Date().timeIntervalSince(lastInteractionTime)
        let isIdle = timeSinceLastInteraction >= idleThreshold
        
        // Scenario 1: User has been idle for threshold time
        if isIdle && timeOnScreen >= idleThreshold {
            print("📊 PaywallAbandonmentTracker: User idle for \(timeSinceLastInteraction)s - showing discount")
            shouldShowDiscount = true
            return true
        }
        
        // Scenario 2: User scrolled to bottom (near "No thanks")
        if hasScrolledToBottom {
            print("📊 PaywallAbandonmentTracker: User scrolled to bottom - showing discount")
            shouldShowDiscount = true
            return true
        }
        
        return false
    }
    
    // MARK: - Private Methods
    
    private func updateTracking() {
        guard let startTime = startTime else { return }
        timeOnScreen = Date().timeIntervalSince(startTime)
        
        // Check abandonment signals periodically
        if !shouldShowDiscount {
            _ = checkAbandonmentSignals()
        }
    }
}
