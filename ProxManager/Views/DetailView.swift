//
//  DetailView.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 04/03/2024.
//  (Unified Detail View for Nodes, VMs, and Containers with Glass UI)
//

import Foundation
import SwiftUI
import Combine

// Enum to distinguish between model types
enum DetailType {
    case node(Node)
    case vm(VM)
    case container(VM) // Assuming LXC containers use the VM structure
}

struct DetailView: View {
    let detailType: DetailType
    @EnvironmentObject var nodeViewModel: NodeViewModel
    @EnvironmentObject var qemuViewModel: QemuViewModel
    @EnvironmentObject var lxcViewModel: LxcViewModel
    
    var body: some View {
        ZStack {
            // Modern gradient background with Liquid Glass effect
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 20) {
                    switch detailType {
                    case .node(let node):
                        NodeInformation(node: node)
                            .environmentObject(nodeViewModel)

                    case .vm(let vm):
                        VMInformation(vm: vm)
                            .environmentObject(qemuViewModel)
                            .onAppear {
                                Logger.shared.log("👤 User selected VM \(vm.vmid) from QemuView tab", level: .info)
                                Logger.shared.log("🟢(DetailView) Fetching IP Address for VM \(vm.vmid) on node \(vm.node)", level: .info)
                                if qemuViewModel.vms.isEmpty {
                                    ProxmoxDataStore.shared.fetchVMResources()
                                }
                                qemuViewModel.fetchVMIPAddress(vmid: vm.vmid, node: vm.node)
                            }

                    case .container(let vm):
                        VMInformation(vm: vm)
                            .environmentObject(lxcViewModel)
                            .onAppear {
                                Logger.shared.log("👤 User selected LXC \(vm.vmid) from LxcView tab")
                                Logger.shared.log("🟢(DetailView) Fetching IP Address for LXC \(vm.vmid) on node \(vm.node)")
                                if lxcViewModel.containers.isEmpty {
                                    ProxmoxDataStore.shared.fetchVMResources()
                                }
                                lxcViewModel.fetchContainerIPAddress(vmid: vm.vmid, node: vm.node)
                            }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .vm(let vm) = detailType {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section {
                            Button {
                                qemuViewModel.startVM(vmid: vm.vmid, node: vm.node)
                            } label: {
                                Label("Start", systemImage: "play")
                            }

                            Button {
                                qemuViewModel.shutdownVM(vmid: vm.vmid, node: vm.node)
                            } label: {
                                Label("Shutdown", systemImage: "stop")
                            }

                            Button {
                                qemuViewModel.rebootVM(vmid: vm.vmid, node: vm.node)
                            } label: {
                                Label("Reboot", systemImage: "restart")
                            }

                            Button(role: .destructive) {
                                qemuViewModel.stopVM(vmid: vm.vmid, node: vm.node, type: vm.type)
                            } label: {
                                Label("Stop", systemImage: "poweroff")
                            }
                        }
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                    }
                }
            } else if case .container(let vm) = detailType {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section(header: Text("Actions")) {
//                            Button("Start") {
//                                lxcViewModel.startVM(vmid: vm.vmid, node: vm.node)
//                            }
//                            Button("Reboot") {
//                                lxcViewModel.rebootVM(vmid: vm.vmid, node: vm.node)
//                            }
//                            Button("Shutdown") {
//                                lxcViewModel.shutdownVM(vmid: vm.vmid, node: vm.node)
//                            }
//                            Button(role: .destructive) {
//                                lxcViewModel.stopVM(vmid: vm.vmid, node: vm.node)
//                            } label: {
//                                Label("Stop", systemImage: "poweroff")
//                            }
                            Button {
                                qemuViewModel.startVM(vmid: vm.vmid, node: vm.node)
                            } label: {
                                Label("Start", systemImage: "play")
                            }

                            Button {
                                qemuViewModel.shutdownVM(vmid: vm.vmid, node: vm.node)
                            } label: {
                                Label("Shutdown", systemImage: "stop")
                            }

                            Button {
                                qemuViewModel.rebootVM(vmid: vm.vmid, node: vm.node)
                            } label: {
                                Label("Reboot", systemImage: "restart")
                            }

                            Button(role: .destructive) {
                                qemuViewModel.stopVM(vmid: vm.vmid, node: vm.node, type: vm.type)
                            } label: {
                                Label("Stop", systemImage: "poweroff")
                            }
                        }
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            Logger.shared.log("👤 User opened DetailView")
        }
    }

