//
//  LoginView.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 24/03/2025.
//


import SwiftUI

struct LoginView: View {
    // MARK: - State
    @State private var username = ""
    @State private var password = ""
    @State private var tokenID = ""
    @State private var tokenSecret = ""
    @State private var baseURL = ""
    @State private var isTokenLogin = false
    @State private var useHTTPS = UserDefaults.standard.bool(forKey: "useHTTPS")
    @State private var storedBaseURL = UserDefaults.standard.string(forKey: "storedBaseURL") ?? ""
    @State private var storedUsername = UserDefaults.standard.string(forKey: "storedUsername") ?? ""
    @State private var storedPassword = UserDefaults.standard.string(forKey: "storedPassword") ?? ""
    @State private var storedTokenID = UserDefaults.standard.string(forKey: "storedTokenID") ?? ""
    @State private var storedTokenSecret = UserDefaults.standard.string(forKey: "storedTokenSecret") ?? ""

    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var isLoading = false

    private let authManager = ProxmoxAuthManager.shared
    private let logger = Logger.shared
    
    // MARK: - Constants
    private let cardPadding: CGFloat = 16
    private let buttonHeight: CGFloat = 44 // Apple's minimum touch target size
    private let spacing: CGFloat = 12

    // MARK: - View
    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: spacing * 2) {
                    titleSection
                    statusSection
                    formSection
                    actionButtons
                }
                .padding()
            }
        }
        .alert("Authentication", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Components

    private var background: some View {
        LinearGradient(
            gradient: Gradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var titleSection: some View {
        Text("Proxmox Login")
            .font(.largeTitle.bold())
            .foregroundColor(.primary)
            .padding(.top)
    }

    private var formSection: some View {
        CardView {
            VStack(spacing: spacing) {
                // Server Configuration
                VStack(alignment: .leading, spacing: spacing) {
                    Text("Server Configuration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    #if os(iOS)
                    TextField("Server Address (e.g. 10.0.0.1:8006)", text: $baseURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            baseURL = storedBaseURL
                        }
                    #else
                    TextField("Server Address (e.g. 10.0.0.1:8006)", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            baseURL = storedBaseURL
                        }
                    #endif
                    
                    Toggle("Use HTTPS", isOn: $useHTTPS)
                        .onChange(of: useHTTPS) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "useHTTPS")
                        }
                }
                
                Divider()
                
                // Authentication Method
                VStack(alignment: .leading, spacing: spacing) {
                    Text("Authentication Method")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Picker("Authentication", selection: $isTokenLogin) {
                        Text("Username / Password").tag(false)
                        Text("API Token").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Divider()
                
                // Credentials
                VStack(alignment: .leading, spacing: spacing) {
                    Text("Credentials")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("Username", text: $username)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            username = storedUsername
                        }

                    if isTokenLogin {
                        TextField("Token ID", text: $tokenID)
                            #if os(iOS)
                            .autocapitalization(.none)
                            #endif
                            .textFieldStyle(.roundedBorder)
                            .onAppear {
                                tokenID = storedTokenID
                            }
                        SecureField("Token Secret", text: $tokenSecret)
                            .textFieldStyle(.roundedBorder)
                            .onAppear {
                                tokenSecret = storedTokenSecret
                            }
                    } else {
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .onAppear {
                                password = storedPassword
                            }
                    }
                }
            }
            .padding(cardPadding)
        }
    }

    private var actionButtons: some View {
        CardView {
            VStack(spacing: spacing) {
                Button(action: login) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Login", systemImage: "arrow.right.circle.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidInput || isLoading)

                HStack(spacing: spacing) {
                    Button(action: logout) {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                            .frame(height: buttonHeight)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!authManager.isAuthenticated())

                    Button(action: refreshAuth) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .frame(height: buttonHeight)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!authManager.isAuthenticated())
                }
            }
            .padding(cardPadding)
        }
    }

    private var statusSection: some View {
        Group {
            if authManager.isAuthenticated() {
                CardView {
                    HStack(spacing: spacing) {
                        Label("Authenticated", systemImage: "checkmark.shield")
                            .foregroundColor(.green)
                        Spacer()
                        Text(authManager.getAuthMethod().rawValue.capitalized)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(cardPadding)
                }
            }
        }
    }

    // MARK: - Logic

    private var isValidInput: Bool {
        !baseURL.isEmpty && !username.isEmpty &&
        (isTokenLogin
         ? !tokenID.isEmpty && !tokenSecret.isEmpty
         : !password.isEmpty)
    }

    private func getFullURL() -> String {
        let cleanURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if useHTTPS {
            return cleanURL.hasPrefix("https://") ? cleanURL : "https://\(cleanURL)"
        } else {
            return cleanURL.hasPrefix("http://") ? cleanURL : "http://\(cleanURL)"
        }
    }

    private func login() {
        Logger.shared.log("Login initiated", level: .info)
        isLoading = true

        // Store credentials
        UserDefaults.standard.set(baseURL, forKey: "storedBaseURL")
        UserDefaults.standard.set(username, forKey: "storedUsername")
        if isTokenLogin {
            UserDefaults.standard.set(tokenID, forKey: "storedTokenID")
            UserDefaults.standard.set(tokenSecret, forKey: "storedTokenSecret")
        } else {
            UserDefaults.standard.set(password, forKey: "storedPassword")
        }

        Task {
            do {
                if isTokenLogin {
                    try await authManager.loginWithToken(
                        username: username,
                        tokenID: tokenID,
                        tokenSecret: tokenSecret,
                        baseURL: getFullURL()
                    )
                } else {
                    try await authManager.login(
                        username: username,
                        password: password,
                        baseURL: getFullURL()
                    )
                }
                show("Login successful!")
            } catch {
                show("Login failed: \(error.localizedDescription)")
            }
        }
    }

    private func logout() {
        Logger.shared.log("Logging out", level: .info)
        authManager.logout()
        show("Logged out successfully.")
    }

    private func refreshAuth() {
        Logger.shared.log("Refreshing authentication", level: .info)
        isLoading = true

        Task {
            do {
                try await authManager.refreshAuthenticationIfNeeded()
                show("Authentication refreshed.")
            } catch {
                show("Refresh failed: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func show(_ message: String) {
        alertMessage = message
        showAlert = true
        isLoading = false
    }
}

#if DEBUG
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
#endif

