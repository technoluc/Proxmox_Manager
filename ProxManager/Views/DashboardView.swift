//
//  DashboardView.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 17/03/2025.
//

import Foundation
import SwiftUI
import Combine

struct DashboardView: View {
    @EnvironmentObject var nodeViewModel: NodeViewModel
    @EnvironmentObject var qemuViewModel: QemuViewModel
    @EnvironmentObject var lxcViewModel: LxcViewModel
    
    @Binding var selectedTab: Int
    @State private var isRefreshing = false
    @State private var showingSettings = false
    @State private var showingLogs = false
    @State private var showingLogin = false
    
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
                        // System Status Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("System Status")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            HStack(spacing: 16) {
                                GlassWidgetView(
                                    title: "CPU Usage",
                                    value: nodeViewModel.totalCPUUsage,
                                    unit: "%",
                                    color: .proxmoxPrimary,
                                    icon: "cpu"
                                )
                                
                                GlassWidgetView(
                                    title: "RAM Usage",
                                    value: nodeViewModel.totalRAMUsage,
                                    unit: "GB",
                                    color: .proxmoxSecondary,
                                    icon: "memorychip"
                                )
                                
                                GlassWidgetView(
                                    title: "Disk Usage",
                                    value: nodeViewModel.totalDiskUsage,
                                    unit: "TB",
                                    color: .proxmoxAccent,
                                    icon: "externaldrive"
                                )
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                        
                        // Resource Status Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Resource Status")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            HStack(spacing: 16) {
                                NavigationButton(
                                    title: "Online Nodes",
                                    count: nodeViewModel.onlineCount,
                                    totalCount: nodeViewModel.totalCount,
                                    color: .proxmoxSuccess,
                                    icon: "server.rack",
                                    action: { selectedTab = 1 }
                                )
                                
                                NavigationButton(
                                    title: "Online VMs",
                                    count: qemuViewModel.runningCount,
                                    totalCount: qemuViewModel.totalCount,
                                    color: .proxmoxPrimary,
                                    icon: "desktopcomputer",
                                    action: { selectedTab = 2 }
                                )
                                
                                NavigationButton(
                                    title: "Online LXCs",
                                    count: lxcViewModel.runningCount,
                                    totalCount: lxcViewModel.totalCount,
                                    color: .proxmoxSecondary,
                                    icon: "cube.box",
                                    action: { selectedTab = 3 }
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Cluster Resources Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cluster Resources")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                GlassWidgetView(
                                    title: "CPU Usage",
                                    value: nodeViewModel.averageNodeLoad * 100,
                                    unit: "%",
                                    color: .proxmoxPrimary,
                                    icon: "cpu"
                                )
                                
                                GlassWidgetView(
                                    title: "Memory Usage",
                                    value: nodeViewModel.averageMemoryUsage * 100,
                                    unit: "%",
                                    color: .proxmoxSuccess,
                                    icon: "memorychip"
                                )
                                
                                GlassWidgetView(
                                    title: "Storage Usage",
                                    value: nodeViewModel.averageStorageUsage * 100,
                                    unit: "%",
                                    color: .proxmoxAccent,
                                    icon: "externaldrive"
                                )
                                
                                GlassWidgetView(
                                    title: "Network I/O",
                                    value: Double(qemuViewModel.vms.reduce(0) { $0 + ($1.netin ?? 0) + ($1.netout ?? 0) }) / 1_000_000,
                                    unit: "MB/s",
                                    color: .proxmoxSecondary,
                                    icon: "network"
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom)
                }
                .refreshable {
                    isRefreshing = true
                    Logger.shared.log("👤 User pulled to refresh")
                    refreshData()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isRefreshing = false
                    }
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                        
                        Button {
                            showingLogs = true
                        } label: {
                            Label("Logs", systemImage: "doc.text.magnifyingglass")
                        }
                        
                        Button {
                            showingLogin = true
                        } label: {
                            Label("Login", systemImage: "person.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingLogs) {
                LogsView()
            }
            .sheet(isPresented: $showingLogin) {
                LoginView()
            }
            .onAppear {
                Logger.shared.log("👤 User selected DashboardView Tab")
            }
        }
    }

    private func refreshData() {
        ProxmoxDataStore.shared.fetchNodes()
        ProxmoxDataStore.shared.fetchVMResources()
    }
}

struct GlassWidgetView: View {
    var title: String
    var value: Double
    var unit: String
    var color: Color
    var icon: String
    
    /// Ensures progress value is always within 0...100 bounds expected by ProgressView
    private var clampedValue: Double {
        min(max(value, 0), 100)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(Int(value)) \(unit)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            ProgressView(value: clampedValue, total: 100)
                .progressViewStyle(LinearProgressViewStyle())
                .tint(color)
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
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
}

struct NavigationButton: View {
    var title: String
    var count: Int
    var totalCount: Int
    var color: Color
    var icon: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(count) / \(totalCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 100)
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
    }
}

