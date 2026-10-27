//
//  WidgetHelper.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import WidgetKit

/// Helper utilities for widget management
enum WidgetHelper {
    /// Widget kind identifier - must match the widget's kind
    static let widgetKind = "SalahAlarmWidget"
    
    /// Reload all timeline entries for the widget
    /// Call this after updating location or important data
    static func reloadWidgetTimeline() {
        DebugLogger.log("Reloading widget timeline for kind: \(widgetKind)")
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        DebugLogger.logSuccess("Widget timeline reload requested")
    }
    
    /// Reload all widgets for this app
    static func reloadAllWidgets() {
        DebugLogger.log("Reloading all widget timelines")
        WidgetCenter.shared.reloadAllTimelines()
        DebugLogger.logSuccess("All widget timelines reload requested")
    }
    
    /// Check if widgets are available on this device
    static var isWidgetAvailable: Bool {
        if #available(iOS 14.0, *) {
            return true
        }
        return false
    }
}
