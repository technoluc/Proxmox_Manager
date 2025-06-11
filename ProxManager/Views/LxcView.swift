//
//  LxcView.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 15/03/2025.
//

import Foundation
import SwiftUI
import Combine

struct LxcView: View {
    @EnvironmentObject var nodeViewModel: NodeViewModel
    @EnvironmentObject var viewModel: LxcViewModel

    @AppStorage("lxcSortOption") private var lxcSortOption: String = "name"
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
                        // Container Status Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Container Status")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            HStack(spacing: 16) {
                                GlassWidgetView(
                                    title: "Active LXC's",
                                    value: Double(viewModel.runningCount),
                                    unit: "of \(viewModel.totalCount)",
                                    color: .proxmoxSuccess,
                                    icon: "cube.box.fill"
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
                        
                        // Containers List Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("LXC Containers")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.sortedContainers, id: \.id) { container in
                                NavigationLink {
                                    DetailView(detailType: .container(container))
                                } label: {
                                    LxcRowView(container: container)
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
                                        viewModel.startVM(vmid: container.vmid, node: container.node)
                                    } label: {
                                        Label("Start", systemImage: "play")
                                    }

                                    Button {
                                        viewModel.shutdownVM(vmid: container.vmid, node: container.node)
                                    } label: {
                                        Label("Shutdown", systemImage: "stop")
                                    }

                                    Button {
                                        viewModel.rebootVM(vmid: container.vmid, node: container.node)
                                    } label: {
                                        Label("Reboot", systemImage: "restart")
                                    }

                                    Button(role: .destructive) {
                                        viewModel.stopVM(vmid: container.vmid, node: container.node)
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
            .navigationTitle("LXC Containers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Toggle("Hide Offline Resources", isOn: $hideOfflineResources)
                            .onChange(of: hideOfflineResources) { _, _ in
                                Logger.shared.log("👤 User toggled hideOfflineResources to \(hideOfflineResources)")
                                viewModel.refreshData()
                                Logger.shared.log(".onChange(of: hideOfflineNodes): LxcViewModel.refreshData()")
                            }

                        Toggle("Hide Stopped Resources", isOn: $viewModel.hideStoppedResources)
                            .onChange(of: viewModel.hideStoppedResources) {
                                viewModel.refreshData()
                                Logger.shared.log("👤 User toggled hideStoppedResources to \(viewModel.hideStoppedResources)")
                                Logger.shared.log(".onChange(of: hideStoppedResources): LxcViewModel.refreshData()")
                            }

                        Section(header: Text("Sort Containers By")) {
                            Button("Name") { lxcSortOption = "name" }
                            Button("ID") { lxcSortOption = "id" }
                            Button("Status") { lxcSortOption = "status" }
                        }
                    } label: {
                        Label("Sort & Filter", systemImage: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .onAppear {
                Logger.shared.log("👤 User selected LxcView Tab")
                Logger.shared.log("ℹ️ hideOfflineResources is: \(hideOfflineResources)")
                Logger.shared.log("ℹ️ hideOfflineResources is: \(hideStoppedResources)")
                Logger.shared.log("ℹ️ LxcView: nodeViewModel.onlineCount: \(nodeViewModel.onlineCount) ")
                Logger.shared.log("ℹ️ LxcView: viewModel.sortedContainers.count: \(viewModel.sortedContainers.count) ")
                if nodeViewModel.nodes.isEmpty {
                    Logger.shared.log("🔄 NodeView: viewModel.nodes.isEmpty, fetching nodes...")
                }
            }
        }
    }
}

struct LxcRowView: View {
    let container: VM

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(container.name ?? "Unknown")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("(ID: \(String(container.vmid)))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Circle()
                            .fill(container.status == "running" ? Color.proxmoxSuccess : Color.proxmoxError)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(container.status.capitalized)
                            .font(.subheadline)
                            .foregroundColor(container.status == "running" ? .proxmoxSuccess : .proxmoxError)
                            .accessibilityLabel("Status: \(container.status)")
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(container.node)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if container.status == "running", let lxcStatus = container.lxcStatus {
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
                    if let lxcStatus = container.lxcStatus {
                        if let cpus = lxcStatus.cpus, let maxcpu = container.maxcpu {
                            HStack(spacing: 4) {
                                Image(systemName: "cpu")
                                    .foregroundColor(.proxmoxPrimary)
                                    .imageScale(.small)
                                Text("\(Int(cpus))/\(maxcpu) cores")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let memory = lxcStatus.memory {
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip")
                                    .foregroundColor(.proxmoxSecondary)
                                    .imageScale(.small)
                                Text("\(formatBytes(memory.used))/\(formatBytes(memory.total))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#if DEBUG
struct LxcView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LxcView()
                .environmentObject(NodeViewModel())
                .environmentObject(QemuViewModel())
                .environmentObject(LxcViewModel())
        }
    }
}
#endif

