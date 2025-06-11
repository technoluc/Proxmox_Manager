//
//  ProxManagerApp.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 21/02/2024.
//

import Foundation
import SwiftUI
import Combine

@main
struct ProxManagerApp: App {
    @StateObject private var nodeViewModel = NodeViewModel()
    @StateObject private var qemuViewModel = QemuViewModel()
    @StateObject private var lxcViewModel = LxcViewModel()

    init() {
        Logger.shared.clearLogs()
        Logger.shared.log("🚀Logger.shared.clearLogs, ProxmoxAuthManager.shared.refreshAuthenticationIfNeeded, ProxmoxDataStore.shared.fetchData", level: .info)
        Task {
            do {
                try await ProxmoxAuthManager.shared.refreshAuthenticationIfNeeded()
                ProxmoxDataStore.shared.fetchData()
            } catch {
                Logger.shared.log("❌ Failed to refresh auth on launch: \(error)", level: .error)
            }
        }
    }
    
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(nodeViewModel)
                .environmentObject(qemuViewModel)
                .environmentObject(lxcViewModel)
        }
    }
}
