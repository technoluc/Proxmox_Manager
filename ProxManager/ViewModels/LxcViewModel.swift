//
//  LxcViewModel.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 15/03/2025.
//

import SwiftUI
import Combine
import Foundation

class LxcViewModel: ObservableObject {
    
    private var cancellables = Set<AnyCancellable>()

    @Published var containers: [VM] = [] {
        didSet {
            Logger.shared.log("🚀 LxcViewModel: @Published var containers: [VM] didSet.", level: .debug)
        }
    }
    
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var vmOperationInProgress: [Int: Bool] = [:]

    @AppStorage("hideOfflineResources") var hideOfflineResources: Bool = false
    @AppStorage("hideStoppedResources") var hideStoppedResources: Bool = false
    @AppStorage("lxcSortOption") private var lxcSortOption: String = "name"
    
    init() {
        ProxmoxDataStore.shared.$containers
            .assign(to: &$containers)  // 🔄 Automatically updates when `ProxmoxDataStore.containers` changes

        Logger.shared.log("🚀 LxcViewModel init(): Initializing LxcViewModel instance: \(self)", level: .info)
        NotificationCenter.default.addObserver(self, selector: #selector(updateSorting), name: UserDefaults.didChangeNotification, object: nil)
    }
    func refreshData() {
        ProxmoxDataStore.shared.fetchVMResources()  // ✅ Trigger global fetch
    }

    deinit {
        Logger.shared.log("Deinitializing LxcViewModel instance: \(self)", level: .info)
        NotificationCenter.default.removeObserver(self)
    }

    private func performVMOperation(endpoint: String, operation: String, vmid: Int) {
        Logger.shared.log("🔄 LxcViewModel: Attempting to perform operation: \(operation) for LXC: \(vmid) with endpoint: \(endpoint)", level: .debug)

        // Specifying 'POST' as all these operations are post requests
        NetworkManager.shared.performRequest(endpoint: endpoint, httpMethod: "POST") { [weak self] (result: Result<TaskResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    Logger.shared.log("✅ LxcViewModel: Successfully performed operation: \(operation) for LXC: \(vmid), Task ID: \(response.data)", level: .info)
                case .failure(let error):
                    Logger.shared.log("❌ LxcViewModel: Failed to perform operation: \(operation) for LXC: \(vmid), Error: \(error.localizedDescription)", level: .error)
                    self?.showError = true
                    self?.errorMessage = "❌ LxcViewModel: \(operation.capitalized) LXC failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .dataCorrupted(let context):
            Logger.shared.log("❌ LxcViewModel: Data corrupted: \(context)", level: .error)
            
        case .keyNotFound(let key, let context):
            Logger.shared.log("❌ LxcViewModel: Key '\(key.stringValue)' not found: \(context.debugDescription), codingPath: \(context.codingPath)", level: .error)
            
        case .valueNotFound(let value, let context):
            Logger.shared.log("❌ LxcViewModel: Value '\(value)' not found: \(context.debugDescription), codingPath: \(context.codingPath)", level: .error)
            
        case .typeMismatch(let type, let context):
            Logger.shared.log("❌ LxcViewModel: Type '\(type)' mismatch: \(context.debugDescription), codingPath: \(context.codingPath)", level: .error)
            
        @unknown default:
            Logger.shared.log("❌ LxcViewModel: Unknown decoding error: \(error)", level: .error)
            
        }
    }

    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Error: \(error.localizedDescription)"
            self.showError = true
            Logger.shared.log("❌ LxcViewModel: Error handling LXC containers: \(self.errorMessage)", level: .error)
        }
    }
    
    @objc private func updateSorting() {
//            self.objectWillChange.send() // 🔹 Ensure UI refresh when sorting changes
    }

    // Computed properties for the UI
    var runningCount: Int { containers.filter { $0.status == "running" }.count }
    var totalCount: Int { containers.count }
    
    var totalCPUUsage: Double {
        let runningContainers = containers.filter { $0.status == "running" }
        guard !runningContainers.isEmpty else { return 0 }
        
        let totalCPU = runningContainers.reduce(0.0) { sum, container in
            if let lxcStatus = container.lxcStatus, let cpus = lxcStatus.cpus {
                return sum + cpus
            }
            return sum
        }
        
        return totalCPU / Double(runningContainers.count)
    }
    
    var totalRAMUsage: Double {
        let runningContainers = containers.filter { $0.status == "running" }
        guard !runningContainers.isEmpty else { return 0 }
        
        let totalRAM = runningContainers.reduce(0.0) { sum, container in
            if let lxcStatus = container.lxcStatus, let memory = lxcStatus.memory {
                return sum + (Double(memory.used) / Double(memory.total))
            }
            return sum
        }
        
        return (totalRAM / Double(runningContainers.count)) * 100
    }

