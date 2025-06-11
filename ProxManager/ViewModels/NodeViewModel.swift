//
//  NodeViewModel.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 15/03/2025.
//

import SwiftUI
import Combine
import Foundation

class NodeViewModel: ObservableObject {
    
    @Published var nodes: [Node] = [] {
        didSet {
            DispatchQueue.main.async { // ✅ Ensure SwiftUI updates outside rendering cycle
                self.objectWillChange.send()
            }
        }
    }
    private var cancellables = Set<AnyCancellable>()
    func refreshData() {
        ProxmoxDataStore.shared.fetchNodes()  // ✅ Trigger global fetch
    }

    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    // **Persistent Sort & Filter Settings**
    @AppStorage("nodeSortOption") private var nodeSortOption: String = "name"
    @AppStorage("hideOfflineNodes") private var hideOfflineNodes: Bool = false

    private var hasFetchedNodes = false // ✅ Prevent redundant fetches

    init() {
        Logger.shared.log("Initializing NodeViewModel instance: \(self)", level: .debug)
        ProxmoxDataStore.shared.$nodes
            .assign(to: &$nodes)  // 🔄 Automatically updates when `ProxmoxDataStore.nodes` changes
        NotificationCenter.default.addObserver(self, selector: #selector(updateSorting), name: UserDefaults.didChangeNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        Logger.shared.log("🚀 Deinitializing NodeViewModel instance: \(self)", level: .info)

    }

    @objc private func updateSorting() {
//        objectWillChange.send() // 🔹 Force UI update when filter/sort changes
    }

    // **Computed Properties for Dashboard Metrics**
    var totalCPUUsage: Double {
        nodes.compactMap { $0.cpu }.reduce(0, +) * 100 // Convert to percentage
    }

    var totalRAMUsage: Double {
        let totalUsed = nodes.compactMap { $0.mem }.reduce(0, +)
        return Double(totalUsed) / 1_073_741_824 // Convert bytes to GB
    }

    var totalMaxRAM: Double {
        let totalMax = nodes.compactMap { $0.maxmem }.reduce(0, +)
        return Double(totalMax) / 1_073_741_824 // Convert bytes to GB
    }

    var totalDiskUsage: Double {
        let totalUsed = nodes.compactMap { $0.disk }.reduce(0, +)
        return Double(totalUsed) / 1_099_511_627_776 // Convert bytes to TB
    }

    var totalMaxDisk: Double {
        let totalMax = nodes.compactMap { $0.maxdisk }.reduce(0, +)
        return Double(totalMax) / 1_099_511_627_776 // Convert bytes to TB
    }

    // Computed properties for cluster-wide statistics
    var totalClusterMemory: Int {
        nodes.reduce(0) { $0 + ($1.maxmem ?? 0) }
    }
    
    var usedClusterMemory: Int {
        nodes.reduce(0) { $0 + ($1.mem ?? 0) }
    }
    
    var totalClusterCPU: Int {
        nodes.reduce(0) { $0 + ($1.maxcpu ?? 0) }
    }
    
    var usedClusterCPU: Double {
        nodes.reduce(0) { $0 + ($1.cpu ?? 0) }
    }
    
    var totalClusterStorage: Int {
        nodes.reduce(0) { $0 + ($1.maxdisk ?? 0) }
    }
    
    var usedClusterStorage: Int {
        nodes.reduce(0) { $0 + ($1.disk ?? 0) }
    }
    
    // Computed properties for node status
    var onlineCount: Int {
        nodes.filter { $0.status == "online" }.count
    }
    
    var totalCount: Int {
        nodes.count
    }
    
    // Computed properties for node performance
    var averageNodeLoad: Double {
        let onlineNodes = nodes.filter { $0.status == "online" }
        guard !onlineNodes.isEmpty else { return 0 }
        return onlineNodes.reduce(0) { $0 + ($1.cpu ?? 0) } / Double(onlineNodes.count)
    }
    
    var averageMemoryUsage: Double {
        let onlineNodes = nodes.filter { $0.status == "online" }
        guard !onlineNodes.isEmpty else { return 0 }
        return onlineNodes.reduce(0) { $0 + (Double($1.mem ?? 0) / Double($1.maxmem ?? 1)) } / Double(onlineNodes.count)
    }
    
    var averageStorageUsage: Double {
        let onlineNodes = nodes.filter { $0.status == "online" }
        guard !onlineNodes.isEmpty else { return 0 }
        return onlineNodes.reduce(0) { $0 + (Double($1.disk ?? 0) / Double($1.maxdisk ?? 1)) } / Double(onlineNodes.count)
    }

    // **Filtering: Hide Offline Nodes if Enabled**
    var filteredNodes: [Node] {
        if hideOfflineNodes {
            return nodes.filter { $0.status == "online" }
        }
        return nodes
    }

    // **Sorting: Apply Sorting After Filtering**
    var sortedNodes: [Node] {
        switch nodeSortOption {
        case "id":
            return filteredNodes.sorted { $0.id < $1.id }
        case "status":
            return filteredNodes.sorted { $0.status.localizedCompare($1.status) == .orderedDescending }
        default: // Case-insensitive sorting for names
            return filteredNodes.sorted { $0.node.lowercased() < $1.node.lowercased() }
        }
    }


    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Error: \(error.localizedDescription)"
            self.showError = true
            Logger.shared.log("❌ NodeViewModel: Error handling nodes: \(self.errorMessage)", level: .error)
        }
    }
}
extension NodeViewModel {
    func fetchNodeStatus(node: String) {
        let endpoint = "/api2/json/nodes/\(node)/status"
        NetworkManager.shared.performRequest(endpoint: endpoint, httpMethod: "GET") { [weak self] (result: Result<NodeStatusResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    Logger.shared.log("NodeViewModel: Successfully fetched node status for \(node)", level: .info)
                    if let index = self?.nodes.firstIndex(where: { $0.node == node }) {
                        self?.nodes[index].update(with: response.data)
                    }
                case .failure(let error):
                    Logger.shared.log("❌ NodeViewModel: Failed to fetch status for node \(node): \(error.localizedDescription)", level: .error)
                    self?.handleError(error)
                }
            }
        }
    }
    
    func rebootNode(node: String) {
        let endpoint = "/api2/json/nodes/\(node)/status/reboot"
        NetworkManager.shared.performRequest(endpoint: endpoint, httpMethod: "POST") { (result: Result<String, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    Logger.shared.log("✅ Successfully rebooted node: \(node)", level: .info)
                case .failure(let error):
                    self.handleError(error)
                    Logger.shared.log("❌ Failed to reboot node \(node): \(error.localizedDescription)", level: .error)
                }
            }
        }
    }

    
    func shutdownNode(node: String) {
        let endpoint = "/api2/json/nodes/\(node)/status/shutdown"
        NetworkManager.shared.performRequest(endpoint: endpoint, httpMethod: "POST") { (result: Result<String, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    Logger.shared.log("✅ Successfully shut down node: \(node)", level: .info)
                case .failure(let error):
                    self.handleError(error)
                    Logger.shared.log("❌ Failed to shut down node \(node): \(error.localizedDescription)", level: .error)
                }
            }
        }
    }

    
    func shutdownCluster() {
        Logger.shared.log("⚠️ Initiating cluster shutdown...", level: .info)

        for node in nodes {
            shutdownNode(node: node.node) // Send shutdown to each node
        }
    }

}
