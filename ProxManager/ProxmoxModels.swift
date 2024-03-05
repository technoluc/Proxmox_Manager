//
//  ProxmoxModels.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 21/02/2024.
//

import Foundation

// Represents the response structure for a request to retrieve nodes from a Proxmox cluster.
struct NodeResponse: Decodable {
    let data: [Node]
}

struct Node: Identifiable, Decodable {
    let type: String
    let node: String
    let level: String
    let id: String
    let sslFingerprint: String
    let status: String
    let mem: Int
    let maxmem: Int
    let cpu: Double
    let maxcpu: Int
    let disk: Int
    let maxdisk: Int
    let uptime: Int

    
    // New properties for node status
    var memoryUsed: Int?
    var memoryFree: Int?
    var memoryTotal: Int?
    var cpuMhz: String?
    var cpuCores: Int?
    var cpuModel: String?
    var cpuUserHz: Int?
    var cpus: Int?
    var cpuHvm: String?
    var cpuFlags: String?
    var cpuSockets: Int?
    var nodeUptime: Int?
    var nodeIdle: Double?
    var nodeCpu: Double?
    var currentKernelVersion: String?
    var bootMode: String?
    var pveVersion: String?
    var swapUsed: Int?
    var swapTotal: Int?
    var fileSystemUsed: Int?
    var fileSystemTotal: Int?
    var fileSystemFree: Int?
    var fileSystemAvail: Int?

    
    enum CodingKeys: String, CodingKey {
        case type, node, level, id, status
        case sslFingerprint = "ssl_fingerprint"
        case mem, maxmem, cpu, maxcpu, disk, maxdisk, uptime
    }
}
extension Node {
    mutating func update(with status: NodeStatus) {
        // Update the node's properties with the fetched status data
        self.memoryUsed = status.memory.used
        self.memoryFree = status.memory.free
        self.memoryTotal = status.memory.total
        self.cpuMhz = status.cpuinfo.mhz
        self.cpuCores = status.cpuinfo.cores
        self.cpuModel = status.cpuinfo.model
        self.cpuUserHz = status.cpuinfo.userHz
        self.cpus = status.cpuinfo.cpus
        self.cpuHvm = status.cpuinfo.hvm
        self.cpuFlags = status.cpuinfo.flags
        self.cpuSockets = status.cpuinfo.sockets
        self.nodeUptime = status.uptime
        self.nodeIdle = status.idle
        self.nodeCpu = status.cpu
        self.currentKernelVersion = "\(status.currentKernel.sysname) \(status.currentKernel.release)"
        self.bootMode = status.bootInfo.mode
        self.pveVersion = status.pveversion
        self.swapUsed = status.swap.used
        self.swapTotal = status.swap.total
        self.fileSystemUsed = status.rootfs.used
        self.fileSystemTotal = status.rootfs.total
        self.fileSystemFree = status.rootfs.free
        self.fileSystemAvail = status.rootfs.avail
    
    }
}


// Represents the response structure for a request to retrieve VMs from a Proxmox cluster.
struct VMResponse: Decodable {
    let data: [VM]
}

// Describes the properties of a single virtual machine or container within a Proxmox cluster.
struct VM: Identifiable, Decodable {
    let id: String
    let vmid: Int
    let name: String
    let status: String
    let node: String
    let type: String
    let disk: Int
    let cpu: Double
    let diskread: Int
    let diskwrite: Int
    let mem: Int
    let maxcpu: Int
    let maxmem: Int
    let maxdisk: Int
    let netin: Int
    let netout: Int
    let uptime: Int
    let template: Bool
    let tags: String?

    var ipAddress: String? // Add this property to store the IP address

    // Additional fields for running VMs, encapsulated in a nested struct
    struct RunningDetails: Decodable {
        let runningMachine: String?
        let runningQemu: String?
        let proxmoxSupport: [String: Bool]?
    }
    let runningDetails: RunningDetails?

    enum CodingKeys: String, CodingKey {
        case id, vmid, name, status, node, type, maxmem, cpu, disk, uptime, maxcpu, mem, maxdisk, netin, netout, diskread, diskwrite, template, tags
        case runningDetails = "running_details"
    }
}

