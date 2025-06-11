//
//  QemuViewModel.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 15/03/2025.
//

import Combine
import SwiftUI
import Foundation

class QemuViewModel: ObservableObject {
//    @ObservedObject private var nodeViewModel = NodeViewModel() // 🔹 Ensure we fetch nodes

    private var cancellables = Set<AnyCancellable>()

    @Published var vms: [VM] = [] {
        didSet {
            Logger.shared.log("🚀 QemuViewModel: @Published var vms: [VM] didSet.", level: .debug)
        }
    }

    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var vmOperationInProgress: [Int: Bool] = [:]

    @AppStorage("hideOfflineResources") var hideOfflineResources: Bool = false
    @AppStorage("hideStoppedResources") var hideStoppedResources: Bool = false
    @AppStorage("vmSortOption") private var vmSortOption: String = "name"

    // Constructor adds this object as an observer to the notification center
    init() {
        Logger.shared.log("🚀 QemuViewModel init(): Initializing QemuViewModel instance: \(self)", level: .info)
        ProxmoxDataStore.shared.$vms
            .assign(to: &$vms)  // 🔄 Automatically updates when `ProxmoxDataStore.vms` changes

        NotificationCenter.default.addObserver(self, selector: #selector(updateSorting), name: UserDefaults.didChangeNotification, object: nil)
    }
    
    func refreshData() {
        ProxmoxDataStore.shared.fetchVMResources()  // ✅ Trigger global fetch
    }

    // Remember to remove the observer
    deinit {
        Logger.shared.log("Deinitializing QemuViewModel instance: \(self)", level: .info)
        NotificationCenter.default.removeObserver(self)
    }
    
    private func performVMOperation(endpoint: String, operation: String, vmid: Int) {
        Logger.shared.log("🔄 QemuViewModel: Attempting to perform operation: \(operation) for VM: \(vmid) with endpoint: \(endpoint)")

        // Specifying 'POST' as all these operations are post requests
        NetworkManager.shared.performRequest(endpoint: endpoint, httpMethod: "POST") { [weak self] (result: Result<TaskResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    Logger.shared.log("✅ QemuViewModel: Successfully performed operation: \(operation) for VM: \(vmid), Task ID: \(response.data)")
                case .failure(let error):
                    Logger.shared.log("❌ QemuViewModel: Failed to perform operation: \(operation) for VM: \(vmid), Error: \(error.localizedDescription)")
                    self?.showError = true
                    self?.errorMessage = "❌ QemuViewModel: \(operation.capitalized) VM failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .dataCorrupted(let context):
            Logger.shared.log("❌ QemuViewModel: Data corrupted: \(context)")
        case .keyNotFound(let key, let context):
            Logger.shared.log("❌ QemuViewModel: Key '\(key.stringValue)' not found: \(context.debugDescription), codingPath: \(context.codingPath)")
        case .valueNotFound(let value, let context):
            Logger.shared.log("❌ QemuViewModel: Value '\(value)' not found: \(context.debugDescription), codingPath: \(context.codingPath)")
        case .typeMismatch(let type, let context):
            Logger.shared.log("❌ QemuViewModel: Type '\(type)' mismatch: \(context.debugDescription), codingPath: \(context.codingPath)")
        @unknown default:
            Logger.shared.log("❌ QemuViewModel: Unknown decoding error: \(error)")
        }
    }

    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Error: \(error.localizedDescription)"
            self.showError = true
            Logger.shared.log("❌ QemuViewModel: Error handling in QemuViewModel: \(self.errorMessage)")
        }
    }

    @objc private func updateSorting() {
//        objectWillChange.send()
    }
    
    // Computed properties for the UI
    var runningCount: Int { vms.filter { $0.status == "running" }.count }
    var totalCount: Int { vms.count }
    
    var totalCPUUsage: Double {
        let runningVMs = vms.filter { $0.status == "running" }
        let totalCPU = runningVMs.reduce(0.0) { sum, vm in
            if let cpu = vm.cpu, let maxcpu = vm.maxcpu {
                return sum + (Double(cpu) / Double(maxcpu) * 100)
            }
            return sum
        }
        return totalCPU / Double(max(runningVMs.count, 1))
    }
    
    var totalRAMUsage: Double {
        let runningVMs = vms.filter { $0.status == "running" }
        let totalRAM = runningVMs.reduce(0.0) { sum, vm in
            if let mem = vm.mem, let maxmem = vm.maxmem {
                return sum + (Double(mem) / Double(maxmem) * 100)
            }
            return sum
        }
        return totalRAM / Double(max(runningVMs.count, 1))
    }
    
