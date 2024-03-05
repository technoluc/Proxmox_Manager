//
//  QemuDetailView.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 04/03/2024.
//

import SwiftUI

struct QemuDetailView: View {
    let vm: VM

    var body: some View {
        Spacer()
        informationCard {
            VStack(spacing: 10) {
                Text("General").font(.title2).bold().padding(.top, 0)
                    .foregroundColor(.primary)

                Divider()
                
                HStack {
                    Text("Name:").bold()
                    Spacer()
                    Text("\(String(vm.name))").font(.headline)
                }
                HStack {
                    Text("VMID:").bold()
                    Spacer()
                    Text("\(String(vm.vmid))").font(.headline)
                }
                HStack {
                    Text("Node:").bold()
                    Spacer()
                    Text(vm.node).font(.headline)
                }
                HStack {
                    Text("Type:").bold()
                    Spacer()
                    Image(systemName: vm.type == "qemu" ? "shippingbox.fill" : "shippingbox").font(.headline)
                    Text(vm.type).font(.headline)
                }
                HStack {
                    Text("Uptime:").bold()
                    Spacer()
                    Text(formatUptime(vm.uptime)).font(.headline)
                }
                HStack {
                    Text("Template:").bold()
                    Spacer()
                    Text(vm.template ? "Yes" : "No").font(.headline)
                }
                // Add more properties as needed
            }
            VStack(spacing: 10) {
                Text("Usage ").font(.title2).bold().padding(.top, 0)
                    .foregroundColor(.primary)

                Divider()

                HStack {
                    Text("CPU Usage:").bold()
                    Spacer()
                    Text("\(vm.cpu, specifier: "%.2f") of \(vm.maxcpu)").font(.headline)
                }

                HStack {
                    Text("Memory Usage:").bold()
                    Spacer()
                    Text("\(formatBytes(vm.mem)) of \(formatBytes(vm.maxmem))").font(.headline)
                }

                HStack {
                    Text("Disk Usage:").bold()
                    Spacer()
                    Text("\(formatBytes(vm.disk)) of \(formatBytes(vm.maxdisk))").font(.headline)
                }

                HStack {
                    Text("Network In/Out:").bold()
                    Spacer()
                    Text("\(formatBytes(vm.netin))/\(formatBytes(vm.netout))").font(.headline)

                }

            }
            
            VStack(spacing: 10) {
                Text("Network ")
                    .font(.title2)
                    .bold()
                    .padding(.top, 0)
                    .foregroundColor(.primary)

                Divider()

                HStack {
                    Text("IP Address:").bold()
                    Spacer()
                    Text(vm.ipAddress ?? "Unavailable").font(.headline)
                }
            }
            
        }
    }
}


// MARK: - Previews

struct QemuDetailView_Previews: PreviewProvider {
    static var previews: some View {
        DetailView_Previews.previews
    }
}