extension VM {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        vmid = try container.decode(Int.self, forKey: .vmid)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(String.self, forKey: .status)
        node = try container.decode(String.self, forKey: .node)
        type = try container.decode(String.self, forKey: .type)
        maxmem = try container.decode(Int.self, forKey: .maxmem)
        cpu = try container.decode(Double.self, forKey: .cpu)
        disk = try container.decode(Int.self, forKey: .disk)
        uptime = try container.decode(Int.self, forKey: .uptime)
        maxcpu = try container.decode(Int.self, forKey: .maxcpu)
        mem = try container.decode(Int.self, forKey: .mem)
        maxdisk = try container.decode(Int.self, forKey: .maxdisk)
        netin = try container.decode(Int.self, forKey: .netin)
        netout = try container.decode(Int.self, forKey: .netout)
        diskread = try container.decode(Int.self, forKey: .diskread)
        diskwrite = try container.decode(Int.self, forKey: .diskwrite)
        tags = try container.decodeIfPresent(String.self, forKey: .tags)
        runningDetails = try container.decodeIfPresent(RunningDetails.self, forKey: .runningDetails)
        // Decoding the 'template' field as a number and converting it to Boolean
        let templateValue = try container.decode(Int.self, forKey: .template)
        template = templateValue != 0

    }
}


// IP Helper structs

struct NetworkInterfacesResponse: Decodable {
    let data: NetworkResult
}

struct NetworkResult: Decodable {
    let result: [NetworkInterface]
}

struct NetworkInterface: Decodable {
    let name: String
    let hardwareAddress: String
    let ipAddresses: [IPAddress]

    enum CodingKeys: String, CodingKey {
        case name
        case hardwareAddress = "hardware-address"
        case ipAddresses = "ip-addresses"
    }
}

struct IPAddress: Decodable {
    let ipAddress: String
    let ipAddressType: String
    let prefix: Int

    enum CodingKeys: String, CodingKey {
        case ipAddress = "ip-address"
        case ipAddressType = "ip-address-type"
        case prefix
    }
}

// Represents the response structure for a request to retrieve LXC container interfaces.
struct LXCNetworkInterfacesResponse: Decodable {
    let data: [LXCNetworkInterface] // This will directly map to the "data" array for LXC interfaces
}

struct LXCNetworkInterface: Decodable {
    let name: String
    let hwaddr: String?
    let inet: String?
    let inet6: String?

    enum CodingKeys: String, CodingKey {
        case name, hwaddr, inet, inet6
    }
}




// Node Status response structure.
struct NodeStatusResponse: Decodable {
    let data: NodeStatus
}

// Details about a node.
struct NodeStatus: Decodable {
    let memory: MemoryStatus
    let wait: Double
    let cpuinfo: CPUInfo
    let uptime: Int
    let idle: Double
    let cpu: Double
    let currentKernel: KernelInfo
    let kversion: String
    let bootInfo: BootInfo
    let pveversion: String
    let loadavg: [String]
    let swap: SwapStatus
    let rootfs: FileSystemStatus
    let ksm: KSMStatus

    struct MemoryStatus: Decodable {
        let used: Int
        let free: Int
        let total: Int
    }

    struct CPUInfo: Decodable {
        let mhz: String
        let cores: Int
        let model: String
        let userHz: Int?
        let cpus: Int
        let hvm: String
        let flags: String
        let sockets: Int
    }

    struct KernelInfo: Decodable {
        let sysname: String
        let release: String
        let machine: String
        let version: String
    }

    struct BootInfo: Decodable {
        let secureboot: Int?
        let mode: String
    }

    struct SwapStatus: Decodable {
        let free: Int
        let used: Int
        let total: Int
    }

    struct FileSystemStatus: Decodable {
        let total: Int
        let avail: Int
        let used: Int
        let free: Int
    }

    struct KSMStatus: Decodable {
        let shared: Int
    }
    
    enum CodingKeys: String, CodingKey {
        case memory, wait, cpuinfo, uptime, idle, cpu, currentKernel = "current-kernel", kversion, bootInfo = "boot-info", pveversion, loadavg, swap, rootfs, ksm
        
    }

    // Implement other nested structures as needed based on the JSON you provided.
}

// Extension for decoding conveniences, if necessary.



