//
//  DebugLogger.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation

/// Debug logging utility for Ramadan Pro
/// Set `isEnabled` to false to disable all debug logs
struct DebugLogger {
    static var isEnabled: Bool = false
    
    static func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        print("🔍 [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)")
    }
    
    static func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        print("❌ [\(timestamp)] [\(fileName):\(line)] \(function) - ERROR: \(message)")
    }
    
    static func logSuccess(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        print("✅ [\(timestamp)] [\(fileName):\(line)] \(function) - SUCCESS: \(message)")
    }
    
    static func logWidget(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        print("📱 [WIDGET] [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)")
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
