//
//  QemuView.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 15/03/2025.
//

import Foundation
import SwiftUI
import Combine

struct QemuView: View {
    @EnvironmentObject var nodeViewModel: NodeViewModel
    @EnvironmentObject var viewModel: QemuViewModel
    
    @AppStorage("vmSortOption") private var vmSortOption: String = "name"
    @AppStorage("hideOfflineResources") private var hideOfflineResources: Bool = false
    @AppStorage("hideStoppedResources") private var hideStoppedResources: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Modern gradient background with enhanced Liquid Glass effect
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.proxmoxPrimary.opacity(0.05),
                        Color.proxmoxSecondary.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 20) {
                        // VM Status Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("VM Status")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            HStack(spacing: 16) {
                                GlassWidgetView(
                                    title: "Active VMs",
                                    value: Double(viewModel.runningCount),
                                    unit: "of \(viewModel.totalCount)",
                                    color: .proxmoxSuccess,
                                    icon: "server.rack"
                                )
                                .frame(maxWidth: .infinity)
                                
                                GlassWidgetView(
                                    title: "CPU Usage",
                                    value: viewModel.totalCPUUsage,
                                    unit: "%",
                                    color: .proxmoxPrimary,
                                    icon: "cpu"
                                )
                                .frame(maxWidth: .infinity)
                                
                                GlassWidgetView(
                                    title: "Memory Usage",
                                    value: viewModel.totalRAMUsage,
                                    unit: "%",
                                    color: .proxmoxSecondary,
                                    icon: "memorychip"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                        
                        // VMs List Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Virtual Machines")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.sortedVMs, id: \.id) { vm in
                                NavigationLink {
                                    DetailView(detailType: .vm(vm))
                                } label: {
                                    VMRowView(vm: vm)
                                        .background(
                                            RoundedRectangle(cornerRadius: ProxmoxMaterialStyle.cardCornerRadius)
                                                .fill(ProxmoxMaterialStyle.card)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: ProxmoxMaterialStyle.cardCornerRadius)
                                                        .stroke(ProxmoxMaterialStyle.cardBorder, lineWidth: ProxmoxMaterialStyle.cardBorderWidth)
                                                )
                                                .shadow(
                                                    color: ProxmoxMaterialStyle.cardShadow,
                                                    radius: ProxmoxMaterialStyle.cardShadowRadius,
                                                    y: ProxmoxMaterialStyle.cardShadowY
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        viewModel.startVM(vmid: vm.vmid, node: vm.node)
                                    } label: {
                                        Label("Start", systemImage: "play")
                                    }

                                    Button {
                                        viewModel.shutdownVM(vmid: vm.vmid, node: vm.node)
                                    } label: {
                                        Label("Shutdown", systemImage: "stop")
                                    }

                                    Button {
                                        viewModel.rebootVM(vmid: vm.vmid, node: vm.node)
                                    } label: {
                                        Label("Reboot", systemImage: "restart")
                                    }

                                    Button(role: .destructive) {
                                        viewModel.stopVM(vmid: vm.vmid, node: vm.node, type: vm.type)
                                    } label: {
                                        Label("Stop", systemImage: "poweroff")
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
//                    .padding(.vertical)
                }
                .refreshable {
                    Logger.shared.log("👤 User pulled to refresh")
                    ProxmoxDataStore.shared.fetchVMResources()
                }
            }
            .navigationTitle("Virtual Machines")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Toggle("Hide Offline Resources", isOn: $hideOfflineResources)
                            .onChange(of: hideOfflineResources) {
                                viewModel.refreshData()
                                Logger.shared.log("👤 User toggled hideOfflineResources to \(hideOfflineResources)")
                                Logger.shared.log(".onChange(of: hideOfflineNodes): QemuViewModel.refreshData()")
                            }

                        Toggle("Hide Stopped Resources", isOn: $viewModel.hideStoppedResources)
                            .onChange(of: viewModel.hideStoppedResources) {
                                viewModel.refreshData()
                                Logger.shared.log("👤 User toggled hideStoppedResources to \(viewModel.hideStoppedResources)")
                                Logger.shared.log(".onChange(of: hideStoppedResources): QemuViewModel.refreshData()")
                            }

                        Section(header: Text("Sort VMs By")) {
                            Button("Name") { vmSortOption = "name" }
                            Button("ID") { vmSortOption = "id" }
                            Button("Status") { vmSortOption = "status" }
                        }
                    } label: {
                        Label("Sort & Filter", systemImage: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .onAppear {
                Logger.shared.log("👤 User selected QemuView Tab")
                Logger.shared.log("ℹ️ hideOfflineResources is: \(hideOfflineResources)")
                Logger.shared.log("ℹ️ hideStoppedResources is: \(hideStoppedResources)")
                Logger.shared.log("ℹ️ QemuView: nodeViewModel.onlineCount: \(nodeViewModel.onlineCount) ")
                Logger.shared.log("ℹ️ QemuView: viewModel.sortedVMs.count: \(viewModel.sortedVMs.count) ")
                if nodeViewModel.nodes.isEmpty {
                    Logger.shared.log("🔄 NodeView: viewModel.nodes.isEmpty, fetching nodes...")
                }
            }
        }
    }
}

struct VMRowView: View {
    let vm: VM

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(vm.name ?? "Unknown")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("(ID: \(String(vm.vmid)))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Circle()
                            .fill(vm.status == "running" ? Color.proxmoxSuccess : Color.proxmoxError)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(vm.status.capitalized)
                            .font(.subheadline)
                            .foregroundColor(vm.status == "running" ? .proxmoxSuccess : .proxmoxError)
                            .accessibilityLabel("Status: \(vm.status)")
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(vm.node)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if vm.status == "running" {
                Divider()
                    .background(
                        LinearGradient(
                            colors: [.clear, .secondary.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.vertical, 4)
                
                HStack(spacing: 16) {
                    if let cpu = vm.cpu, let maxcpu = vm.maxcpu {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .foregroundColor(.proxmoxPrimary)
                                .imageScale(.small)
                            Text("\(Int(cpu))/\(maxcpu) cores")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let mem = vm.mem, let maxmem = vm.maxmem {
                        HStack(spacing: 4) {
                            Image(systemName: "memorychip")
                                .foregroundColor(.proxmoxSecondary)
                                .imageScale(.small)
                            Text("\(formatBytes(mem))/\(formatBytes(maxmem))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#if DEBUG
struct QemuView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            QemuView()
                .environmentObject(NodeViewModel())
                .environmentObject(QemuViewModel())
                .environmentObject(LxcViewModel())
        }
    }
}
#endif
