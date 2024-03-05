//
//  ProxmoxViewModels.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 21/02/2024.
//

import Foundation


// MARK: NodeViewModel

class NodeViewModel: ObservableObject {
    
    @Published var nodes: [Node] = []
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private var apiAddress: String? { UserDefaults.standard.string(forKey: "apiAddress") }
    private var apiID: String? { UserDefaults.standard.string(forKey: "apiID") }
    private var apiKey: String? { UserDefaults.standard.string(forKey: "apiKey") }
    private var useHTTPS: Bool { UserDefaults.standard.bool(forKey: "useHTTPS") }

    init() {
        fetchNodes()
    }

    func fetchNodes() {
        let endpoint = "/api2/json/nodes"
        print("NodeViewModel: Fetching nodes with endpoint: \(endpoint)")

        NetworkManager.shared.performRequest(endpoint: endpoint, apiAddress: apiAddress, apiID: apiID, apiKey: apiKey, useHTTPS: useHTTPS, httpMethod: "GET") { [weak self] (result: Result<NodeResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("NodeViewModel: Successfully fetched nodes")
                    self?.nodes = response.data.sorted { $0.node < $1.node }
                case .failure(let error):
                    print("NodeViewModel: Failed to fetch nodes: \(error.localizedDescription)")
                    self?.handleError(error)
                }
            }
        }
    }

    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Error: \(error.localizedDescription)"
            self.showError = true
            print("NodeViewModel: Error handling nodes: \(self.errorMessage)")
        }
    }
}
// MARK: - NodeViewModel Extensions

extension NodeViewModel {
    func fetchNodeStatus(node: String) {
        let endpoint = "/api2/json/nodes/\(node)/status"
//        let endpoint = "/api2/json/nodes/\(nodeName)/status"
        NetworkManager.shared.performRequest(endpoint: endpoint, apiAddress: apiAddress, apiID: apiID, apiKey: apiKey, useHTTPS: useHTTPS, httpMethod: "GET") { [weak self] (result: Result<NodeStatusResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("NodeViewModel: Successfully fetched node status for \(node)")
                    if let index = self?.nodes.firstIndex(where: { $0.node == node }) {
                        self?.nodes[index].update(with: response.data)
                    }
                case .failure(let error):
                    print("NodeViewModel: Failed to fetch status for node \(node): \(error.localizedDescription)")
                    self?.handleError(error)
                }
            }
        }
    }
}


// MARK: QemuViewModel

class QemuViewModel: ObservableObject {
    @Published var vms: [VM] = []
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private var apiAddress: String? { UserDefaults.standard.string(forKey: "apiAddress") }
    private var apiID: String? { UserDefaults.standard.string(forKey: "apiID") }
    private var apiKey: String? { UserDefaults.standard.string(forKey: "apiKey") }
    private var useHTTPS: Bool { UserDefaults.standard.bool(forKey: "useHTTPS") }

    init() {
        fetchVMs()
    }

