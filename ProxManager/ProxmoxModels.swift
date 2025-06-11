//
//  ProxmoxModels.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 21/02/2024.
//

import Foundation
import SwiftUI
import Combine

// Represents the response structure for a request to retrieve nodes from a Proxmox cluster.
struct NodeResponse: Decodable {
    let data: [Node]
}

struct Node: Identifiable, Decodable {
    let type: String
    let node: String
    let level: String?
    let id: String
    let sslFingerprint: String
    let status: String
    let mem: Int?
    let maxmem: Int?
    let cpu: Double?
    let maxcpu: Int?
    let disk: Int?
    let maxdisk: Int?
    let uptime: Int?
    
    // Status properties (updated via update method)
    private(set) var memoryUsed: Int?
    private(set) var memoryFree: Int?
    private(set) var memoryTotal: Int?
    private(set) var cpuMhz: String?
    private(set) var cpuCores: Int?
    private(set) var cpuModel: String?
    private(set) var cpuUserHz: Int?
    private(set) var cpus: Int?
    private(set) var cpuHvm: String?
    private(set) var cpuFlags: String?
    private(set) var cpuSockets: Int?
    private(set) var nodeUptime: Int?
    private(set) var nodeIdle: Double?
    private(set) var nodeCpu: Double?
    private(set) var currentKernelVersion: String?
    private(set) var bootMode: String?
    private(set) var pveVersion: String?
    private(set) var swapUsed: Int?
    private(set) var swapTotal: Int?
    private(set) var fileSystemUsed: Int?
    private(set) var fileSystemTotal: Int?
    private(set) var fileSystemFree: Int?
    private(set) var fileSystemAvail: Int?
    private(set) var loadAvg: [String]?
    
    enum CodingKeys: String, CodingKey {
        case type, node, level, id, status
        case sslFingerprint = "ssl_fingerprint"
        case mem, maxmem, cpu, maxcpu, disk, maxdisk, uptime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        node = try container.decode(String.self, forKey: .node)
        level = try container.decodeIfPresent(String.self, forKey: .level)
        id = try container.decode(String.self, forKey: .id)
        sslFingerprint = try container.decode(String.self, forKey: .sslFingerprint)
        status = try container.decode(String.self, forKey: .status)
        mem = try container.decodeIfPresent(Int.self, forKey: .mem)
        maxmem = try container.decodeIfPresent(Int.self, forKey: .maxmem)
        cpu = try container.decodeIfPresent(Double.self, forKey: .cpu)
        maxcpu = try container.decodeIfPresent(Int.self, forKey: .maxcpu)
        disk = try container.decodeIfPresent(Int.self, forKey: .disk)
        maxdisk = try container.decodeIfPresent(Int.self, forKey: .maxdisk)
        uptime = try container.decodeIfPresent(Int.self, forKey: .uptime)
    }
}

extension Node {
    mutating func update(with status: NodeStatus) {
        // Update the node's properties with the fetched status data
        memoryUsed = status.memory.used
        memoryFree = status.memory.free
        memoryTotal = status.memory.total
        cpuMhz = status.cpuinfo.mhz
        cpuCores = status.cpuinfo.cores
        cpuModel = status.cpuinfo.model
        cpuUserHz = status.cpuinfo.userHz
        cpus = status.cpuinfo.cpus
        cpuHvm = status.cpuinfo.hvm
        cpuFlags = status.cpuinfo.flags
        cpuSockets = status.cpuinfo.sockets
        nodeUptime = status.uptime
        nodeIdle = status.idle
        nodeCpu = status.cpu
        currentKernelVersion = "\(status.currentKernel.sysname) \(status.currentKernel.release)"
        bootMode = status.bootInfo.mode
        pveVersion = status.pveversion
        swapUsed = status.swap.used
        swapTotal = status.swap.total
        fileSystemUsed = status.rootfs.used
        fileSystemTotal = status.rootfs.total
        fileSystemFree = status.rootfs.free
        fileSystemAvail = status.rootfs.avail
        loadAvg = status.loadavg
    }
}

// MARK: - Node Status Models
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
    
    enum CodingKeys: String, CodingKey {
        case memory, wait, cpuinfo, uptime, idle, cpu
        case currentKernel = "current-kernel"
        case kversion, bootInfo = "boot-info"
        case pveversion, loadavg, swap, rootfs, ksm
    }
}

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

// Represents the response structure for a request to retrieve VMs from a Proxmox cluster.
struct VMResponse: Decodable {
    let data: [VM]
}

// Describes the properties of a single virtual machine or container within a Proxmox cluster.
struct VM: Identifiable, Decodable {
    let id: String
    let vmid: Int
    let name: String?
    var status: String
    let node: String
    let type: String
    let disk: Int?
    let cpu: Double?
    let diskread: Int?
    let diskwrite: Int?
    let mem: Int?
    let maxcpu: Int?
    let maxmem: Int?
    let maxdisk: Int?
    let netin: Int?
    let netout: Int?
    let uptime: Int?
    let template: Bool
    let tags: String?
    var ipAddress: String?

    // Additional fields for running VMs, encapsulated in a nested struct
    struct RunningDetails: Decodable {
        let runningMachine: String?
        let runningQemu: String?
        let proxmoxSupport: [String: Bool]?
    }
    let runningDetails: RunningDetails?

