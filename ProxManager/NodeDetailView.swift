//
//  NodeDetailView.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 04/03/2024.
//

import SwiftUI

struct NodeDetailView: View {
    let node: Node

    var body: some View {
        informationCard {
            VStack(spacing: 10) {
                Text("General").font(.title2).bold().padding(.top, 0)
                    .foregroundColor(.primary)

                Divider()

                HStack {
                    Text("Name:").bold()
                    Spacer()
                    Text(node.node).font(.headline)
                }
                HStack {
                    Text("Status:").bold()
                    Spacer()
                    Text(node.status).font(.headline)
                }
                HStack {
                    Text("Uptime:").bold()
                    Spacer()
                    Text(formatUptime(node.uptime)).font(.headline)
                }
            }
            VStack(spacing: 10) {
                Text("Usage ").font(.title2).bold().padding(.top, 0)
                    .foregroundColor(.primary)

                Divider()

                HStack {
                    Text("CPU Usage:").bold()
                    Spacer()
                    Text("\(node.cpu, specifier: "%.2f") of \(node.maxcpu)").font(.headline)
                }
                HStack {
                    Text("Memory Usage:").bold()
                    Spacer()
                    Text("\(formatBytes(node.mem)) of \(formatBytes(node.maxmem))").font(.headline)
                }
                HStack {
                    Text("Disk Usage:").bold()
                    Spacer()
                    Text("\(formatBytes(node.disk)) of \(formatBytes(node.maxdisk))").font(.headline)
                }

            }
        }
        informationCard {
            VStack(spacing: 10) {
                Text("Hardware").font(.title2).bold()
                    .foregroundColor(.primary)

                Divider()

                HStack {
                    Text("CPU Model:").bold()
                    Spacer()
                    Text(node.cpuModel ?? "Unknown").font(.headline)
                }
                HStack {
                    Text("CPU Speed:").bold()
                    Spacer()
                    Text("\(node.cpuMhz ?? "Unknown") MHz").font(.headline)
                }
                HStack {
                    Text("CPU Cores:").bold()
                    Spacer()
                    Text("\(node.cpuCores ?? 0)").font(.headline)
                }
                HStack {
                    Text("Total CPUs:").bold()
                    Spacer()
                    Text("\(node.cpus ?? 0)").font(.headline)
                }
                HStack {
                    Text("CPU Sockets:").bold()
                    Spacer()
                    Text("\(node.cpuSockets ?? 0)").font(.headline)
                }
            }.padding()
        }
        informationCard {
            VStack(spacing: 10) {
                Text("Kernel & OS").font(.title2).bold()
                    .foregroundColor(.primary)

                Divider()

                HStack {
                    Text("Kernel Version:").bold()
                    Spacer()
                    Text(node.currentKernelVersion ?? "Unknown").font(.headline)
                }
                HStack {
                    Text("PVE Version:").bold()
                    Spacer()
                    Text(node.pveVersion ?? "Unknown").font(.headline)
                }
                HStack {
                    Text("Boot Mode:").bold()
                    Spacer()
                    Text(node.bootMode ?? "Unknown").font(.headline)
                }
            }.padding()
        }
        informationCard {
            VStack(spacing: 10) {
                Text("Root File System").font(.title2).bold().padding(.top, 0)
                    .foregroundColor(.primary)
                
                Divider()
                
                HStack {
                    Text("Used:")
                        .bold()
                        .frame(width: 80, alignment: .leading) // Ensure alignment and width
                    Spacer()
                    // Display used space
                    Text(formatBytes(node.fileSystemUsed ?? 0))
                        .font(.headline)
                }
                HStack {
                    Text("Free:")
                        .bold()
                        .frame(width: 80, alignment: .leading) // Ensure alignment and width
                    Spacer()
                    // Display free space
                    Text(formatBytes(node.fileSystemFree ?? 0))
                        .font(.headline)
                }
                HStack {
                    Text("Total:")
                        .bold()
                        .frame(width: 80, alignment: .leading) // Ensure alignment and width
                    Spacer()
                    // Display total space
                    Text(formatBytes(node.fileSystemTotal ?? 0))
                        .font(.headline)
                }
                HStack {
                    Text("Available:")
                        .bold()
                        .frame(width: 80, alignment: .leading) // Ensure alignment and width
                    Spacer()
                    // Display available space
                    Text(formatBytes(node.fileSystemAvail ?? 0))
                        .font(.headline)
                }
            }
        }


    }
}

    
// MARK: - Previews

struct NodeDetails_Previews: PreviewProvider {
    static var previews: some View {
        DetailView_Previews.previews
    }
}