    func fetchVMs() {
        let endpoint = "/api2/json/cluster/resources?type=vm"
         print("QemuViewModel: Fetching VMs with endpoint: \(endpoint)")

        NetworkManager.shared.performRequest(endpoint: endpoint, apiAddress: apiAddress, apiID: apiID, apiKey: apiKey, useHTTPS: useHTTPS, httpMethod: "GET") { [weak self] (result: Result<VMResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // print("Successfully fetched VMs")
                    self?.vms = response.data.filter { $0.type == "qemu" }.sorted { $0.name < $1.name }
                case .failure(let error):
                    print("QemuViewModel: Failed to fetch VMs: \(error.localizedDescription)")
                    if let decodingError = error as? DecodingError {
                        self?.logDecodingError(decodingError)
                    }
                    self?.handleError(error)
                }
            }
        }
    }

    func startVM(vmid: Int, node: String) {
        performVMOperation(endpoint: "/api2/json/nodes/\(node)/qemu/\(vmid)/status/start", operation: "start", vmid: vmid)
    }

    func shutdownVM(vmid: Int, node: String) {
        performVMOperation(endpoint: "/api2/json/nodes/\(node)/qemu/\(vmid)/status/shutdown", operation: "shutdown", vmid: vmid)
    }

    func stopVM(vmid: Int, node: String, type: String) {
        performVMOperation(endpoint: "/api2/json/nodes/\(node)/\(type)/\(vmid)/status/stop", operation: "stop", vmid: vmid)
    }

    func rebootVM(vmid: Int, node: String) {
        performVMOperation(endpoint: "/api2/json/nodes/\(node)/qemu/\(vmid)/status/reboot", operation: "reboot", vmid: vmid)
    }

    private func performVMOperation(endpoint: String, operation: String, vmid: Int) {
        print("QemuViewModel: Attempting to \(operation) VM: \(vmid) with endpoint: \(endpoint)")

        // Specifying 'POST' as all these operations are post requests
        NetworkManager.shared.performRequest(endpoint: endpoint, apiAddress: apiAddress, apiID: apiID, apiKey: apiKey, useHTTPS: useHTTPS, httpMethod: "POST") { [weak self] (result: Result<TaskResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("QemuViewModel: Successfully \(operation)ed VM: \(vmid), Task ID: \(response.data)")
                    self?.fetchVMs()  // Refresh VM list after operation
                case .failure(let error):
                    print("QemuViewModel: Failed to \(operation) VM: \(vmid), Error: \(error.localizedDescription)")
                    self?.showError = true
                    self?.errorMessage = "QemuViewModel: \(operation.capitalized) VM failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .dataCorrupted(let context):
            print("QemuViewModel: Data corrupted: \(context)")
        case .keyNotFound(let key, let context):
            print("QemuViewModel: Key '\(key.stringValue)' not found: \(context.debugDescription), codingPath: \(context.codingPath)")
        case .valueNotFound(let value, let context):
            print("QemuViewModel: Value '\(value)' not found: \(context.debugDescription), codingPath: \(context.codingPath)")
        case .typeMismatch(let type, let context):
            print("QemuViewModel: Type '\(type)' mismatch: \(context.debugDescription), codingPath: \(context.codingPath)")
        @unknown default:
            print("QemuViewModel: Unknown decoding error: \(error)")
        }
    }

    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Error: \(error.localizedDescription)"
            self.showError = true
            print("QemuViewModel: Error handling in QemuViewModel: \(self.errorMessage)")
        }
    }
}