    // New fields for VM status
    var balloonInfo: BalloonInfo?
    var blockStats: [String: BlockStats]?
    var networkInterfaces: [String: NetworkInterface]?
    var haStatus: HAStatus?

    // LXC specific fields
    var lxcConfig: LXCConfig?
    var lxcStatus: LXCStatus?

    // QEMU specific fields
    var qemuStatus: QEMUStatus?

    struct BalloonInfo: Decodable {
        let memSwappedIn: Int
        let totalMem: Int
        let memSwappedOut: Int
        let maxMem: Int
        let majorPageFaults: Int
        let actual: Int
        let minorPageFaults: Int
        let lastUpdate: Int
        let freeMem: Int
    }

    struct BlockStats: Decodable {
        let rdBytes: Int
        let wrBytes: Int
        let rdOperations: Int
        let wrOperations: Int
        let flushOperations: Int
    }

    struct HAStatus: Decodable {
        let managed: Int
    }

    // LXC specific structures
    struct LXCConfig: Decodable {
        let hostname: String?
        let memory: Int?
        let swap: Int?
        let rootfs: String?
        let net0: String?
        let ostype: String?
        let arch: String?
        let features: [String: String]?
        let nameserver: String?
        let searchdomain: String?
    }

    struct LXCStatus: Decodable {
        let status: String
        var cpus: Double?
        var memory: MemoryStatus?
        var swap: SwapStatus?
        var disk: DiskStatus?
        var uptime: Int?
        var network: NetworkStatus?

        struct MemoryStatus: Decodable {
            let used: Int
            let total: Int
        }

        struct SwapStatus: Decodable {
            let used: Int
            let total: Int
        }

        struct DiskStatus: Decodable {
            let used: Int
            let total: Int
        }

        struct NetworkStatus: Decodable {
            let netin: Int
            let netout: Int
        }
    }

    struct QEMUStatus: Decodable {
        let disk: DiskStatus?
        let memory: MemoryStatus?
        let cpus: Double?
        let uptime: Int?

        struct DiskStatus: Decodable {
            let used: Int
            let total: Int
        }

        struct MemoryStatus: Decodable {
            let used: Int
            let total: Int
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, vmid, name, status, node, type, maxmem, cpu, disk, uptime, maxcpu, mem, maxdisk, netin, netout, diskread, diskwrite, template, tags
        case runningDetails = "running_details"
        case balloonInfo = "ballooninfo"
        case blockStats = "blockstat"
        case networkInterfaces = "nics"
        case haStatus = "ha"
        case lxcConfig = "lxc_config"
        case lxcStatus = "lxc_status"
        case qemuStatus = "qemu_status"
    }
}

extension VM {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        vmid = try container.decode(Int.self, forKey: .vmid)
        name = try? container.decode(String.self, forKey: .name)
        status = try container.decode(String.self, forKey: .status)
        node = try container.decode(String.self, forKey: .node)
        type = try container.decode(String.self, forKey: .type)
        maxmem = try? container.decode(Int.self, forKey: .maxmem)
        cpu = try? container.decode(Double.self, forKey: .cpu)
        disk = try? container.decode(Int.self, forKey: .disk)
        uptime = try? container.decode(Int.self, forKey: .uptime)
        maxcpu = try? container.decode(Int.self, forKey: .maxcpu)
        mem = try? container.decode(Int.self, forKey: .mem)
        maxdisk = try? container.decode(Int.self, forKey: .maxdisk)
        netin = try? container.decode(Int.self, forKey: .netin)
        netout = try? container.decode(Int.self, forKey: .netout)
        diskread = try? container.decode(Int.self, forKey: .diskread)
        diskwrite = try? container.decode(Int.self, forKey: .diskwrite)
        tags = try? container.decodeIfPresent(String.self, forKey: .tags)
        runningDetails = try? container.decodeIfPresent(RunningDetails.self, forKey: .runningDetails)
        let templateValue = try? container.decodeIfPresent(Int.self, forKey: .template)
        template = (templateValue ?? 0) != 0
        
        // Decode LXC specific fields
        lxcConfig = try? container.decodeIfPresent(LXCConfig.self, forKey: .lxcConfig)
        
        // Handle LXC status data - try both nested and root level
        if type == "lxc" {
            // First try to get nested lxc_status
            if let nestedStatus = try? container.decodeIfPresent(LXCStatus.self, forKey: .lxcStatus) {
                lxcStatus = nestedStatus
            } else {
                // If nested status not found, create LXCStatus from root level data
                var memoryStatus: LXCStatus.MemoryStatus?
                if let mem = mem, let maxmem = maxmem {
                    memoryStatus = LXCStatus.MemoryStatus(used: mem, total: maxmem)
                }
                
                lxcStatus = LXCStatus(
                    status: status,
                    cpus: cpu,
                    memory: memoryStatus,
                    swap: nil,
                    disk: nil,
                    uptime: uptime,
                    network: nil
                )
            }
        }
        
        // Decode QEMU specific fields
        qemuStatus = try? container.decodeIfPresent(QEMUStatus.self, forKey: .qemuStatus)
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
    let hardwareAddress: String?
    let ipAddresses: [IPAddress]
    let netin: Int?
    let netout: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case hardwareAddress = "hardware-address"
        case ipAddresses = "ip-addresses"
        case netin, netout
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