    var sortedContainers: [VM] {
        let availableNodes = ProxmoxDataStore.shared.nodes.map { $0.node } // ✅ Directly get nodes

        var filteredContainers = containers

        if hideOfflineResources {
            let offlineNodes = ProxmoxDataStore.shared.nodes
                .filter { $0.status != "online" }
                .map { $0.node }

            filteredContainers = filteredContainers.filter { availableNodes.contains($0.node) && !offlineNodes.contains($0.node) }
        }

        // 🔹 Hide stopped containers if enabled
        if hideStoppedResources {
            filteredContainers = filteredContainers.filter { $0.status != "stopped" }
        }

        // Apply sorting based on user selection
        switch lxcSortOption {
        case "id":
            return filteredContainers.sorted { $0.vmid < $1.vmid }
        case "status":
            return filteredContainers.sorted { $0.status.localizedCompare($1.status) == .orderedAscending }
        default: // Case-insensitive sorting for names
            return filteredContainers.sorted { ($0.name ?? "").lowercased() < ($1.name ?? "").lowercased() }
        }
    }

}

// MARK - extensions
extension LxcViewModel {
    func fetchContainerIPAddress(vmid: Int, node: String) {
        let endpoint = "/api2/json/nodes/\(node)/lxc/\(vmid)/interfaces"
        
        NetworkManager.shared.performRequest(endpoint: endpoint, httpMethod: "GET") { [weak self] (result: Result<LXCNetworkInterfacesResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
//                    Logger.shared.log("extension LxcViewModel: ✅ Successfully fetched LXC IP response: \(response)")

                    // 1️⃣ **Prioritize `eth0` first**
                    let mainInterface = response.data.first(where: { $0.name == "eth0" })
                    
                    // 2️⃣ **If `eth0` not found, pick first available valid interface**
                    let alternativeInterface = response.data.first(where: {
                        $0.name != "lo" && !$0.name.starts(with: "br-") && !$0.name.starts(with: "docker")
                    })

                    // 3️⃣ **Extract the IPv4 address from the chosen interface**
                    let ipv4Address = (mainInterface ?? alternativeInterface)?
                        .inet?
                        .components(separatedBy: "/")
                        .first
                    
                    // 4️⃣ **Update the VM model**
                    if let index = self?.containers.firstIndex(where: { $0.vmid == vmid }) {
//                        Logger.shared.log("🔍 Before update: \(String(describing: self?.containers[index]))")

                        var updatedContainers = self?.containers ?? []  // Copy the array
                        updatedContainers[index].ipAddress = ipv4Address  // Modify struct ✅

                        self?.containers = updatedContainers  // ✅ Replace the whole array

                        self?.objectWillChange.send()  // ✅ Force UI refresh

                        Logger.shared.log("📌 Updated LXC \(vmid) with IP: \(ipv4Address ?? "Unavailable")", level: .info)
                    }

                case .failure(let error):
                    Logger.shared.log("❌ Failed to fetch IP Address: \(error.localizedDescription)", level: .error)
                }
            }
        }
    }
    
    // VM Operations
    func startVM(vmid: Int, node: String) {
        vmOperationInProgress[vmid] = true
        
        let endpoint = "/api2/json/nodes/\(node)/lxc/\(vmid)/status/start"

        performVMOperation(endpoint: endpoint, operation: "start", vmid: vmid)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // Mock delay for the async operation
            self.vmOperationInProgress[vmid] = false
            // You should update the VM's actual status here if needed
            if let index = self.containers.firstIndex(where: { $0.vmid == vmid }) {
                self.containers[index].status = "running" // Update based on your logic
            }
        }

    }
    
    func stopVM(vmid: Int, node: String) {
        vmOperationInProgress[vmid] = true
        
        let endpoint = "/api2/json/nodes/\(node)/lxc/\(vmid)/status/stop"

        performVMOperation(endpoint: endpoint, operation: "stop", vmid: vmid)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // Mock delay for the async operation
            self.vmOperationInProgress[vmid] = false
            // You should update the VM's actual status here if needed
            if let index = self.containers.firstIndex(where: { $0.vmid == vmid }) {
                self.containers[index].status = "stopped" // Update based on your logic
            }
        }

    }

    func shutdownVM(vmid: Int, node: String) {
        vmOperationInProgress[vmid] = true
        
        let endpoint = "/api2/json/nodes/\(node)/lxc/\(vmid)/status/shutdown"

        performVMOperation(endpoint: endpoint, operation: "shutdown", vmid: vmid)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // Mock delay for the async operation
            self.vmOperationInProgress[vmid] = false
            // You should update the VM's actual status here if needed
            if let index = self.containers.firstIndex(where: { $0.vmid == vmid }) {
                self.containers[index].status = "stopped" // Update based on your logic
            }
        }

    }

    func rebootVM(vmid: Int, node: String) {
        vmOperationInProgress[vmid] = true
        
        let endpoint = "/api2/json/nodes/\(node)/lxc/\(vmid)/status/reboot"

        performVMOperation(endpoint: endpoint, operation: "reboot", vmid: vmid)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // Mock delay for the async operation
            self.vmOperationInProgress[vmid] = false
            // You should update the VM's actual status here if needed
            if let index = self.containers.firstIndex(where: { $0.vmid == vmid }) {
                self.containers[index].status = "stopped" // Update based on your logic
            }
        }

    }
}
