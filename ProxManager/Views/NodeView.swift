//
//  NodeView.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 15/03/2025.
//

import Foundation
import SwiftUI
import Combine

struct NodeView: View {
    @EnvironmentObject var viewModel: NodeViewModel

    // 🔹 Persistent settings
    @AppStorage("nodeSortOption") private var nodeSortOption: String = "name"
    @AppStorage("hideOfflineNodes") private var hideOfflineNodes: Bool = false

    // UI State
    @State private var showRebootAlert = false
    @State private var showShutdownAlert = false
    @State private var showClusterShutdownAlert = false
    @State private var selectedNode: String = ""

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
                        // Node Status Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Node Status")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            HStack(spacing: 16) {
                                GlassWidgetView(
                                    title: "Online Nodes",
                                    value: Double(viewModel.onlineCount),
                                    unit: "of \(viewModel.totalCount)",
                                    color: .proxmoxSuccess,
                                    icon: "server.rack"
                                )
                                
                                GlassWidgetView(
                                    title: "CPU Usage",
                                    value: viewModel.totalCPUUsage,
                                    unit: "%",
                                    color: .proxmoxPrimary,
                                    icon: "cpu"
                                )
                                
                                GlassWidgetView(
                                    title: "Memory Usage",
                                    value: viewModel.totalRAMUsage,
                                    unit: "GB",
                                    color: .proxmoxSecondary,
                                    icon: "memorychip"
                                )
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                        
                        // Nodes List Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Nodes")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.sortedNodes, id: \.id) { node in
                                NavigationLink {
                                    DetailView(detailType: .node(node))
                                } label: {
                                    NodeRowView(node: node)
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
                                        selectedNode = node.node
                                        showRebootAlert = true
                                    } label: {
                                        Label("Reboot Node", systemImage: "restart")
                                    }
                                    
                                    Button(role: .destructive) {
                                        selectedNode = node.node
                                        showShutdownAlert = true
                                    } label: {
                                        Label("Shutdown Node", systemImage: "poweroff")
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
                    ProxmoxDataStore.shared.fetchNodes()
                }
            }
            .navigationTitle("Nodes")
            .toolbar {
                // Sort & Filter Menu
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Toggle("Hide Offline Nodes", isOn: $hideOfflineNodes)
                            .onChange(of: hideOfflineNodes) { _, _ in
                                viewModel.refreshData()
                                Logger.shared.log(".onChange(of: hideOfflineNodes): NodeViewModel.refreshData()")
                            }

                        Section(header: Text("Sort Nodes By")) {
                            Button("Name") { nodeSortOption = "name" }
                            Button("ID") { nodeSortOption = "id" }
                            Button("Status") { nodeSortOption = "status" }
                        }
                    } label: {
                        Label("Sort & Filter", systemImage: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(.primary)
                    }
                }

                // Shutdown Cluster Button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .destructive) {
                        showClusterShutdownAlert = true
                    } label: {
                        Label("Shutdown Cluster", systemImage: "power.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                Logger.shared.log("👤 User selected NodeView Tab")
                Logger.shared.log("ℹ️ NodeView: nodeViewModel.onlineCount: \(viewModel.onlineCount) ")
                if viewModel.nodes.isEmpty {
                    Logger.shared.log("🔄 NodeView: viewModel.nodes.isEmpty.")
                }
                if ProxmoxDataStore.shared.nodes.isEmpty {
                    Logger.shared.log("🔄 NodeView: ProxmoxDataStore.shared.nodes.isEmpty.")
                }
            }
        }
        // Confirmation Alerts
        .alert("Confirm Reboot", isPresented: $showRebootAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reboot", role: .destructive) {
                viewModel.rebootNode(node: selectedNode)
            }
        }
        .alert("Confirm Shutdown", isPresented: $showShutdownAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Shutdown", role: .destructive) {
                viewModel.shutdownNode(node: selectedNode)
            }
        }
        .alert("Confirm Cluster Shutdown", isPresented: $showClusterShutdownAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Shutdown All Nodes", role: .destructive) {
                viewModel.shutdownCluster()
            }
        }
    }
}

// Node Row UI
struct NodeRowView: View {
    let node: Node

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(node.node)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Circle()
                            .fill(node.status == "online" ? Color.proxmoxSuccess : Color.proxmoxError)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(node.status.capitalized)
                            .font(.subheadline)
                            .foregroundColor(node.status == "online" ? .proxmoxSuccess : .proxmoxError)
                            .accessibilityLabel("Status: \(node.status)")
                    }
                    
                    if node.status == "online" {
                        HStack(spacing: 4) {
                            Image(systemName: "server.rack")
                                .foregroundColor(.proxmoxPrimary)
                                .imageScale(.small)
                            Text("Proxmox Node")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if node.status == "online" {
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
                    if let cpu = node.cpu {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .foregroundColor(.proxmoxPrimary)
                                .imageScale(.small)
                            Text("\(Int(cpu * 100))% CPU")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let mem = node.mem, let maxmem = node.maxmem {
                        HStack(spacing: 4) {
                            Image(systemName: "memorychip")
                                .foregroundColor(.proxmoxSecondary)
                                .imageScale(.small)
                            Text("\(Int((Double(mem) / Double(maxmem)) * 100))% Memory")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

#if DEBUG
struct NodeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NodeView()
                .environmentObject(NodeViewModel())
                .environmentObject(QemuViewModel())
                .environmentObject(LxcViewModel())
        }
    }
}
#endif
