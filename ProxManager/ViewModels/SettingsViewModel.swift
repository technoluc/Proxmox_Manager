import Foundation
import SwiftUI
import Combine

class SettingsViewModel: ObservableObject {
    @Published var hideOfflineResources: Bool = UserDefaults.standard.bool(forKey: "hideOfflineResources")
    @Published var hideStoppedResources: Bool = UserDefaults.standard.bool(forKey: "hideStoppedResources")
    @Published var errorMessage: String? = nil
    
    private let logger = Logger.shared
    
    init() {
        logger.log("🚀 SettingsViewModel init(): Initializing SettingsViewModel instance: \(self)", level: .info)
        loadStoredSettings()
    }
    
    private func loadStoredSettings() {
        logger.log("🛠 SettingsViewModel: loadStoredSettings", level: .info)
        hideOfflineResources = UserDefaults.standard.bool(forKey: "hideOfflineResources")
        hideStoppedResources = UserDefaults.standard.bool(forKey: "hideStoppedResources")
    }
    
    func saveSettings() {
        logger.log("💾 Saving settings", level: .info)
        UserDefaults.standard.set(hideOfflineResources, forKey: "hideOfflineResources")
        UserDefaults.standard.set(hideStoppedResources, forKey: "hideStoppedResources")

    }
    
    // MARK: - Troubleshooting
    
    func clearAuthenticationTicket() {
        logger.log("🧹 Clearing authentication ticket", level: .info)
        UserDefaults.standard.removeObject(forKey: "pveAuthCookie")
        UserDefaults.standard.removeObject(forKey: "csrfToken")
        UserDefaults.standard.removeObject(forKey: "ticketExpiration")
        logger.log("✅ Ticket cleared manually from UserDefaults")
    }
    
    func removeHideOfflineResourcesKey() {
        logger.log("🗑 Removing hideOfflineResources key", level: .info)
        logger.log("Before remove: \(hideOfflineResources)")
        UserDefaults.standard.removeObject(forKey: "hideOfflineResources")
        hideOfflineResources = false
        logger.log("After remove: \(hideOfflineResources)")
    }
    
    func simulateTicketExpiration() {
        logger.log("🧪 Simulating ticket expiration", level: .info)
        ProxmoxAuthManager.shared.simulateTicketExpired()
        logger.log("✅ Simulated expired ticket via SettingsView")
    }
}
