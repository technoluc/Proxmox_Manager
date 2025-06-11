//
//  LogsView 4.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 22/03/2025.
//


import SwiftUI

struct LogsView: View {
//    @State private var logText: String = ""
    @State private var searchQuery: String = ""
    @State private var selectedLogLevel: LogLevel? = nil
    @State private var refreshTrigger = UUID()

    init() {
        UISegmentedControl.appearance().setTitleTextAttributes(
            [
                .font: UIFont.systemFont(ofSize: 9),
            ], for: .normal)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 10) {

                    // 🔎 Search and Filter
                    VStack(spacing: 10) {
                        Picker("Filter by Log Level", selection: $selectedLogLevel) {
                            Text("All").tag(nil as LogLevel?)
                            ForEach(LogLevel.allCases, id: \.self) { level in
                                Text(level.rawValue).tag(level as LogLevel?)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .font(.footnote)

                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)

                            TextField("Search Logs...", text: $searchQuery)
                                .textFieldStyle(PlainTextFieldStyle())
                                .foregroundColor(.primary)
                                .autocorrectionDisabled(true)
                                .textInputAutocapitalization(.never)

                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.2), radius: 5)
                        .padding(.horizontal)
                    }

                    // 📝 Scrollable Logs
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if filteredLogs.isEmpty {
                                Text("No logs available")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                    .padding(.top, 20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(filteredLogs) { log in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(log.timestamp)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .textSelection(.enabled)

                                        Text(log.message)
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundColor(color(for: log.level))
                                            .textSelection(.enabled)

                                        Divider()
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                        .padding()
                    }
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.2), radius: 5)
                    .padding()
                    .id(refreshTrigger) // ✅ force refresh when changed


                    // 🚀 Action Buttons
                    HStack {
                        Button(action: refreshLogs) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)

                        Button(action: clearLogs) {
                            Label("Clear Logs", systemImage: "trash")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)

                        Button(action: exportLogs) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Network Logs")
            .onAppear {
                Logger.shared.log("👤 User selected LogsView Tab")
                refreshLogs()
            }
            .toolbar(.hidden, for: .automatic)
        }
    }

    // 🧱 Log Entry Struct
    struct LogEntry: Identifiable, Hashable {
        let id = UUID()
        let timestamp: String
        let message: String
        let level: LogLevel
    }

    // 🔍 Filtered + Parsed Logs
    var filteredLogs: [LogEntry] {
        let rawLogs = Logger.shared.readLogs(filteredBy: selectedLogLevel)
            .split(separator: "\n")
            .map { String($0) }

        let parsed = rawLogs.compactMap { line -> LogEntry? in
//            let pattern = #"^(\d{2}/\d{2}/\d{4}, \d{2}:\d{2}:\d{2} GMT ?[+-]?\d{1,2}): \[(.*?)\] (.*)$"#
            let pattern = #"^(\d{2}/\d{2}/\d{4}, \d{2}:\d{2}:\d{2} GMT\+?\d*?) \[(.*?)\]: (.*)$"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            let range = NSRange(location: 0, length: line.utf16.count)

            if let match = regex.firstMatch(in: line, options: [], range: range),
               let timestampRange = Range(match.range(at: 1), in: line),
               let levelRange = Range(match.range(at: 2), in: line),
               let messageRange = Range(match.range(at: 3), in: line) {

                let timestamp = String(line[timestampRange])
                let levelStr = String(line[levelRange])
                let message = String(line[messageRange])

                let level = LogLevel(rawValue: levelStr) ?? .info
                return LogEntry(timestamp: timestamp, message: message, level: level)
            }

            // Fallback
            return LogEntry(timestamp: "Unknown", message: line, level: .info)
        }

        guard !searchQuery.isEmpty else { return parsed }

        return parsed.filter {
            $0.timestamp.localizedCaseInsensitiveContains(searchQuery) ||
            $0.message.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private func color(for level: LogLevel) -> Color {
        switch level {
        case .error: return .red
        case .warning: return .orange
        case .debug: return .blue
        case .info: return .primary
        }
    }

    private func refreshLogs() {
        refreshTrigger = UUID() // triggers re-evaluation of view
    }

    private func clearLogs() {
        Logger.shared.clearLogs()
        refreshTrigger = UUID() // same here
    }

    private func exportLogs() {
        let logsToExport = filteredLogs
            .map { "[\($0.timestamp)] [\($0.level.rawValue)]: \($0.message)" }
            .joined(separator: "\n")

        guard !logsToExport.isEmpty else {
            print("❌ No logs to export.")
            return
        }

        let fileName = "ProxManager_Logs.txt"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try logsToExport.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Logs written to: \(fileURL)")

            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("❌ Export failed: \(error.localizedDescription)")
            Logger.shared.log("❌ Export error: \(error.localizedDescription)")
        }
    }

}

#if DEBUG
struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LogsView()
        }
    }
}
#endif
