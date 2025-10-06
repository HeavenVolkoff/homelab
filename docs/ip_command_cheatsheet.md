# ip COMMAND CHEAT SHEET

> Originally in PDF [here](https://access.redhat.com/sites/default/files/attachments/rh_ip_command_cheatsheet_1214_jcs_print.pdf)

### **IP QUERIES**

| SUBCOMMAND | DESCRIPTIONS AND TASKS                                                    |
| ---------- | ------------------------------------------------------------------------- |
| **addr**   | Display IP Addresses and property information (abbreviation of address)   |
|            | `ip addr` <br> Show information for all addresses                         |
|            | `ip addr show dev em1` <br> Display information only for device em1       |
| **link**   | Manage and display the state of all network interfaces                    |
|            | `ip link` <br> Show information for all interfaces                        |
|            | `ip link show dev em1` <br> Display information only for device em1       |
|            | `ip -s link` <br> Display interface statistics                            |
| **route**  | Display and alter the routing table                                       |
|            | `ip route` <br> List all of the route entries in the kernel               |
| **maddr**  | Manage and display multicast IP addresses                                 |
|            | `ip maddr` <br> Display multicast information for all devices             |
|            | `ip maddr show dev em1` <br> Display multicast information for device em1 |
| **neigh**  | Show neighbour objects; also known as the ARP table for IPv4              |
|            | `ip neigh` <br> Display neighbour objects                                 |
|            | `ip neigh show dev em1` <br> Show the ARP cache for device em1            |
| **help**   | Display a list of commands and arguments for each subcommand              |
|            | `ip help` <br> Display ip commands and arguments                          |
|            | `ip addr help` <br> Display address commands and arguments                |
|            | `ip link help` <br> Display link commands and arguments                   |
|            | `ip neigh help` <br> Display neighbour commands and arguments             |

### **MULTICAST ADDRESSING**

| SUBCOMMAND    | DESCRIPTIONS AND TASKS                                                                       |
| ------------- | -------------------------------------------------------------------------------------------- |
| **maddr add** | Add a static link-layer multicast address                                                    |
|               | `ip maddr add 33:33:00:00:00:01 dev em1` <br> Add multicast address 33:33:00:00:00:01 to em1 |
| **maddr del** | Delete a multicast address                                                                   |
|               | `ip maddr del 33:33:00:00:00:01 dev em1` <br> Delete address 33:33:00:00:00:01 from em1      |

### **MODIFYING ADDRESS AND LINK PROPERTIES**

| SUBCOMMAND   | DESCRIPTIONS AND TASKS                                                                          |
| ------------ | ----------------------------------------------------------------------------------------------- |
| **addr add** | Add an address                                                                                  |
|              | `ip addr add 192.168.1.1/24 dev em1` <br> Add address 192.168.1.1 with netmask 24 to device em1 |
| **addr del** | Delete an address                                                                               |
|              | `ip addr del 192.168.1.1/24 dev em1` <br> Remove address 192.168.1.1/24 from device em1         |
| **link set** | Alter the status of the interface                                                               |
|              | `ip link set em1 up` <br> Bring em1 online                                                      |
|              | `ip link set em1 down` <br> Bring em1 offline                                                   |
|              | `ip link set em1 mtu 9000` <br> Set the MTU on em1 to 9000                                      |
|              | `ip link set em1 promisc on` <br> Enable promiscuous mode for em1                               |

### **ADJUSTING AND VIEWING ROUTES**

| SUBCOMMAND        | DESCRIPTIONS AND TASKS                                                                                                                                          |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **route add**     | Add an entry to the routing table                                                                                                                               |
|                   | `ip route add default via 192.168.1.1 dev em1` <br> Add a default route (for all addresses) via the local gateway 192.168.1.1 that can be reached on device em1 |
|                   | `ip route add 192.168.1.0/24 via 192.168.1.1` <br> Add a route to 192.168.1.0/24 via the gateway at 192.168.1.1                                                 |
|                   | `ip route add 192.168.1.0/24 dev em1` <br> Add a route to 192.168.1.0/24 that can be reached on device em1                                                      |
| **route delete**  | Delete a routing table entry                                                                                                                                    |
|                   | `ip route delete 192.168.1.0/24 via 192.168.1.1` <br> Delete the route for 192.168.1.0/24 via the gateway at 192.168.1.1                                        |
| **route replace** | Replace, or add if not defined, a route                                                                                                                         |
|                   | `ip route replace 192.168.1.0/24 dev em1` <br> Replace the defined route for 192.168.1.0/24 to use device em1                                                   |
| **route get**     | Display the route an address will take                                                                                                                          |
|                   | `ip route get 192.168.1.5` <br> Display the route taken for IP 192.168.1.5                                                                                      |

### **MANAGING THE ARP TABLE**

| SUBCOMMAND        | DESCRIPTIONS AND TASKS                                                                                                                 |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| **neigh add**     | Add an entry to the ARP Table                                                                                                          |
|                   | `ip neigh add 192.168.1.1 lladdr 1:2:3:4:5:6 dev em1` <br> Add address 192.168.1.1 with MAC 1:2:3:4:5:6 to em1                         |
| **neigh del**     | Invalidate an entry                                                                                                                    |
|                   | `ip neigh del 192.168.1.1 dev em1` <br> Invalidate the entry for 192.168.1.1 on em1                                                    |
| **neigh replace** | Replace, or adds if not defined, an entry to the ARP table                                                                             |
|                   | `ip neigh replace 192.168.1.1 lladdr 1:2:3:4:5:6 dev em1` <br> Replace the entry for address 192.168.1.1 to use MAC 1:2:3:4:5:6 on em1 |

### **USEFUL NETWORKING COMMANDS (NOT NECESSARILY PROVIDED FROM IPROUTE)**

| SUBCOMMAND  | DESCRIPTIONS AND TASKS                                                                                |
| ----------- | ----------------------------------------------------------------------------------------------------- |
| **arping**  | Send ARP request to a neighbour host                                                                  |
|             | `arping -I eth0 192.168.1.1` <br> Send ARP request to 192.168.1.1 via interface eth0                  |
|             | `arping -D -I eth0 192.168.1.1` <br> Check for duplicate MAC addresses at 192.168.1.1 on eth0         |
| **ethtool** | Query or control network driver and hardware settings                                                 |
|             | `ethtool -g eth0` <br> Display ring buffer for eth0                                                   |
|             | `ethtool -i eth0` <br> Display driver information for eth0                                            |
|             | `ethtool -p eth0` <br> Identify eth0 by sight, typically by causing LEDs to blink on the network port |
|             | `ethtool -S eth0` <br> Display network and driver statistics for eth0                                 |
| **ss**      | Display socket statistics. The below options can be combined                                          |
|             | `ss -a` <br> Show all sockets (listening and non-listening)                                           |
|             | `ss -e` <br> Show detailed socket information                                                         |
|             | `ss -o` <br> Show timer information                                                                   |
|             | `ss -n` <br> Do not resolve addresses                                                                 |
|             | `ss -p` <br> Show process using the socket                                                            |

### **COMPARING NET-TOOLS VS. IPROUTE PACKAGE COMMANDS**

| NET-TOOLS COMMANDS                                          | IPROUTE COMMANDS                                       |
| ----------------------------------------------------------- | ------------------------------------------------------ |
| `arp -a`                                                    | `ip neigh`                                             |
| `arp -v`                                                    | `ip -s neigh`                                          |
| `arp -s 192.168.1.1 1:2:3:4:5:6`                            | `ip neigh add 192.168.1.1 lladdr 1:2:3:4:5:6 dev eth1` |
| `arp -i eth1 -d 192.168.1.1`                                | `ip neigh del 192.168.1.1 dev eth1`                    |
| `ifconfig -a`                                               | `ip addr`                                              |
| `ifconfig eth0 down`                                        | `ip link set eth0 down`                                |
| `ifconfig eth0 up`                                          | `ip link set eth0 up`                                  |
| `ifconfig eth0 192.168.1.1`                                 | `ip addr add 192.168.1.1/24 dev eth0`                  |
| `ifconfig eth0 netmask 255.255.255.0`                       | `ip addr add 192.168.1.1/24 dev eth0`                  |
| `ifconfig eth0 mtu 9000`                                    | `ip link set eth0 mtu 9000`                            |
| `ifconfig eth0:0 192.168.1.2`                               | `ip addr add 192.168.1.2/24 dev eth0`                  |
| `netstat`                                                   | `ss`                                                   |
| `netstat -neopa`                                            | `ss -neopa`                                            |
| `netstat -g`                                                | `ip maddr`                                             |
| `route`                                                     | `ip route`                                             |
| `route add -net 192.168.1.0 netmask 255.255.255.0 dev eth0` | `ip route add 192.168.1.0/24 dev eth0`                 |
| `route add default gw 192.168.1.1`                          | `ip route add default via 192.168.1.1`                 |
