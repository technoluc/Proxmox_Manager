//
//  SettingsView.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 22/02/2024.
//

import Foundation
import SwiftUI
import Combine

// The view used for displaying and editing the application's settings.
struct SettingsView: View {
    // Binding to the presentation mode of the view, allowing the view to dismiss itself.
    @Environment(\.presentationMode) var presentationMode
    // State variable indicating whether HTTPS should be used for network connections.
    @State private var useHTTPS: Bool = UserDefaults.standard.bool(forKey: "useHTTPS")
    // State variable storing the API address set by the user.
    @State private var apiAddress: String = UserDefaults.standard.string(forKey: "apiAddress") ?? ""
    // State variable storing the API ID set by the user.
    @State private var apiID: String = UserDefaults.standard.string(forKey: "apiID") ?? ""
    // State variable storing the API key set by the user.
    @State private var apiKey: String = UserDefaults.standard.string(forKey: "apiKey") ?? ""
    // Optional closure called when the save operation completes.
    var onSave: (() -> Void)?

    // The body of the SettingsView, containing all UI components for settings.
    var body: some View {
        Group {
            #if os(iOS)
            NavigationView {
                settingsForm()
                    .navigationBarTitle("Settings", displayMode: .inline)
                    .navigationBarItems(leading: Button("Back") {
                        presentationMode.wrappedValue.dismiss()
                    }.foregroundColor(.primary))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                saveSettings()
                                presentationMode.wrappedValue.dismiss()
                                onSave?()
                            }.foregroundColor(.primary)
                        }
                    }
            }
            #else
            settingsForm()
                .frame(minWidth: 500, idealWidth: 600, maxHeight: .infinity) // Adjusted for macOS
                .padding()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveSettings()
                            presentationMode.wrappedValue.dismiss()
                            onSave?()

                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            #endif
        }
//        .accentColor(.orange)
    }

    private func settingsForm() -> some View {
        Form {
            Section(header: Text("Welcome to ProxMan!").bold().foregroundColor(.primary)) {
                Text("Configure your settings below to get started.")
                    .padding(.vertical)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Section(header: Text("Connection Settings").foregroundColor(.primary)) {

                Toggle("Use HTTPS for secure connection", isOn: $useHTTPS)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .font(.caption)
                    .padding(.top)
                    .foregroundColor(.primary)

                HStack {
                    Text("API Address:")
                        .foregroundColor(.primary)
                        .font(.caption)
                    Spacer()
                    TextField("API Address (e.g., 10.0.1.11:8006)", text: $apiAddress)
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.trailing)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange, lineWidth: 2))
                        #if os(iOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        #endif
                }
                .padding(.vertical)

            }

            Section(header: Text("Authentication").foregroundColor(.primary)) {
                Text("""
                    Proxmox API credentials.
                    """)
//                    .padding(.horizontal)
                    .foregroundColor(.orange)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                HStack {
                    Text("API ID:")
                        .foregroundColor(.primary)
                        .font(.footnote)
                    Spacer()
                    TextField("e.g., api@pam!ProxManager", text: $apiID)
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.trailing)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange, lineWidth: 2))

                }
                VStack(alignment: .leading) {
                    Text("API Key:")
                        .foregroundColor(.primary)
                        .font(.footnote)
                    TextEditor(text: $apiKey)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange, lineWidth: 2))
                        .disableAutocorrection(true)
                        .foregroundColor(.primary)
                        .background(Color(uiColor: .systemBackground))
                        .padding(.bottom)
                }
            }
//            #if os(iOS)
//            Section {
//                Button("Save Settings") {
//                    saveSettings()
//                    presentationMode.wrappedValue.dismiss()
//                    onSave?()
//                }
//                .foregroundColor(.white)
//                .frame(maxWidth: .infinity)
//                .padding()
//                .background(Color.orange)
//                .cornerRadius(10)
//            }
//            #endif
        }
        #if os(iOS)
        .scrollContentBackground(.hidden) // Hides the scroll view's background.
        // .background(.orange)
        .background(Color.orange.opacity(0.8))

        #endif
    }

    // Saves the current settings to UserDefaults.
    private func saveSettings() {
        UserDefaults.standard.set(useHTTPS, forKey: "useHTTPS")
        UserDefaults.standard.set(apiAddress.lowercased(), forKey: "apiAddress")
        UserDefaults.standard.set(apiID, forKey: "apiID")
        UserDefaults.standard.set(apiKey, forKey: "apiKey")
    }
}

// MARK: - Previews

struct Settings_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView_Previews.previews
    }
}