    var sortedVMs: [VM] {
        let availableNodes = ProxmoxDataStore.shared.nodes.map { $0.node } // ✅ Directly get nodes

        var filteredVMs = vms

        // 🔹 Hide offline VMs if enabled
        if hideOfflineResources {
            let offlineNodes = ProxmoxDataStore.shared.nodes
                .filter { $0.status != "online" }
                .map { $0.node }

            filteredVMs = filteredVMs.filter { availableNodes.contains($0.node) && !offlineNodes.contains($0.node) }
        }

        // 🔹 Hide stopped VMs if enabled
        if hideStoppedResources {
            filteredVMs = filteredVMs.filter { $0.status != "stopped" }
        }

        // 🔹 Apply sorting based on user selection
        switch vmSortOption {
        case "id":
            return filteredVMs.sorted { $0.vmid < $1.vmid }
        case "status":
            return filteredVMs.sorted { $0.status.localizedCompare($1.status) == .orderedAscending }
        default: // 🔹 Case-insensitive sorting for names
            return filteredVMs.sorted { ($0.name ?? "").lowercased() < ($1.name ?? "").lowercased() }
        }
    }


}

extension QemuViewModel {
    func fetchVMIPAddress(vmid: Int, node: String) {
        let endpoint = "/api2/json/nodes/\(node)/qemu/\(vmid)/agent/network-get-interfaces"
        Logger.shared.log("🔍 Fetching IP Address for VM \(vmid) on node \(node)")
        
        NetworkManager.shared.performRequest(endpoint: endpoint, httpMethod: "GET") { [weak self] (result: Result<NetworkInterfacesResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
//                    Logger.shared.log("✅ Successfully fetched IP response: \(response)")
                    // Prioritize non-loopback interfaces and then find the first IPv4 address
                    let nonLoopbackInterfaces = response.data.result.filter { $0.name != "lo" && $0.name != "lo0" }
                    let ipv4Address = nonLoopbackInterfaces
                        .flatMap { $0.ipAddresses } // Flatten all IP addresses from non-loopback interfaces
                        .first { $0.ipAddressType == "ipv4" } // Get the first IPv4 address
                        .map { $0.ipAddress } // Extract the IP address string

                    if let index = self?.vms.firstIndex(where: { $0.vmid == vmid }) {
                        self?.vms[index].ipAddress = ipv4Address // Update the VM's IP address
                        Logger.shared.log("📌 Updated VM \(vmid) with IP: \(ipv4Address ?? "Unavailable")")

                    }
                case .failure(let error):
                    Logger.shared.log("❌ Failed to fetch VM IP Address: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func startVM(vmid: Int, node: String) {
        vmOperationInProgress[vmid] = true

        performVMOperation(endpoint: "/api2/json/nodes/\(node)/qemu/\(vmid)/status/start", operation: "start", vmid: vmid)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // Mock delay for the async operation
            self.vmOperationInProgress[vmid] = false
            // You should update the VM's actual status here if needed
            if let index = self.vms.firstIndex(where: { $0.vmid == vmid }) {
                self.vms[index].status = "running" // Update based on your logic
            }
        }

    }

    func shutdownVM(vmid: Int, node: String) {
        vmOperationInProgress[vmid] = true
        performVMOperation(endpoint: "/api2/json/nodes/\(node)/qemu/\(vmid)/status/shutdown", operation: "shutdown", vmid: vmid)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // Mock delay for the async operation
            self.vmOperationInProgress[vmid] = false
            // You should update the VM's actual status here if needed
            if let index = self.vms.firstIndex(where: { $0.vmid == vmid }) {
                self.vms[index].status = "stopped" // Update based on your logic
            }
        }

    }

    func stopVM(vmid: Int, node: String, type: String) {
        vmOperationInProgress[vmid] = true

        performVMOperation(endpoint: "/api2/json/nodes/\(node)/\(type)/\(vmid)/status/stop", operation: "stop", vmid: vmid)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // Mock delay for the async operation
            self.vmOperationInProgress[vmid] = false
            // You should update the VM's actual status here if needed
            if let index = self.vms.firstIndex(where: { $0.vmid == vmid }) {
                self.vms[index].status = "stopped" // Update based on your logic
            }
        }

    }

    func rebootVM(vmid: Int, node: String) {
        vmOperationInProgress[vmid] = true

        performVMOperation(endpoint: "/api2/json/nodes/\(node)/qemu/\(vmid)/status/reboot", operation: "reboot", vmid: vmid)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // Mock delay for the async operation
            self.vmOperationInProgress[vmid] = false
            // You should update the VM's actual status here if needed
            if let index = self.vms.firstIndex(where: { $0.vmid == vmid }) {
                self.vms[index].status = "running" // Update based on your logic
            }
        }

    }

}
