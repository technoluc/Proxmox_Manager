//
//  MainView.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 17/03/2025.
//  (Tabbed UI with glass effect for modern UX)
//

import Foundation
import SwiftUI
import Combine

struct MainView: View {
    @EnvironmentObject var nodeViewModel: NodeViewModel
    @EnvironmentObject var qemuViewModel: QemuViewModel
    @EnvironmentObject var lxcViewModel: LxcViewModel

    @State private var hasFetchedData = false
    @State private var selectedTab = 0
    
    // 🔹 Persistent filter & sort options
    @AppStorage("hideOfflineResources") private var hideOfflineResources: Bool = false
    @AppStorage("hideStoppedResources") private var hideStoppedResources: Bool = false
    @AppStorage("nodeSortOption") private var nodeSortOption: String = "name"
    @AppStorage("vmSortOption") private var vmSortOption: String = "name"
    @AppStorage("lxcSortOption") private var lxcSortOption: String = "name"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Primary Tabs
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)
            
            NodeView()
                .tabItem {
                    Label("Nodes", systemImage: "server.rack")
                }
                .tag(1)

            QemuView()
                .tabItem {
                    Label("VMs", systemImage: "desktopcomputer")
                }
                .tag(2)
            
            LxcView()
                .tabItem {
                    Label("LXC", systemImage: "shippingbox.fill")
                }
                .tag(3)
            
            QNAPManagerView()
                .tabItem {
                    Label("QNAP", systemImage: "terminal.fill")
                }
                .tag(4)
        }
        .tint(.proxmoxPrimary)
        .applyTabBarMinimizeBehavior()
        .onAppear {
            if !hasFetchedData {
                hasFetchedData = true
                ProxmoxDataStore.shared.fetchNodes()
                ProxmoxDataStore.shared.fetchVMResources()
            }
            Logger.shared.log("👁️ MainView appeared")
            Logger.shared.log("↘️ DashboardView opened as first tab in MainView")
        }
    }
    
    private func refreshData() {
        ProxmoxDataStore.shared.fetchVMResources()
    }
}

private extension View {
    @ViewBuilder
    func applyTabBarMinimizeBehavior() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(NodeViewModel())
            .environmentObject(QemuViewModel())
            .environmentObject(LxcViewModel())
    }
}
#endif
