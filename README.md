# Proxmox_Manager
This is the public copy of my private repo. 

iOS app to interact with the PVE API. Can start, stop, reboot and shutdow Qemu VM's and LXC containers.

Made this because i wanted a simple app to start/stop containers and view their IP address. Too bad Proxmox doesnt have a (free) ios app. 

https://pve.proxmox.com/pve-docs/api-viewer/index.html


What the app can do:

| Fetch nodes        	| /api2/json/nodes                                                   	|
|--------------------	|--------------------------------------------------------------------	|
| Fetch vms          	| /api2/json/cluster/resources?type=vm (filter by vm)                	|
| Fetch containers   	| /api2/json/cluster/resources?type=vm (filter by container)         	|
| Fetch node details 	| /api2/json/nodes/{node}/status                                     	|
| Fetch CT IP        	| /api2/json/nodes/{node}/{type}/{vmid}/interfaces                   	|
| Fetch VM IP        	| /api2/json/nodes/{node}/{type}/{vmid}/agent/network-get-interfaces 	|



# Contributing

Please do!!

I'm not a developer, this is my first ios/swift/xcode app. please be kind, improve where possible and add functions bit by bit. 