struct TaskResponse: Decodable {
    let data: String  // Assuming 'data' contains the UPID string
}
extension QemuViewModel {
    func fetchVMIPAddress(vmid: Int, node: String) {
        let endpoint = "/api2/json/nodes/\(node)/qemu/\(vmid)/agent/network-get-interfaces"
        NetworkManager.shared.performRequest(endpoint: endpoint, apiAddress: apiAddress, apiID: apiID, apiKey: apiKey, useHTTPS: useHTTPS, httpMethod: "GET") { [weak self] (result: Result<NetworkInterfacesResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Prioritize non-loopback interfaces and then find the first IPv4 address
                    let nonLoopbackInterfaces = response.data.result.filter { $0.name != "lo" && $0.name != "lo0" }
                    let ipv4Address = nonLoopbackInterfaces
                        .flatMap { $0.ipAddresses } // Flatten all IP addresses from non-loopback interfaces
                        .first { $0.ipAddressType == "ipv4" } // Get the first IPv4 address
                        .map { $0.ipAddress } // Extract the IP address string

                    if let index = self?.vms.firstIndex(where: { $0.vmid == vmid }) {
                        self?.vms[index].ipAddress = ipv4Address // Update the VM's IP address
                    }
                case .failure(let error):
                    print("Failed to fetch VM IP Address: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: LxcViewModel

class LxcViewModel: ObservableObject {
    @Published var containers: [VM] = [] // Assuming LXC containers are represented using the VM structure.
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private var apiAddress: String? { UserDefaults.standard.string(forKey: "apiAddress") }
    private var apiID: String? { UserDefaults.standard.string(forKey: "apiID") }
    private var apiKey: String? { UserDefaults.standard.string(forKey: "apiKey") }
    private var useHTTPS: Bool { UserDefaults.standard.bool(forKey: "useHTTPS") }

    init() {
        fetchContainers()
    }

    func fetchContainers() {
        let endpoint = "/api2/json/cluster/resources?type=vm"
        print("LxcViewModel: Fetching LXC containers with endpoint: \(endpoint)")

        NetworkManager.shared.performRequest(endpoint: endpoint, apiAddress: apiAddress, apiID: apiID, apiKey: apiKey, useHTTPS: useHTTPS, httpMethod: "GET") { [weak self] (result: Result<VMResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("LxcViewModel:  Successfully fetched LXC containers")
                    self?.containers = response.data.filter { $0.type == "lxc" }.sorted { $0.name < $1.name }
                case .failure(let error):
                    print("LxcViewModel:  Failed to fetch Containers: \(error.localizedDescription)")
                        if let decodingError = error as? DecodingError {
                            self?.logDecodingError(decodingError)
                        }
                    self?.handleError(error)
                }
            }
        }
    }

    func startVM(vmid: Int, node: String) {
        let endpoint = "/api2/json/nodes/\(node)/lxc/\(vmid)/status/start"
        performVMOperation(endpoint: endpoint)
    }

    func stopVM(vmid: Int, node: String) {
        let endpoint = "/api2/json/nodes/\(node)/lxc/\(vmid)/status/stop"
        performVMOperation(endpoint: endpoint)
    }

    func shutdownVM(vmid: Int, node: String) {
        let endpoint = "/api2/json/nodes/\(node)/lxc/\(vmid)/status/shutdown"
        performVMOperation(endpoint: endpoint)
    }

    func rebootVM(vmid: Int, node: String) {
        let endpoint = "/api2/json/nodes/\(node)/lxc/\(vmid)/status/reboot"
        performVMOperation(endpoint: endpoint)
    }

    private func performVMOperation(endpoint: String) {
        NetworkManager.shared.performRequest(endpoint: endpoint, apiAddress: apiAddress, apiID: apiID, apiKey: apiKey, useHTTPS: useHTTPS, httpMethod: "POST") { [weak self] (result: Result<TaskResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
//                case .success(_):
                case .success:
                    print("LxcViewModel:  Successfully performed operation for endpoint: \(endpoint)")
                    // Optionally update the state or UI after the operation.
                case .failure(let error):
                    print("LxcViewModel:  Failed to perform operation for endpoint: \(endpoint), Error: \(error.localizedDescription)")
                    self?.handleError(error)
                }
            }
        }
    }

    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .dataCorrupted(let context):
            print("LxcViewModel: Data corrupted: \(context)")
        case .keyNotFound(let key, let context):
            print("LxcViewModel: Key '\(key.stringValue)' not found: \(context.debugDescription), codingPath: \(context.codingPath)")
        case .valueNotFound(let value, let context):
            print("LxcViewModel: Value '\(value)' not found: \(context.debugDescription), codingPath: \(context.codingPath)")
        case .typeMismatch(let type, let context):
            print("LxcViewModel: Type '\(type)' mismatch: \(context.debugDescription), codingPath: \(context.codingPath)")
        @unknown default:
            print("LxcViewModel: Unknown decoding error: \(error)")
        }
    }

    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Error: \(error.localizedDescription)"
            self.showError = true
            print("LxcViewModel: Error handling LXC containers: \(self.errorMessage)")
        }
    }
}
extension LxcViewModel {
    func fetchContainerIPAddress(vmid: Int, node: String) {
        let endpoint = "/api2/json/nodes/\(node)/lxc/\(vmid)/interfaces"
        NetworkManager.shared.performRequest(endpoint: endpoint, apiAddress: apiAddress, apiID: apiID, apiKey: apiKey, useHTTPS: useHTTPS, httpMethod: "GET") { [weak self] (result: Result<LXCNetworkInterfacesResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let ipv4Address = response.data
                        .filter { $0.name != "lo" && $0.hwaddr != nil } // Exclude loopback and interfaces without a hardware address
                        .compactMap { $0.inet }
                        .first
                        .flatMap { $0.components(separatedBy: "/").first } // Split the string and take only the IP part
                    if let index = self?.containers.firstIndex(where: { $0.vmid == vmid }) {
                        self?.containers[index].ipAddress = ipv4Address
                    }
                case .failure(let error):
                    print("Failed to fetch Container IP Address: \(error.localizedDescription)")
                }
            }
        }
    }
}
