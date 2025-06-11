//
//
// QNAPManagerViewModel.swift
//
//


import Foundation
import SwiftUI


@MainActor
class QNAPManagerViewModel: ObservableObject {
    @Published var savedCommands: [SSHCommand] = []
    @Published var connection: SSHConnection?
    @Published var isConnected = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var lastExecutedCommand: SSHCommand?
    @Published var liveOutput: String = ""
    @Published var isStreaming: Bool = false
    
    private var sshService: SSHService?
    private let commandsKey = "saved_ssh_commands"
    private let connectionKey = "qnap_connection"
    
    init() {
        loadSavedCommands()
        loadConnection()
        if connection != nil {
            Task {
                await connectToServer()
            }
        }
    }
    
    func saveConnection(_ connection: SSHConnection) {
        self.connection = connection
        sshService = SSHService(
            host: connection.host,
            port: connection.port,
            username: connection.username,
            password: connection.password
        )
        
        if let encoded = try? JSONEncoder().encode(connection) {
            UserDefaults.standard.set(encoded, forKey: connectionKey)
        }
        
        Task {
            await connectToServer()
        }
    }
    
    private func connectToServer() async {
        guard let sshService = sshService else { return }
        
        do {
            try await sshService.connect()
            isConnected = true
            errorMessage = nil
        } catch {
            isConnected = false
            errorMessage = "Failed to connect: \(error.localizedDescription)"
        }
    }
    
    private func loadConnection() {
        guard let data = UserDefaults.standard.data(forKey: connectionKey),
              let connection = try? JSONDecoder().decode(SSHConnection.self, from: data) else {
            return
        }
        self.connection = connection
        sshService = SSHService(
            host: connection.host,
            port: connection.port,
            username: connection.username,
            password: connection.password
        )
    }
    
    func saveCommand(_ command: SSHCommand) {
        if !savedCommands.contains(where: { $0.id == command.id }) {
            savedCommands.append(command)
            saveToDisk()
        }
    }
    
    func updateCommand(_ command: SSHCommand) {
        if let index = savedCommands.firstIndex(where: { $0.id == command.id }) {
            savedCommands[index] = command
            saveToDisk()
        }
    }
    
    func deleteCommand(_ command: SSHCommand) {
        savedCommands.removeAll { $0.id == command.id }
        saveToDisk()
    }
    
    func executeCommand(_ command: SSHCommand) async {
        guard let sshService = sshService else {
            errorMessage = "No SSH connection configured"
            return
        }
        
        if !isConnected {
            await connectToServer()
            guard isConnected else { return }
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await sshService.executeCommand(command.command)
            var updatedCommand = command
            updatedCommand.lastExecuted = Date()
            updateCommand(updatedCommand)
            lastExecutedCommand = updatedCommand
            errorMessage = nil
            print("Command executed successfully: \(result)")
        } catch {
            errorMessage = error.localizedDescription
            let reconnected = await reconnectIfNeeded()
            if !reconnected {
                errorMessage = "Failed to reconnect: \(error.localizedDescription)"
            }
        }
    }
    
    func streamCommandOutput(_ command: SSHCommand) async {
        guard let sshService = sshService else {
            print("[ViewModel] ❌ No SSH service configured")
            errorMessage = "No SSH connection configured"
            return
        }
        print("[ViewModel] ▶️ streamCommandOutput started for \(command.name)")

        liveOutput = ""
        
        if !isConnected {
            print("[ViewModel] 🔌 Not connected — reconnecting...")

            await connectToServer()
            guard isConnected else {
                print("[ViewModel] ❌ Reconnect failed")
                return
            }
        }

        do {
            let stream = try await sshService.streamCommand(command.command)
            for try await line in stream {
                await MainActor.run {
                    print("[ViewModel] 📝 Appending line to liveOutput: \(line)")
                    self.liveOutput += line
                }
            }
            var updatedCommand = command
            updatedCommand.lastExecuted = Date()
            updateCommand(updatedCommand)
            lastExecutedCommand = updatedCommand
            print("[ViewModel] ✅ Finished streaming command: \(command.name)")
        } catch {
            print("[ViewModel] ❌ Error during streaming: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func restartPlex() async {
        guard let sshService = sshService else {
            errorMessage = "No SSH connection configured"
            return
        }

        if !isConnected {
            await connectToServer()
            guard isConnected else { return }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let output = try await sshService.restartPlexServer()
            print("[ViewModel] ✅ Plex restarted:\n\(output)")
            errorMessage = nil
        } catch {
            print("[ViewModel] ❌ restartPlex failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

//    func restartPlex() async {
//        guard let sshService = sshService else {
//            errorMessage = "No SSH connection configured"
//            return
//        }
//        
//        if !isConnected {
//            await connectToServer()
//            guard isConnected else { return }
//        }
//        
//        isLoading = true
//        defer { isLoading = false }
//        
//        do {
//            let result = try await sshService.restartPlexServer()
//            errorMessage = nil
//            print("Plex server restarted: \(result)")
//        } catch {
//            print("[ViewModel] ❌ restartPlex failed: \(error.localizedDescription)")
//            errorMessage = error.localizedDescription
//            let reconnected = await reconnectIfNeeded()
//            if !reconnected {
//                errorMessage = "Failed to reconnect: \(error.localizedDescription)"
//            }
//        }
//    }
    
    private func reconnectIfNeeded() async -> Bool {
        guard let sshService = sshService else { return false }
        
        do {
            let isValid = try await sshService.validateConnection()
            if !isValid {
                await connectToServer()
            }
            return isConnected
        } catch {
            await connectToServer()
            return isConnected
        }
    }
    
    private func saveToDisk() {
        if let encoded = try? JSONEncoder().encode(savedCommands) {
            UserDefaults.standard.set(encoded, forKey: commandsKey)
        }
    }
    
    private func loadSavedCommands() {
        if let data = UserDefaults.standard.data(forKey: commandsKey),
           let decoded = try? JSONDecoder().decode([SSHCommand].self, from: data) {
            savedCommands = decoded
        }
    }
} 
