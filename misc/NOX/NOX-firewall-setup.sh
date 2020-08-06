#!/bin/bash

# switch to 'legacy' (real) ebtables
sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy

# clean slate
sudo ebtables -P INPUT ACCEPT
sudo ebtables -P OUTPUT ACCEPT
sudo ebtables -P FORWARD ACCEPT

sudo ebtables -F
sudo ebtables -Z

# eth0 = external network
# wlan0, eth1 = protected segment

# allow device destined packets, allow locally generated packets out, don't forward packets
sudo ebtables -P INPUT ACCEPT
sudo ebtables -P OUTPUT ACCEPT
sudo ebtables -P FORWARD DROP

# create new chain for MAC address filtering, external -> prtected segment, drop by default
sudo ebtables -X NOX-MAC-FILTER-IN
sudo ebtables -N NOX-MAC-FILTER-IN -P DROP

# create new chain for MAC address filtering, protected segment -> external, accept by default
sudo ebtables -X NOX-MAC-FILTER-OUT
sudo ebtables -N NOX-MAC-FILTER-OUT -P ACCEPT

# allow packets that stay within protected segment
sudo ebtables -A FORWARD -i ! eth0 -o ! eth0 -j ACCEPT

# allow ARP packets bidirectionally
sudo ebtables -A FORWARD -p ARP -j ACCEPT

# allow ICMP packets bidirectionally
sudo ebtables -A FORWARD -p IPv4 --ip-proto ICMP -j ACCEPT
sudo ebtables -A FORWARD -p IPv6 --ip6-proto IPv6-ICMP -j ACCEPT

# allow IGMP packets bidirectionally
sudo ebtables -A FORWARD -p IPv4 --ip-proto IGMP -j ACCEPT

# allow DHCP packets bidirectionally
sudo ebtables -A FORWARD -p IPv4 --ip-proto udp --ip-dport 67:68 -j ACCEPT
sudo ebtables -A FORWARD -p IPv6 --ip6-proto udp --ip6-dport 546:547 -j ACCEPT

# allow multicast and broadcast packets bidirectionally
sudo ebtables -A FORWARD -d Multicast -j ACCEPT

# allow packets external network -> protected segment, where they meet MAC address criteria
sudo ebtables -A FORWARD -i eth0 -o ! eth0 -j NOX-MAC-FILTER-IN

# allow packets protected segment -> external network, where they meet MAC address criteria
sudo ebtables -A FORWARD -i ! eth0 -o eth0 -j NOX-MAC-FILTER-OUT

# initial set up of network specific MAC addresses
sudo /etc/NOX/NOX-mac-filter.sh
