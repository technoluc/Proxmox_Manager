//
//  ProxmoxViews.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 21/02/2024.
//

import Foundation
import SwiftUI

struct ContentView: View {
    /// ViewModel for managing node data.
    @StateObject var nodeViewModel = NodeViewModel()
    /// ViewModel for managing QEMU virtual machines.
    @StateObject var qemuViewModel = QemuViewModel()
    /// ViewModel for managing LXC containers.
    @StateObject var lxcViewModel = LxcViewModel()
    /// Controls the visibility of the settings view.
    @State private var showingSettings = false
    /// Controls the visibility of the alert.
    @State private var showAlert = false
    /// The message to be displayed in the alert.
    @State private var alertMessage = ""
    /// Determines if this is the first launch based on the presence of an API address.
    @State private var isFirstLaunch = UserDefaults.standard.string(forKey: "apiAddress") == nil

    var body: some View {
        NavigationView {
            List {
                NodeView(viewModel: nodeViewModel)
                QemuView(viewModel: qemuViewModel)
                LxcView(viewModel: lxcViewModel)
            }
            .refreshable {
                // Refresh action to fetch new node data
                nodeViewModel.fetchNodes()
                qemuViewModel.fetchVMs()
                lxcViewModel.fetchContainers()

            }
            .listStyle(.plain) // Set the list style to plain
            .scrollContentBackground(.hidden) // Hides the scroll view's background.
            .background(.orange)
            .navigationTitle("ProxMan Dashboard")
//             .navigationBarTitleDisplayMode(.inline)
//            .toolbarBackground(.orange)
            .toolbar {
                Menu {
                    Button("Refresh", action: {
                        nodeViewModel.fetchNodes()
                        qemuViewModel.fetchVMs()
                        lxcViewModel.fetchContainers()
                    })
                    Button("Log Out", action: {
                        // Add log out functionality here
                    })
                    Button(action: { showingSettings = true }) {
//                        Image(systemName: "gear")
//                            .imageScale(.large)
//                            .foregroundColor(.primary)
                        Text("Settings")
                    }
                } label: {
                    Label("Settings", systemImage: "gear")
                        .imageScale(.large)
                        .foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showingSettings) {
                // Presents the settings view as a modal sheet.
                SettingsView(onSave: {
                    // Action to take when settings are saved.
                    nodeViewModel.fetchNodes()
                    qemuViewModel.fetchVMs()
                    lxcViewModel.fetchContainers()
                })
            }
            .sheet(isPresented: $isFirstLaunch) {
                SettingsView(onSave: {
                    // Actions to take after saving settings, such as refreshing data or dismissing the welcome screen
                    self.isFirstLaunch = false
                    nodeViewModel.fetchNodes()
                    qemuViewModel.fetchVMs()
                    lxcViewModel.fetchContainers()
                })
            }
            .alert(isPresented: $showAlert) {
                // Configures the alert dialog
                Alert(
                    title: Text("Error"),
                    message: Text(alertMessage),
                    primaryButton: .default(Text("OK")),
                    secondaryButton: .default(Text("Settings")) {
                        showingSettings = true
                    }
                )
            }
            .onAppear {
                self.isFirstLaunch = UserDefaults.standard.string(forKey: "apiAddress") == nil
                nodeViewModel.fetchNodes()
                qemuViewModel.fetchVMs()
                lxcViewModel.fetchContainers()
            }
        }
    }
}

// MARK: NodeView

struct NodeView: View {
    @ObservedObject var viewModel: NodeViewModel
    @State private var expandedNodeIDs: Set<String> = []

    var body: some View {
        Section(header: Text("Nodes")
            .foregroundColor(.primary)
            .font(.headline)
            .bold()
            // .headerProminence(.standard)
        ) {
            ForEach(viewModel.nodes.sorted(by: { $0.node < $1.node }), id: \.id) { node in
                NavigationLink(destination: DetailView(detailType: .node(node))
                    .onAppear {
                        self.viewModel.fetchNodeStatus(node: node.node)
                        //viewModel.fetchNodeStatus(node: node.node)
                }) {
                    VStack(alignment: .leading) {
                        HStack {
                            Spacer()
                        }
                        HStack {
                            Text(node.node)
                                .font(.headline)
                                .bold()
                                .foregroundColor(node.status == "online" ? .orange : .red)
                            Spacer()
                            Text(node.status)
                                .font(.subheadline)
                                .foregroundColor(node.status == "online" ? .green : .red)

                        }
                        .contextMenu {
                            Button(action: {
                                // Placeholder for reboot functionality
                            }) {
                                Label("Reboot", systemImage: "arrow.clockwise")
                            }
                            Button(action: {
                                // Placeholder for shutdown functionality
                            }) {
                                Label("Shutdown", systemImage: "power")
                            }
//                            Button("Fetch Node Status") {
//                                // self.viewModel.fetchNodeStatus(node: "exampleNode")
//                            }

                        }
                    }
                }
                .padding(.vertical)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(uiColor: .systemBackground))
                .opacity(0.6)
                    .padding(
                        EdgeInsets(
                            top: 5,
                            leading: 5,
                            bottom: 5,
                            trailing: 5
                        )
                    )
            )
            .listRowSeparator(.hidden)
        }
    }
}

