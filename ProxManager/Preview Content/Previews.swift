//
//  Previews.swift
//  ProxManager
//
//  Created by Luc Kurstjens on 04/03/2024.
//

import SwiftUI

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewLayout(.device)
                .previewDevice("iPhone 15 Pro")
                .previewDisplayName("Default")
                .onAppear {
                    // Sets default values for user defaults used in the app.
                    UserDefaults.standard.set(true, forKey: "useHTTPS")
                    UserDefaults.standard.set("10.0.1.11:8006", forKey: "apiAddress")
                    UserDefaults.standard.set("api@pam!proxman", forKey: "apiID")
                    UserDefaults.standard.set("MY_API_KEY_HERE", forKey: "apiKey")
                }

            SettingsView()
                .previewLayout(.device)
                .previewDisplayName("SettingsView")

            ContentView()
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Dark Mode")

            ContentView()
                .environment(\.colorScheme, .light)
                .previewDisplayName("Light Mode")


        }
    }
}
#endif


struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .onAppear {
                // Sets default values for user defaults used in the app.
                UserDefaults.standard.set(true, forKey: "useHTTPS")
                    UserDefaults.standard.set("10.0.1.11:8006", forKey: "apiAddress")
                    UserDefaults.standard.set("api@pam!proxman", forKey: "apiID")
                    UserDefaults.standard.set("MY_API_KEY_HERE", forKey: "apiKey")
            }
            .previewDisplayName("Dashboard")
        
        DetailView(detailType: .vm(VM(id: "qemu/9912", vmid: 9912, name: "monterey", status: "running", node: "pve3", type: "qemu", disk: 0, cpu: 0.0259939602248228, diskread: 19071652352, diskwrite: 31918374912, mem: 19524018563, maxcpu: 16, maxmem: 68719476736, maxdisk: 103079215104, netin: 1877166238, netout: 214963689, uptime: 629659, template: false, tags: nil, ipAddress: "10.0.1.210", runningDetails: nil)))
            .previewDisplayName("Qemu Details")
        
        DetailView(detailType: .vm(VM(id: "lxc/100", vmid: 100, name: "docker", status: "running", node: "pve1", type: "lxc", disk: 0, cpu: 0.0259939602248228, diskread: 19071652352, diskwrite: 31918374912, mem: 19524018563, maxcpu: 16, maxmem: 68719476736, maxdisk: 103079215104, netin: 1877166238, netout: 214963689, uptime: 629659, template: false, tags: nil, ipAddress: "10.0.1.3", runningDetails: nil)))
            .previewDisplayName("LXC Details")
        
        DetailView(detailType: .node(Node(type: "pve3", node: "pve3", level: "Node 3", id: "", sslFingerprint: "SSL Fingerprin4", status: "online", mem: Int(0.0123508954399194), maxmem: 23064555520, cpu: 8960327680, maxcpu: 32, disk: 135112847360, maxdisk: 33501757440, uptime: 1075850)))
            .previewDisplayName("Node Details")
        
        SettingsView()
            .previewDisplayName("Settings")

    }
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .previewDisplayName("SettingsView")
            .onAppear {
                // Sets default values for user defaults used in the app.
                UserDefaults.standard.set(true, forKey: "useHTTPS")
                    UserDefaults.standard.set("10.0.1.11:8006", forKey: "apiAddress")
                    UserDefaults.standard.set("api@pam!proxman", forKey: "apiID")
                    UserDefaults.standard.set("MY_API_KEY_HERE", forKey: "apiKey")
            }

    }
}
