import Combine
import Foundation
import Security
import SwiftKeychainWrapper
import SwiftUI

enum AuthMethod: String {
    case none
    case ticketBased
    case tokenBased
}

enum AuthError: Error {
    case invalidCredentials
    case networkError
    case invalidResponse
    case ticketExpired
    case tokenExpired
    case noStoredCredentials
    case sslError
}

class ProxmoxAuthManager: NSObject {
    static let shared = ProxmoxAuthManager()
    private let logger = Logger.shared
    private var session: URLSession!
    
    private let keychain = KeychainWrapper.standard
    private let defaults = UserDefaults.standard
    
    private var authMethod: AuthMethod = .none
    fileprivate(set) var baseURL: String?
    private var username: String?
    private var ticket: String?
    private var csrfToken: String?
    private var tokenID: String?
    private var tokenSecret: String?
    private var ticketExpirationDate: Date?
    
    override private init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        logger.log("Initializing ProxmoxAuthManager", level: .debug)
        loadStoredCredentials()
    }
    
    // MARK: - Public Methods
    
    func isAuthenticated() -> Bool {
        let isAuth = authMethod != .none
        logger.log("Checking authentication status: \(isAuth)", level: .debug)
        return isAuth
    }
    
    func getAuthMethod() -> AuthMethod {
        logger.log("Current auth method: \(authMethod.rawValue)", level: .debug)
        return authMethod
    }
    
    func login(username: String, password: String, baseURL: String) async throws {
        logger.log("Attempting login with username: \(username)", level: .info)
        self.baseURL = baseURL
        self.username = username
        
        // Save password for ticket refresh
        do {
            try keychain.set(password, forKey: "password")
            logger.log("Saved password to keychain", level: .debug)
        } catch {
            logger.log("Failed to save password to keychain: \(error.localizedDescription)", level: .error)
        }
        
        // Try ticket-based authentication first
        do {
            try await authenticateWithTicket(username: username, password: password)
            await MainActor.run {
                self.authMethod = .ticketBased
                logger.log("Successfully logged in with ticket-based authentication", level: .info)
            }
        } catch {
            logger.log("Failed to login: \(error.localizedDescription)", level: .error)
            throw AuthError.invalidCredentials
        }
    }
    
    func loginWithToken(username: String, tokenID: String, tokenSecret: String, baseURL: String) async throws {
        logger.log("Attempting login with token for user: \(username)", level: .info)
        self.baseURL = baseURL
        self.username = username
        self.tokenID = tokenID
        self.tokenSecret = tokenSecret
        
        await MainActor.run {
            self.authMethod = .tokenBased
        }
        try saveCredentials()
        logger.log("Successfully logged in with token-based authentication", level: .info)
    }
    
    func logout() {
        logger.log("Logging out user", level: .info)
        clearCredentials()
        Task { @MainActor in
            self.authMethod = .none
            logger.log("Successfully logged out", level: .info)
        }
    }
    
    func refreshAuthenticationIfNeeded() async throws {
        logger.log("Checking if authentication refresh is needed", level: .debug)
        switch authMethod {
        case .ticketBased:
            if isTicketExpired() {
                logger.log("Ticket expired, attempting refresh", level: .info)
                try await refreshTicket()
            } else {
                logger.log("Ticket still valid, no refresh needed", level: .debug)
            }
        case .tokenBased:
            logger.log("Token-based auth doesn't need refresh", level: .debug)
        case .none:
            logger.log("No stored credentials found", level: .error)
            throw AuthError.noStoredCredentials
        }
    }
    
    func authHeaders() -> [String: String] {
        switch authMethod {
        case .ticketBased:
            guard let ticket = ticket else {
                logger.log("⚠️ No ticket available", level: .warning)
                return [:]
            }
            return ["Cookie": "PVEAuthCookie=\(ticket)"]
        case .tokenBased:
            guard let tokenID = tokenID, let secret = tokenSecret else {
                logger.log("⚠️ No token credentials available", level: .warning)
                return [:]
            }
            return ["Authorization": "PVEAPIToken=\(tokenID)=\(secret)"]
        case .none:
            logger.log("❌ No auth method set", level: .error)
            return [:]
        }
    }
    
    func getCSRFToken() -> String? {
        return csrfToken
    }

    // MARK: - Developer Utilities

    /// ⚠️ Developer-only: Simulate ticket expiration for testing refresh flow
    func simulateTicketExpired() {
        logger.log("🧪 Simulating ticket expiration (dev mode)", level: .debug)
        ticketExpirationDate = Date(timeIntervalSinceNow: -10) // Expired 10 seconds ago
    }

    // MARK: - Private Methods
    
    private func authenticateWithTicket(username: String, password: String) async throws {
        guard let baseURL = baseURL else {
            logger.log("No base URL configured", level: .error)
            throw AuthError.invalidResponse
        }
        
        logger.log("Authenticating with ticket for user: \(username)", level: .debug)
        let loginURL = "\(baseURL)/api2/json/access/ticket"
        var request = URLRequest(url: URL(string: loginURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "username=\(username)&password=\(password)"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.log("Invalid response type received", level: .error)
                throw AuthError.invalidResponse
            }
            
            logger.log("Received response with status code: \(httpResponse.statusCode)", level: .debug)
            
            if httpResponse.statusCode != 200 {
                if let errorString = String(data: data, encoding: .utf8) {
                    logger.log("Server returned error: \(errorString)", level: .error)
                }
                throw AuthError.invalidCredentials
            }
            
            guard !data.isEmpty else {
                logger.log("Received empty response data", level: .error)
                throw AuthError.invalidResponse
            }
            
            do {
                let decoder = JSONDecoder()
                let ticketResponse = try decoder.decode(TicketResponse.self, from: data)
                
                await MainActor.run {
                    self.ticket = ticketResponse.data.ticket
                    self.csrfToken = ticketResponse.data.CSRFPreventionToken
                    self.ticketExpirationDate = Date().addingTimeInterval(TimeInterval(ticketResponse.data.expirationTime))
                    self.authMethod = .ticketBased
                }
                
                logger.log("Successfully obtained ticket, expires in \(ticketResponse.data.expirationTime) seconds", level: .debug)
                try saveCredentials()
            } catch {
                logger.log("Failed to decode response: \(error.localizedDescription)", level: .error)
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.log("Raw response: \(responseString)", level: .debug)
                }
                throw AuthError.invalidResponse
            }
        } catch let error as URLError {
            if error.code == .serverCertificateUntrusted {
                logger.log("SSL certificate validation failed: \(error.localizedDescription)", level: .error)
                throw AuthError.sslError
            }
            logger.log("Network error: \(error.localizedDescription)", level: .error)
            throw AuthError.networkError
        }
    }
    
    private func refreshTicket() async throws {
        logger.log("Starting ticket refresh process", level: .debug)
        
        // First verify we have a username
        guard let username = username else {
            logger.log("No username found for ticket refresh", level: .error)
            throw AuthError.noStoredCredentials
        }
        logger.log("Found username for refresh: \(username)", level: .debug)
        
        // Then try to get the password
        guard let password = try? keychain.string(forKey: "password") else {
            logger.log("No stored password found in keychain for ticket refresh", level: .error)
            throw AuthError.noStoredCredentials
        }
        logger.log("Found password in keychain for refresh", level: .debug)
        
        logger.log("Refreshing ticket for user: \(username)", level: .info)
        try await authenticateWithTicket(username: username, password: password)
    }
    
    private func isTicketExpired() -> Bool {
        guard let expirationDate = ticketExpirationDate else {
            logger.log("No expiration date found for ticket", level: .debug)
            return true
        }
        let isExpired = Date() >= expirationDate
        logger.log("Ticket expiration check: \(isExpired)", level: .debug)
        return isExpired
    }
    
    // MARK: - Keychain Operations
    
    private func saveCredentials() throws {
        logger.log("Saving credentials to secure storage", level: .debug)
        
        // Save non-sensitive data to UserDefaults
        if let username = username {
            defaults.set(username, forKey: "username")
            logger.log("Saved username: \(username)", level: .debug)
        }
        
        if let baseURL = baseURL {
            defaults.set(baseURL, forKey: "baseURL")
            logger.log("Saved baseURL: \(baseURL)", level: .debug)
        }
        
        if let expirationDate = ticketExpirationDate {
            defaults.set(expirationDate, forKey: "ticketExpirationDate")
            logger.log("Saved expiration date: \(expirationDate)", level: .debug)
        }
        
        // Save csrfToken
        if let csrf = csrfToken {
            defaults.set(csrf, forKey: "csrfToken")
            logger.log("Saved CSRFPreventionToken", level: .debug)
        }

        // Save auth method synchronously since it's critical for state
        defaults.set(authMethod.rawValue, forKey: "authMethod")
        logger.log("Saved auth method: \(authMethod.rawValue)", level: .debug)
        
        // Save sensitive data to Keychain
        if let ticket = ticket {
            let success = try keychain.set(ticket, forKey: "ticket")
            logger.log("Saved ticket: \(success ? "success" : "failed")", level: .debug)
        }
        
        if let tokenID = tokenID {
            let success = try keychain.set(tokenID, forKey: "tokenID")
            logger.log("Saved tokenID: \(success ? "success" : "failed")", level: .debug)
        }
        
        if let tokenSecret = tokenSecret {
            let success = try keychain.set(tokenSecret, forKey: "tokenSecret")
            logger.log("Saved tokenSecret: \(success ? "success" : "failed")", level: .debug)
        }
        
        // Verify saved data
        verifySavedCredentials()
    }
    
    private func loadStoredCredentials() {
        logger.log("Loading stored credentials", level: .debug)
        
        // Load non-sensitive data from UserDefaults
        username = defaults.string(forKey: "username")
        baseURL = defaults.string(forKey: "baseURL")
        ticketExpirationDate = defaults.object(forKey: "ticketExpirationDate") as? Date

        if let savedCSRF = defaults.string(forKey: "csrfToken") {
            csrfToken = savedCSRF
            logger.log("Loaded CSRFPreventionToken from UserDefaults", level: .debug)
        } else {
            logger.log("No stored CSRFPreventionToken found", level: .debug)
        }

        
        if let methodRaw = defaults.string(forKey: "authMethod"),
           let method = AuthMethod(rawValue: methodRaw)
        {
            authMethod = method
            logger.log("Loaded auth method: \(method.rawValue)", level: .debug)
        } else {
            logger.log("No stored auth method found", level: .debug)
        }
        
        // Load sensitive data from Keychain
        do {
            ticket = try keychain.string(forKey: "ticket")
            tokenID = try keychain.string(forKey: "tokenID")
            tokenSecret = try keychain.string(forKey: "tokenSecret")
            
            // Also try to load password if using ticket auth
            if authMethod == .ticketBased {
                if let _ = try? keychain.string(forKey: "password") {
                    logger.log("Loaded password from keychain: success", level: .debug)
                } else {
                    logger.log("Loaded password from keychain: not found", level: .debug)
                }
            }
            
            logger.log("Loaded ticket: \(ticket != nil ? "success" : "not found")", level: .debug)
            logger.log("Loaded tokenID: \(tokenID != nil ? "success" : "not found")", level: .debug)
            logger.log("Loaded tokenSecret: \(tokenSecret != nil ? "success" : "not found")", level: .debug)
        } catch {
            logger.log("Error loading keychain data: \(error.localizedDescription)", level: .error)
        }
        
        // Verify loaded data
        verifyLoadedCredentials()
    }
    
    private func verifySavedCredentials() {
        logger.log("Verifying saved credentials...", level: .debug)
        
        // Verify UserDefaults
        let savedUsername = defaults.string(forKey: "username")
        let savedBaseURL = defaults.string(forKey: "baseURL")
        let savedMethod = defaults.string(forKey: "authMethod")
        
        logger.log("Saved username matches: \(savedUsername == username)", level: .debug)
        logger.log("Saved baseURL matches: \(savedBaseURL == baseURL)", level: .debug)
        logger.log("Saved auth method matches: \(savedMethod == authMethod.rawValue)", level: .debug)
        
        // Verify Keychain
        do {
            let savedTicket = try keychain.string(forKey: "ticket")
            logger.log("Saved ticket matches: \(savedTicket == ticket)", level: .debug)
            
            // Verify password is in keychain if using ticket auth
            if authMethod == .ticketBased {
                let hasPassword = (try? keychain.string(forKey: "password")) != nil
                logger.log("Password saved in keychain: \(hasPassword)", level: .debug)
            }
        } catch {
            logger.log("Error verifying saved ticket: \(error.localizedDescription)", level: .error)
        }
    }
    
    private func verifyLoadedCredentials() {
        logger.log("Verifying loaded credentials...", level: .debug)
        
        // Verify UserDefaults
        let loadedUsername = defaults.string(forKey: "username")
        let loadedBaseURL = defaults.string(forKey: "baseURL")
        let loadedMethod = defaults.string(forKey: "authMethod")
        
        logger.log("Loaded username matches: \(loadedUsername == username)", level: .debug)
        logger.log("Loaded baseURL matches: \(loadedBaseURL == baseURL)", level: .debug)
        logger.log("Loaded auth method matches: \(loadedMethod == authMethod.rawValue)", level: .debug)
        
        // Verify Keychain
        do {
            let loadedTicket = try keychain.string(forKey: "ticket")
            logger.log("Loaded ticket matches: \(loadedTicket == ticket)", level: .debug)
            
            // Verify password is in keychain if using ticket auth
            if authMethod == .ticketBased {
                let hasPassword = (try? keychain.string(forKey: "password")) != nil
                logger.log("Password loaded from keychain: \(hasPassword)", level: .debug)
            }
        } catch {
            logger.log("Error verifying loaded ticket: \(error.localizedDescription)", level: .error)
        }
    }
    
    private func clearCredentials() {
        logger.log("Clearing stored credentials", level: .debug)
        defaults.removeObject(forKey: "username")
        defaults.removeObject(forKey: "baseURL")
        defaults.removeObject(forKey: "ticketExpirationDate")
        defaults.removeObject(forKey: "authMethod")
        
        try? keychain.removeObject(forKey: "ticket")
        try? keychain.removeObject(forKey: "tokenID")
        try? keychain.removeObject(forKey: "tokenSecret")
        try? keychain.removeObject(forKey: "password") // Also clear password when clearing credentials
        defaults.removeObject(forKey: "csrfToken")

        
        username = nil
        baseURL = nil
        ticket = nil
        tokenID = nil
        tokenSecret = nil
        ticketExpirationDate = nil
        logger.log("Successfully cleared all credentials", level: .debug)
    }
}

// MARK: - URLSession Delegate

extension ProxmoxAuthManager: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            logger.log("No server trust available", level: .error)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Accept self-signed certificates
        let credential = URLCredential(trust: serverTrust)
        logger.log("Accepting server certificate", level: .debug)
        completionHandler(.useCredential, credential)
    }
}

// MARK: - Response Models

struct TicketResponse: Codable {
    let data: TicketData
}

struct TicketData: Codable {
    let ticket: String
    let expires: Int?
    let CSRFPreventionToken: String
    
    // Default expiration time of 2 hours if not provided
    var expirationTime: Int {
        return expires ?? 7200 // 2 hours in seconds
    }
}
