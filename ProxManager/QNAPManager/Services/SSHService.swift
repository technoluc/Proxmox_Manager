//
//
// SSHService.swift
//
//


import Foundation
import Citadel
import NIOCore
import NIOSSH

@MainActor
class SSHService: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading = false
    
    private var client: SSHClient?
    private let host: String
    private let port: Int
    private let username: String
    private let password: String
    
    init(host: String, port: Int = 22, username: String, password: String) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
    }
    
    func connect() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Configure algorithms to support older servers if needed
            var algorithms = SSHAlgorithms()
            algorithms.transportProtectionSchemes = .add([
                AES128CTR.self
            ])
            algorithms.keyExchangeAlgorithms = .add([
                DiffieHellmanGroup14Sha1.self,
                DiffieHellmanGroup14Sha256.self
            ])
            
            client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: .passwordBased(
                    username: username,
                    password: password
                ),
                hostKeyValidator: .acceptAnything(), // TODO: Implement proper host key validation
                reconnect: .never,
                algorithms: algorithms
            )
            
            isConnected = true
            lastError = nil
        } catch {
            isConnected = false
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func disconnect() {
        client = nil
        isConnected = false
    }
    
    func executeCommand(_ command: String) async throws -> String {
        guard let client = client else {
            throw SSHError.notConnected
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let buffer = try await client.executeCommand(command)
            let output = String(buffer: buffer) ?? ""
            print("[SSHService] ✅ Command: \(command)\n\(output)")
            lastError = nil
//            return String(buffer: buffer) ?? ""
            return output
        } catch let error as SSHClient.CommandFailed{
            print("[SSHService] ❌ Command failed (exit code: \(error.exitCode)) for: \(command)")
            lastError = error.localizedDescription
            throw error
        } catch {
            print("[SSHService] ❌ SSH error: \(error.localizedDescription)")
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func restartPlexServer() async throws -> String {
        do {
            let result = try await client?.executeCommand("/etc/init.d/plex.sh restart")
            return String(buffer: result ?? ByteBuffer()) ?? ""
        } catch let error as SSHClient.CommandFailed {
            print("[SSHService] ⚠️ Plex restart returned non-zero exit: \(error.exitCode)")
            throw error
        } catch {
            print("[SSHService] ❌ SSH error: \(error.localizedDescription)")
            throw error
        }
    }


    func validateConnection() async throws -> Bool {
        guard let client = client else {
            return false
        }
        
        do {
            let buffer = try await client.executeCommand("echo 'Connection test'")
            return (String(buffer: buffer) ?? "").contains("Connection test")
        } catch {
            return false
        }
    }
    
    func streamCommand(_ command: String) async throws -> AsyncThrowingStream<String, Error> {
        guard let client = client else {
            print("[SSHService] ❌ Cannot stream — no SSH client")
            throw SSHError.notConnected
        }

        print("[SSHService] 🔄 Starting stream for command: \(command)")

        let stream = try await client.executeCommandStream(command)

        return AsyncThrowingStream<String, Error> { continuation in
            Task {
                do {
                    for try await event in stream {
                        switch event {
                        case .stdout(let buffer), .stderr(let buffer):
                            let str = try String(buffer: buffer)
                            print("[SSHService] ⏩ Output: \(str)")
                            continuation.yield(str)
                        }
                    }
                    print("[SSHService] ✅ Stream finished for command: \(command)")
                    continuation.finish()
                } catch {
                    print("[SSHService] ❌ Stream failed: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

}

enum SSHError: LocalizedError {
    case notConnected
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to SSH server"
        }
    }
} 
