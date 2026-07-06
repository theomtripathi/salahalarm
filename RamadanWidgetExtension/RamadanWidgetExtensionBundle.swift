//
//  RamadanWidgetExtensionBundle.swift
//  RamadanWidgetExtension
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Debug Logger (Widget Extension only)
private func logWidget(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    let timestamp = formatter.string(from: Date())
    let fileName = (file as NSString).lastPathComponent
    print("📱 [WIDGET EXTENSION] [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)")
    #endif
}

private func logWidgetError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    let timestamp = formatter.string(from: Date())
    let fileName = (file as NSString).lastPathComponent
    print("❌ [WIDGET EXTENSION ERROR] [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)")
    #endif
}

private func logWidgetSuccess(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    let timestamp = formatter.string(from: Date())
    let fileName = (file as NSString).lastPathComponent
    print("✅ [WIDGET EXTENSION SUCCESS] [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)")
    #endif
}

@main
struct RamadanWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        RamadanWidget()
    }
}

