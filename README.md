# Proxmox_Manager
iOS app to interact with the PVE API. Can start, stop, reboot and shutdow Qemu VM's and LXC containers

https://pve.proxmox.com/pve-docs/api-viewer/index.html

This is the public copy of my private repo. 

What the app can do:

| Fetch nodes        	| /api2/json/nodes                                                   	|
|--------------------	|--------------------------------------------------------------------	|
| Fetch vms          	| /api2/json/cluster/resources?type=vm (filter by vm)                	|
| Fetch containers   	| /api2/json/cluster/resources?type=vm (filter by container)         	|
| Fetch node details 	| /api2/json/nodes/{node}/status                                     	|
| Fetch CT IP        	| /api2/json/nodes/{node}/{type}/{vmid}/interfaces                   	|
| Fetch VM IP        	| /api2/json/nodes/{node}/{type}/{vmid}/agent/network-get-interfaces 	|
|                    	|                                                                    	|