    /// Dynamic title based on content type
    private var navigationTitle: String {
        switch detailType {
        case .node(let node): return "\(node.node) Details"
        case .vm(let vm), .container(let vm): return "\(vm.name ?? "VM") Details"
        }
    }
}

// MARK: - Node Information Section
struct NodeInformation: View {
    let node: Node
    @EnvironmentObject var nodeViewModel: NodeViewModel

    var body: some View {
        InformationCard {
            VStack(spacing: 10) {
                Text("Node Information")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                Divider()
                DetailRow(label: "Name", value: node.node)
                DetailRow(label: "Status", value: node.status, color: node.status == "online" ? .green : .red)
                DetailRow(label: "Uptime", value: node.uptime != nil ? formatUptime(node.uptime!) : "Unavailable")
                if let pveVersion = node.pveVersion {
                    DetailRow(label: "PVE Version", value: pveVersion)
                }
                if let bootMode = node.bootMode {
                    DetailRow(label: "Boot Mode", value: bootMode.uppercased())
                }
                if let kernelVersion = node.currentKernelVersion {
                    DetailRow(label: "Kernel Version", value: kernelVersion)
                }
            }
        }
        .onAppear {
            nodeViewModel.fetchNodeStatus(node: node.node)
        }

        InformationCard {
            VStack(spacing: 10) {
                Text("System Information")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                Divider()
                
                if let cpuModel = node.cpuModel {
                    DetailRow(label: "CPU Model", value: cpuModel)
                }
                if let cpuCores = node.cpuCores, let cpuSockets = node.cpuSockets {
                    DetailRow(label: "CPU Cores", value: "\(cpuCores) cores, \(cpuSockets) sockets")
                }
                if let cpuMhz = node.cpuMhz {
                    DetailRow(label: "CPU Speed", value: "\(cpuMhz) MHz")
                }
                if let loadAvg = node.loadAvg {
                    DetailRow(label: "Load Average", value: "\(loadAvg[0]) (1min), \(loadAvg[1]) (5min), \(loadAvg[2]) (15min)")
                }
                if let nodeIdle = node.nodeIdle {
                    DetailRow(label: "System Idle", value: "\(String(format: "%.2f", nodeIdle))%")
                }
            }
        }

        InformationCard {
            VStack(spacing: 10) {
                Text("Resource Usage")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                Divider()
                
                if let cpu = node.cpu, let maxcpu = node.maxcpu {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("CPU Usage")
                                .font(.headline)
                            Spacer()
                            Text("\(cpu, specifier: "%.2f") of \(maxcpu) cores")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: min(cpu, Double(maxcpu)), total: Double(maxcpu))
                            .progressViewStyle(LinearProgressViewStyle())
                            .accentColor(.blue)
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                    }
                }
                
                if let mem = node.mem, let maxmem = node.maxmem {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Memory Usage")
                                .font(.headline)
                            Spacer()
                            Text("\(formatBytes(mem)) of \(formatBytes(maxmem))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: Double(min(mem, maxmem)), total: Double(maxmem))
                            .progressViewStyle(LinearProgressViewStyle())
                            .accentColor(.green)
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                    }
                }
                
                if let swapUsed = node.swapUsed, let swapTotal = node.swapTotal {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Swap Usage")
                                .font(.headline)
                            Spacer()
                            Text("\(formatBytes(swapUsed)) of \(formatBytes(swapTotal))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: Double(min(swapUsed, swapTotal)), total: Double(swapTotal))
                            .progressViewStyle(LinearProgressViewStyle())
                            .accentColor(.purple)
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                    }
                }
                
                if let fileSystemUsed = node.fileSystemUsed, let fileSystemTotal = node.fileSystemTotal {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Disk Usage")
                                .font(.headline)
                            Spacer()
                            Text("\(formatBytes(fileSystemUsed)) of \(formatBytes(fileSystemTotal))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: Double(min(fileSystemUsed, fileSystemTotal)), total: Double(fileSystemTotal))
                            .progressViewStyle(LinearProgressViewStyle())
                            .accentColor(.orange)
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - VM / LXC Information Section
struct VMInformation: View {
    let vm: VM
    @EnvironmentObject var qemuViewModel: QemuViewModel
    @EnvironmentObject var lxcViewModel: LxcViewModel
    
    private var ipAddress: String {
        if vm.type == "qemu" {
            return qemuViewModel.vms.first { $0.vmid == vm.vmid }?.ipAddress ?? "Unavailable"
        } else {
            return lxcViewModel.containers.first { $0.vmid == vm.vmid }?.ipAddress ?? "Unavailable"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Basic Information
            InformationCard {
                VStack(spacing: 10) {
                    Text("Basic Information")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                    Divider()
                    DetailRow(label: "ID", value: "\(vm.vmid)")
                    DetailRow(label: "Name", value: vm.name ?? "N/A")
                    DetailRow(label: "Status", value: vm.status)
                    DetailRow(label: "Node", value: vm.node)
                    DetailRow(label: "Type", value: vm.type)
                    DetailRow(label: "IP Address", value: ipAddress)
                    
                    if let haStatus = vm.haStatus {
                        DetailRow(label: "HA Status", value: haStatus.managed == 1 ? "Managed" : "Unmanaged")
                    }
                }
            }
            
            // LXC Specific Information
            if vm.type == "lxc", let lxcConfig = vm.lxcConfig {
                InformationCard {
                    VStack(spacing: 10) {
                        Text("LXC Configuration")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.primary)
                        Divider()
                        
                        if let hostname = lxcConfig.hostname {
                            DetailRow(label: "Hostname", value: hostname)
                        }
                        if let ostype = lxcConfig.ostype {
                            DetailRow(label: "OS Type", value: ostype)
                        }
                        if let arch = lxcConfig.arch {
                            DetailRow(label: "Architecture", value: arch)
                        }
                        if let rootfs = lxcConfig.rootfs {
                            DetailRow(label: "Root Filesystem", value: rootfs)
                        }
                        if let net0 = lxcConfig.net0 {
                            DetailRow(label: "Network Configuration", value: net0)
                        }
                    }
                }
            }
            
            // Resource Usage
            InformationCard {
                VStack(spacing: 10) {
                    Text("Resource Usage")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                    Divider()
                    
                    if vm.type == "lxc", let lxcStatus = vm.lxcStatus {
                        if let cpus = lxcStatus.cpus {
                            ResourceUsageRow(
                                title: "CPU",
                                used: cpus,
                                total: Double(vm.maxcpu ?? 1),
                                unit: "cores",
                                color: .blue
                            )
                        }
                        
                        if let memory = lxcStatus.memory {
                            ResourceUsageRow(
                                title: "Memory",
                                used: Double(memory.used) / 1_048_576, // Convert to MB
                                total: Double(memory.total) / 1_048_576,
                                unit: "MB",
                                color: .green
                            )
                        }
                        
                        if let swap = lxcStatus.swap {
                            ResourceUsageRow(
                                title: "Swap",
                                used: Double(swap.used) / 1_048_576, // Convert to MB
                                total: Double(swap.total) / 1_048_576,
                                unit: "MB",
                                color: .purple
                            )
                        }
                        
                        if let disk = lxcStatus.disk {
                            ResourceUsageRow(
                                title: "Storage",
                                used: Double(disk.used) / 1_048_576, // Convert to MB
                                total: Double(disk.total) / 1_048_576,
                                unit: "MB",
                                color: .orange
                            )
                        }
                        
                        if let network = lxcStatus.network {
                            HStack {
                                Text("Network I/O")
                                    .font(.headline)
                                Spacer()
                                Text("↓ \(formatBytes(network.netin))/s ↑ \(formatBytes(network.netout))/s")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        // QEMU VM resource usage
                        if let cpu = vm.cpu, let maxcpu = vm.maxcpu {
                            ResourceUsageRow(
                                title: "CPU",
                                used: cpu,
                                total: Double(maxcpu),
                                unit: "cores",
                                color: .blue
                            )
                        }
                        
                        if let mem = vm.mem, let maxmem = vm.maxmem {
                            ResourceUsageRow(
                                title: "Memory",
                                used: Double(mem) / 1_048_576, // Convert to MB
                                total: Double(maxmem) / 1_048_576,
                                unit: "MB",
                                color: .green
                            )
                        }
                        
                        if let disk = vm.qemuStatus?.disk {
                            ResourceUsageRow(
                                title: "Storage",
                                used: Double(disk.used) / 1_048_576, // Convert to MB
                                total: Double(disk.total) / 1_048_576,
                                unit: "MB",
                                color: .orange
                            )
                        }
                    }
                }
            }
            
            // Performance Metrics
            InformationCard {
                VStack(spacing: 10) {
                    Text("Performance Metrics")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                    Divider()
                    
                    if vm.type == "lxc", let lxcStatus = vm.lxcStatus {
                        if let uptime = lxcStatus.uptime {
                            DetailRow(label: "Uptime", value: formatUptime(uptime))
                        }
                    } else {
                        if let diskread = vm.diskread, let diskwrite = vm.diskwrite {
                            HStack {
                                Text("Disk I/O")
                                    .font(.subheadline)

                                Spacer()
                                Text("↓ \(formatBytes(diskread))/s ↑ \(formatBytes(diskwrite))/s")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let netin = vm.netin, let netout = vm.netout {
                            HStack {
                                Text("Network I/O")
                                    .font(.subheadline)
                                Spacer()
                                Text("↓ \(formatBytes(netin))/s ↑ \(formatBytes(netout))/s")
                                    .font(.headline)

                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let uptime = vm.uptime {
                            // DetailRow(label: "Uptime", value: formatUptime(uptime))
                            HStack {
                                Text("Uptime")
                                    .font(.subheadline)

                                Spacer()
                                Text("\(formatUptime(uptime))")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }

                        }
                    }
                }
            }
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatUptime(_ seconds: Int) -> String {
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct ResourceUsageRow: View {
    let title: String
    let used: Double
    let total: Double
    let unit: String
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return min(used * 100 / total, 100)
    }
    
    private var clampedUsed: Double {
        max(0, min(used, total))
    }
    
    private var safeTotal: Double {
        max(1, total)
    }
    
    private var displayUsed: Double {
        if total <= 0 {
            return 0
        }
        return clampedUsed
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Text("\(Int(percentage))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: displayUsed, total: safeTotal)
                .progressViewStyle(LinearProgressViewStyle())
                .tint(color)
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .accessibilityLabel("\(title) usage")
                .accessibilityValue("\(Int(percentage))%")
            
            HStack {
                Text("\(Int(displayUsed)) \(unit)")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(Int(total)) \(unit)")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Reusable Components

/// A reusable glass-like card view with improved styling
struct InformationCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.2),
                                        Color.purple.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}

/// A reusable row for displaying key-value pairs with improved styling
struct DetailRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Utility Functions

/// Formats bytes into a human-readable format (MB/GB)
func formatBytes(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
}

/// Formats uptime (in seconds) into `Days Hours Minutes`
func formatUptime(_ seconds: Int) -> String {
    let days = seconds / 86400
    let hours = (seconds % 86400) / 3600
    let minutes = (seconds % 3600) / 60
    return "\(days)d \(hours)h \(minutes)m"
}
