//
//  DetailView.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 04/03/2024.
//

import Foundation
import SwiftUI

// Define an enum to distinguish between model types
enum DetailType {
    case node(Node)
    case vm(VM)
    case container(VM) // Assuming Container uses the VM structure
}

struct DetailView: View {
    let detailType: DetailType

    private var sectionHeader: String {
        switch detailType {
        case .node( let node):
            return "\(node.node) Information"
        case .vm(let vm), .container(let vm):
            return "\(vm.name) Information"
        }
    }

    private var navigationTitle: String {
        switch detailType {
        case .node( let node):
            return "\(node.node) Details"
        case .vm(let vm), .container(let vm):
            return "\(vm.name) Details"
        }
    }

    var body: some View {
        ZStack {
            Color.orange.edgesIgnoringSafeArea(.all) // Set the overall background to orange

            ScrollView {
                VStack(spacing: 20) { // Add spacing between sections

                    switch detailType {
                    case .node(let node):
                        NodeDetailView(node: node)
                    case .vm(let vm), .container(let vm):
                        QemuDetailView(vm: vm)
                    }

                }
                // .padding() // Add padding around the VStack content
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}



// Helper function to format bytes into a more readable format
func formatBytes(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
}

// New helper function to format uptime into days, hours, minutes
func formatUptime(_ seconds: Int) -> String {
    let days = seconds / 86400
    let hours = (seconds % 86400) / 3600
    let minutes = (seconds % 3600) / 60
    return "\(days)d \(hours)h \(minutes)m"
}

// Reusable view modifier for framing content
struct informationCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(Color(UIColor.systemBackground)) // Set the card background color
            .opacity(0.6)
            .cornerRadius(10) // Round the corners of the card
            .shadow(radius: 5) // Add a shadow for depth
            .padding([.horizontal, .bottom]) // Add some spacing around the card
    }
}


// MARK: - Previews

struct Details_Previews: PreviewProvider {
    static var previews: some View {
        DetailView_Previews.previews
    }
}
