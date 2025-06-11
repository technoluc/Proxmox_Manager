//
//  ProxmoxViews.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 21/02/2024.
//  (Modern UI update for iOS 18+ using SwiftUI – refined glass look)
//
//
import Foundation
import SwiftUI

public struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.2),
                                        Color.purple.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}

// MARK: - OverviewWidgetView

struct OverviewWidgetView: View {
    var title: String
    var type: String
    var count: Int
    var totalCount: Int
    var statusColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(type)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(count)/\(totalCount)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(statusColor)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    statusColor.opacity(0.3),
                                    statusColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

/// A system usage widget with a progress bar
struct SystemUsageView: View {
    var title: String
    var value: Double
    var max: Double
    var unit: String
    var color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(Int(value)) / \(Int(max)) \(unit)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            ProgressView(value: value, total: max)
                .progressViewStyle(.linear)
                .tint(color)
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.3),
                                    color.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Color Scheme
extension Color {
    static let proxmoxPrimary = Color.blue
    static let proxmoxSecondary = Color.purple
    static let proxmoxAccent = Color.orange
    
    static let proxmoxSuccess = Color.green
    static let proxmoxWarning = Color.orange
    static let proxmoxError = Color.red
    
    static let proxmoxBackground = Color(.systemBackground)
    static let proxmoxSecondaryBackground = Color(.secondarySystemBackground)
    static let proxmoxTertiaryBackground = Color(.tertiarySystemBackground)
}

// MARK: - Material Styles
struct ProxmoxMaterialStyle {
    static let card = Material.ultraThinMaterial
    static let cardBorder = LinearGradient(
        colors: [
            Color.proxmoxPrimary.opacity(0.2),
            Color.proxmoxSecondary.opacity(0.2)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardBorderWidth: CGFloat = 1
    static let cardCornerRadius: CGFloat = 16
    static let cardShadow = Color.black.opacity(0.1)
    static let cardShadowRadius: CGFloat = 5
    static let cardShadowY: CGFloat = 2
}

// MARK: - Preview

struct ProxmoxViews_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            OverviewWidgetView(
                title: "Active Nodes",
                type: "Nodes",
                count: 3,
                totalCount: 5,
                statusColor: .green
            )
            
            SystemUsageView(
                title: "CPU Usage",
                value: 75,
                max: 100,
                unit: "%",
                color: .blue
            )
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
