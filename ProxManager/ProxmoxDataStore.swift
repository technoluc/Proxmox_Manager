//
//  ProxmoxDataStore.swift
//  ProxManager
//

import Foundation
import SwiftUI
import Combine

class ProxmoxDataStore: ObservableObject {
    static let shared = ProxmoxDataStore()
    
    private var hasFetchedData = false

    @Published var nodes: [Node] = []
    @Published var vms: [VM] = []
    @Published var containers: [VM] = []

    private let authManager = ProxmoxAuthManager.shared

    private init() {
        Logger.shared.log("🚀 ProxmoxDataStore private init(): Initializing ProxmoxDataStore instance: \(self)", level: .debug)
    }

    /// Fetch all data from Proxmox API
    func fetchData() {
        guard authManager.getAuthMethod() != .none else {
            Logger.shared.log("⚠️ ProxmoxDataStore: Skipping fetchData – not authenticated", level: .warning)
            return
        }

        guard !hasFetchedData else { return }  // ✅ Ensure it only runs once
        hasFetchedData = true

        DispatchQueue.global(qos: .userInitiated).async {
            self.fetchNodes()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.fetchVMResources()
        }
    }

    /// Fetch Nodes
    func fetchNodes() {
        let endpoint = "/api2/json/nodes"
        NetworkManager.shared.performRequest(endpoint: endpoint) { (result: Result<NodeResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.nodes = response.data
                    Logger.shared.log("✅ ProxmoxDataStore: Fetched \(response.data.count) nodes", level: .info)

                case .failure(let error):
                    Logger.shared.log("❌ ProxmoxDataStore: Failed to fetch nodes - \(error.localizedDescription)", level: .error)
                }
            }
        }
    }

    /// Fetch VMs & LXC Containers
    func fetchVMResources() {
        let endpoint = "/api2/json/cluster/resources?type=vm"
        NetworkManager.shared.performRequest(endpoint: endpoint) { (result: Result<VMResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.vms = response.data.filter { $0.type == "qemu" }
                    self.containers = response.data.filter { $0.type == "lxc" }
                    Logger.shared.log("✅ ProxmoxDataStore: Fetched \(self.vms.count) VMs and \(self.containers.count) Containers", level: .info)

                case .failure(let error):
                    Logger.shared.log("❌ ProxmoxDataStore: Failed to fetch VM resources - \(error.localizedDescription)", level: .error)
                }
            }
        }
    }
}
