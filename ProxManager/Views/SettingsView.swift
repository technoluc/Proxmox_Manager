//
//  SettingsView.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 22/02/2024.
//

import Foundation
import SwiftUI
import Combine

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var LxcViewModel: LxcViewModel

//    @Environment(\.presentationMode) var presentationMode
    var onSave: (() -> Void)?
    
    var body: some View {
        ZStack {
            // 🌟 Background Gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            Form {
                Section(header: Text("Display Settings")) {
                    Toggle("Hide Offline Resources", isOn: $viewModel.hideOfflineResources)
                        .onChange(of: viewModel.hideOfflineResources) { newValue in
                            viewModel.saveSettings()
                        }
                    Toggle("Hide Stopped Resources", isOn: $viewModel.hideStoppedResources)
                        .onChange(of: viewModel.hideStoppedResources) { newValue in
                            viewModel.saveSettings()
                        }
                }
                
                Section(header: Text("Troubleshooting")) {
                    Button(action: viewModel.clearAuthenticationTicket) {
                        Text("Clear Authentication Ticket")
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: viewModel.removeHideOfflineResourcesKey) {
                        Text("Reset Display Settings")
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: viewModel.simulateTicketExpiration) {
                        Text("Simulate Ticket Expiration")
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .onAppear {
            Logger.shared.log("👤 User selected SettingsView")
        }
    }
}

// MARK: - Previews
#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environmentObject(LxcViewModel())
        }
    }
}
#endif

