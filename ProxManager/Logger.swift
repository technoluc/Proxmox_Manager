import Foundation
import OSLog
import SwiftUI
import Combine

enum LogLevel: String, CaseIterable, Identifiable {
    case error = "❌ ERROR"
    case warning = "⚠️ WARNING"
    case debug = "🐞 DEBUG"
    case info = "ℹ️ INFO"

    var id: String { rawValue }
}

class Logger {
    static let shared = Logger()

    private let osLogger: OSLog
    private let logQueue = DispatchQueue(label: "com.proxmanager.logQueue", qos: .background)

    private let logFileName = "ProxManagerLogs.txt"
    private lazy var logFilePath: URL = {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentDirectory.appendingPathComponent(logFileName)
    }()

    private init() {
        self.osLogger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.proxmanager", category: "AppLogs")
    }

    /// Logs to console, OSLog, and file — includes file/line/function metadata
    func log(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .long)
        let formatted = "\(level.rawValue) [\(fileName):\(line)] \(function): \(message)"
        let fullLog = "\(timestamp) [\(level.rawValue)]: \(message)\n"

        // 🔍 Console (dev only)
//        #if DEBUG
//        print(fullLog)
//        #endif

        // 📋 OSLog (for syslog, Console.app, etc.)
        switch level {
        case .debug:
            os_log(.debug, log: osLogger, "%{public}s", formatted)
        case .info:
            os_log(.info, log: osLogger, "%{public}s", formatted)
        case .warning:
            os_log(.default, log: osLogger, "%{public}s", formatted)
        case .error:
            os_log(.error, log: osLogger, "%{public}s", formatted)
        }

        // 🗂 File logging (asynchronously)
        logQueue.async {
            guard let data = fullLog.data(using: .utf8) else { return }

            if FileManager.default.fileExists(atPath: self.logFilePath.path) {
                do {
                    let fileHandle = try FileHandle(forWritingTo: self.logFilePath)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                } catch {
                    print("❌ Logger: Failed to append to log file - \(error)")
                }
            } else {
                do {
                    try data.write(to: self.logFilePath, options: .atomicWrite)
                } catch {
                    print("❌ Logger: Failed to create log file - \(error)")
                }
            }
        }
    }

    /// Reads all logs, optionally filtered by level
    func readLogs(filteredBy level: LogLevel? = nil) -> String {
        let contents = (try? String(contentsOf: logFilePath, encoding: .utf8)) ?? ""
        guard let level = level else { return contents }

        return contents
            .split(separator: "\n")
            .filter { $0.contains("[\(level.rawValue)]") }
            .joined(separator: "\n")
    }

    /// Clears the log file (used in ProxManagerApp.swift on launch)
    func clearLogs() {
        logQueue.async {
            try? FileManager.default.removeItem(at: self.logFilePath)
        }
    }
}