// MARK: QemuView

struct QemuView: View {
    @StateObject var viewModel = QemuViewModel()

    var body: some View {
        Section( header: Text("QEMU Virtual Machines")
            .font(.headline)
            .bold()
            .foregroundColor(.primary)
        ) {
            ForEach(viewModel.vms.sorted(by: { $0.vmid < $1.vmid }), id: \.id) { vm in
                NavigationLink(destination: DetailView(detailType: .vm(vm))
                    .onAppear {
                    self.viewModel.fetchVMIPAddress(vmid: vm.vmid, node: vm.node)
                }) {
                    VStack {
                            HStack {
                                Text("\(String(vm.vmid))") // Correcting VMID display
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            HStack {
                                Text(vm.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    // .foregroundColor(vm.status == "running" ? .green : .red)

                                Spacer()
                                Text(vm.status)
                                    .font(.subheadline)
                                    .foregroundColor(vm.status == "running" ? .green : .red)
                            }
                        }
                        .padding(.vertical) // Apply padding to HStack directly
                        .contextMenu(menuItems: {
                            Button(action: {
                                viewModel.startVM(vmid: vm.vmid, node: vm.node)
                            }) {
                                Label("Start", systemImage: "play")
                            }
                            Button {
                                viewModel.rebootVM(vmid: vm.vmid, node: vm.node)  // Convert Int to String
                            } label: {
                                Label("Reboot", systemImage: "arrow.clockwise")
                            }
                            Button(action: {
                                viewModel.shutdownVM(vmid: (vm.vmid), node: vm.node)
                            }) {
                                Label("Shutdown", systemImage: "power")
                            }
                            Button(action: {
                                viewModel.stopVM(vmid: vm.vmid, node: vm.node, type: vm.type)
                            }) {
                                Label("Stop", systemImage: "poweroff")
                            }
                    })
                }
                // .padding(.horizontal)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(uiColor: .systemBackground))
                .opacity(0.6)
                    .padding(
                        EdgeInsets(
                            top: 5,
                            leading: 5,
                            bottom: 5,
                            trailing: 5
                        )
                    )
            )
            .listRowSeparator(.hidden)

        }
    }
}

// MARK: LxcView

struct LxcView: View {
    @StateObject var viewModel = LxcViewModel()

    var body: some View {
        Section( header: Text("LXC Containers")
            .font(.headline)
            .bold()
            .foregroundColor(.primary)
        ) {
            ForEach(viewModel.containers.sorted(by: { $0.vmid < $1.vmid }), id: \.id) { container in
                NavigationLink(destination: DetailView(detailType: .container(container))
                    .onAppear {
                        self.viewModel.fetchContainerIPAddress(vmid: container.vmid, node: container.node)
                    }) {
                    VStack {
                            HStack {
                                Text("\(String(container.vmid))") // Correcting VMID display
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            HStack {
                                Text(container.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    // .foregroundColor(container.status == "running" ? .green : .red)

                                Spacer()
                                Text(container.status)
                                    .font(.subheadline)
                                    .foregroundColor(container.status == "running" ? .green : .red)
                            }
                        }
                        .padding(.vertical) // Apply padding to HStack directly
                        .contextMenu(menuItems: {
                            Button(action: {
                                viewModel.startVM(vmid: container.vmid, node: container.node)
                            }) {
                                Label("Start", systemImage: "play")
                            }
                            Button {
                                viewModel.rebootVM(vmid: container.vmid, node: container.node)  // Convert Int to String
                            } label: {
                                Label("Reboot", systemImage: "arrow.clockwise")
                            }
                            Button(action: {
                                viewModel.shutdownVM(vmid: (container.vmid), node: container.node)
                            }) {
                                Label("Shutdown", systemImage: "power")
                            }
                            Button(action: {
                                viewModel.stopVM(vmid: container.vmid, node: container.node)
                            }) {
                                Label("Stop", systemImage: "poweroff")
                            }
                    })
                }
                // .padding(.horizontal)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(uiColor: .systemBackground))
                .opacity(0.6)
                    .padding(
                        EdgeInsets(
                            top: 5,
                            leading: 5,
                            bottom: 5,
                            trailing: 5
                        )
                    )
            )
            .listRowSeparator(.hidden)

        }
    }
}

// MARK: - Previews

struct ProxmoxViews_Previews: PreviewProvider {
    static var previews: some View {
        ContentView_Previews.previews
    }
}
