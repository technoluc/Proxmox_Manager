//
//
// QNAPManagerView.swift
//
//


import SwiftUI
import Foundation
import Combine


struct QNAPManagerView: View {
    @StateObject private var viewModel = QNAPManagerViewModel()
    @State private var showingConnectionSheet = false
    @State private var showingNewCommandSheet = false
    @State private var searchText = ""
    @State private var selectedCommandForOutput: SSHCommand?

    
    private var filteredCommands: [SSHCommand] {
        if searchText.isEmpty {
            return viewModel.savedCommands
        }
        return viewModel.savedCommands.filter { $0.name.localizedCaseInsensitiveContains(searchText) || 
                                              $0.description.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Modern gradient background with Liquid Glass effect
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
                        // Connection Status Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Connection")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            if let connection = viewModel.connection {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(connection.host)
                                            .font(.headline)
                                        Text(connection.username)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Circle()
                                        .fill(viewModel.isConnected ? Color.proxmoxSuccess : Color.proxmoxError)
                                        .frame(width: 12, height: 12)
                                }
                                .padding()
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
                            } else {
                                Button(action: { showingConnectionSheet = true }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Configure Connection")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
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
                        .padding(.horizontal)
                        
                        // Quick Actions Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Actions")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            Button(action: {
                                Task {
                                    await viewModel.restartPlex()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("Restart Plex Server")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
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
                            .disabled(viewModel.connection == nil || viewModel.isLoading)
                        }
                        .padding(.horizontal)
                        
                        // Saved Commands Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Saved Commands")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            ForEach(filteredCommands) { command in
                                CommandRow(
                                    command: command,
                                    viewModel: viewModel,
                                    selectedCommand: $selectedCommandForOutput
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("QNAP Manager")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { showingNewCommandSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundStyle(.primary)
                    }
                    #if os(iOS26)
                    ToolbarSpacer(.fixed, placement: .primaryAction)
                    #endif
                    
                    Button(action: { showingConnectionSheet = true }) {
                        Image(systemName: "gear")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Connection Settings")
                }
            }
            .searchable(text: $searchText, prompt: "Search commands")
            .sheet(isPresented: $showingConnectionSheet) {
                ConnectionConfigurationView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingNewCommandSheet) {
                NewCommandView(viewModel: viewModel)
            }
            .sheet(item: $selectedCommandForOutput) { command in
                NavigationView {
                    LiveOutputView(viewModel: viewModel, command: command)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

struct CommandRow: View {
    let command: SSHCommand
    let viewModel: QNAPManagerViewModel
    @Binding var selectedCommand: SSHCommand?
    @State private var showingEditSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(command.name)
                    .font(.headline)
                Spacer()
                if command.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.proxmoxAccent)
                }
            }
            
            Text(command.command)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let lastExecuted = command.lastExecuted {
                Text("Last executed: \(lastExecuted.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
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
        .contextMenu {
            Button {
                print("[CommandRow] ▶️ Run tapped for command: \(command.name)")
                selectedCommand = command
            } label: {
                Label("Run", systemImage: "play.fill")
            }
            
            Button {
                showingEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                viewModel.deleteCommand(command)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Divider()
            
            Button {
                var updatedCommand = command
                updatedCommand.isFavorite.toggle()
                viewModel.updateCommand(updatedCommand)
                print("[CommandRow] ⭐️ Toggled favorite for command: \(command.name)")
            } label: {
                Label(command.isFavorite ? "Unfavorite" : "Favorite",
                      systemImage: command.isFavorite ? "star.slash" : "star")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditCommandView(viewModel: viewModel, command: command)
        }
    }
}

struct ConnectionConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: QNAPManagerViewModel
    
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var password = ""
    
    // Add stored credentials state
    @State private var storedHost = UserDefaults.standard.string(forKey: "qnap_stored_host") ?? ""
    @State private var storedPort = UserDefaults.standard.string(forKey: "qnap_stored_port") ?? "22"
    @State private var storedUsername = UserDefaults.standard.string(forKey: "qnap_stored_username") ?? ""
    @State private var storedPassword = UserDefaults.standard.string(forKey: "qnap_stored_password") ?? ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Connection Details")) {
                    TextField("Host", text: $host)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .onAppear {
                            host = storedHost
                        }
                    
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                        .onAppear {
                            port = storedPort
                        }
                    
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .onAppear {
                            username = storedUsername
                        }
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .onAppear {
                            password = storedPassword
                        }
                }
            }
            .navigationTitle("Configure Connection")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    if let portNumber = Int(port) {
                        // Store credentials
                        UserDefaults.standard.set(host, forKey: "qnap_stored_host")
                        UserDefaults.standard.set(port, forKey: "qnap_stored_port")
                        UserDefaults.standard.set(username, forKey: "qnap_stored_username")
                        UserDefaults.standard.set(password, forKey: "qnap_stored_password")
                        
                        viewModel.saveConnection(SSHConnection(
                            host: host,
                            port: portNumber,
                            username: username,
                            password: password
                        ))
                    }
                    dismiss()
                }
                .disabled(host.isEmpty || username.isEmpty || password.isEmpty)
            )
        }
    }
}

struct NewCommandView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: QNAPManagerViewModel
    
    @State private var name = ""
    @State private var command = ""
    @State private var description = ""
    @State private var isFavorite = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Command Details")) {
                    TextField("Name", text: $name)
                    
                    TextField("Command", text: $command)
                        .autocapitalization(.none)
                    
                    TextField("Description", text: $description)
                    
                    Toggle("Favorite", isOn: $isFavorite)
                }
            }
            .navigationTitle("New Command")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    let newCommand = SSHCommand(
                        name: name,
                        command: command,
                        description: description,
                        isFavorite: isFavorite
                    )
                    viewModel.saveCommand(newCommand)
                    dismiss()
                }
                .disabled(name.isEmpty || command.isEmpty)
            )
        }
    }
}

struct EditCommandView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: QNAPManagerViewModel
    let command: SSHCommand
    
    @State private var name: String
    @State private var commandText: String
    @State private var description: String
    @State private var isFavorite: Bool
    
    init(viewModel: QNAPManagerViewModel, command: SSHCommand) {
        self.viewModel = viewModel
        self.command = command
        _name = State(initialValue: command.name)
        _commandText = State(initialValue: command.command)
        _description = State(initialValue: command.description)
        _isFavorite = State(initialValue: command.isFavorite)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Command Details")) {
                    TextField("Name", text: $name)
                    
                    TextField("Command", text: $commandText)
                        .autocapitalization(.none)
                    
                    TextField("Description", text: $description)
                    
                    Toggle("Favorite", isOn: $isFavorite)
                }
            }
            .navigationTitle("Edit Command")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    let updatedCommand = SSHCommand(
                        id: command.id,
                        name: name,
                        command: commandText,
                        description: description,
                        isFavorite: isFavorite,
                        lastExecuted: command.lastExecuted
                    )
                    viewModel.updateCommand(updatedCommand)
                    dismiss()
                }
                .disabled(name.isEmpty || commandText.isEmpty)
            )
        }
    }
}

#Preview {
    QNAPManagerView()
} 


