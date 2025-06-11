//
//  LiveOutputView.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 25/03/2025.
//

import Foundation
import Combine
import SwiftUI

struct LiveOutputView: View {
    @ObservedObject var viewModel: QNAPManagerViewModel
    let command: SSHCommand
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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
            
            VStack(alignment: .leading, spacing: 16) {
                // Command Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Running: \(command.name)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(command.command)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                
                // Output Display
                ScrollView {
                    Text(viewModel.liveOutput)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
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
            .padding()
        }
        .onAppear {
            print("[LiveOutputView] 📺 View appeared for command: \(command.name)")
            viewModel.liveOutput = "" // clear output on each appearance
            Task {
                await viewModel.streamCommandOutput(command)
            }
        }
        .navigationTitle("Live Output")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    print("[LiveOutputView] ❌ Closed Live Output View")
                    dismiss()
                }
                .foregroundStyle(.primary)
            }
        }
        .onDisappear {
            print("[LiveOutputView] 👋 Disappeared — resetting viewModel")
            viewModel.isStreaming = false
            viewModel.liveOutput = ""
        }
    }
}
