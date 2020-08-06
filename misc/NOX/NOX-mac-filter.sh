#!/bin/bash

red='\033[1;31m'
purple='\033[1;35m'
reset='\033[0m'

# devices allowed unfettered access into the protected segment - as if the bridge was completely lucent
EXTERNAL_NETWORK_ALLOW=(
  XX:XX:XX:XX:XX:XX # Device 1
  YY:YY:YY:YY:YY:YY # Device 2
)

# devices residing in the protected segment for whom ingress traffic should similarly bypass the firewall
PROTECTED_SEGMENT_ALLOW=(
  XX:XX:XX:XX:XX:XX # Device 1
  YY:YY:YY:YY:YY:YY # Device 2
)

# devices residing in the protected segment for whom egress traffic is only permitted to permitted devices
PROTECTED_SEGMENT_RESTRICT=(
  XX:XX:XX:XX:XX:XX # Device 1
  YY:YY:YY:YY:YY:YY # Device 2
)

# the aforementioned permitted devices
PROTECTED_SEGMENT_RESTRICT_TO_EXTERNAL_NETWORK_PERMITTED=(
  XX:XX:XX:XX:XX:XX # Device 1
  YY:YY:YY:YY:YY:YY # Device 2
)

# look at routing table, find default gateway's IPv4 address, then lookup its corresponding MAC address
DEFAULT_GATEWAY_MAC_ADDRESS=$(ip neigh show | grep -P "$(ip -4 route | grep -Po "(?<=default via )(.+?)\s")" | grep -Po "([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}")

if [ "$DEFAULT_GATEWAY_MAC_ADDRESS" = "" ]; then
    echo -e "${red}ERROR: Default Gateway MAC Address Not Found${reset}" >&2
    exit 1
fi

# NOX-MAC-FILTER-IN

# clean out old rules
sudo ebtables -F NOX-MAC-FILTER-IN

# allow packets external -> protected segment, where the source MAC address is allowed
sudo ebtables -A NOX-MAC-FILTER-IN -i eth0 -o ! eth0 --among-src $(IFS=, ; echo "${EXTERNAL_NETWORK_ALLOW[*]}") -j ACCEPT

# allow packets external -> protected segment, where the destination MAC address is allowed
sudo ebtables -A NOX-MAC-FILTER-IN -i eth0 -o ! eth0 --among-dst $(IFS=, ; echo "${PROTECTED_SEGMENT_ALLOW[*]}") -j ACCEPT

# allow packets external -> protected segment, where the source MAC address is that of the default gateway, and the destination MAC address is not restricted
sudo ebtables -A NOX-MAC-FILTER-IN -i eth0 -o ! eth0 --among-src $DEFAULT_GATEWAY_MAC_ADDRESS --among-dst ! $(IFS=, ; echo "${PROTECTED_SEGMENT_RESTRICT[*]}") -j ACCEPT || exit 1


# NOX-MAC-FILTER-OUT

# clean out old rules
sudo ebtables -F NOX-MAC-FILTER-OUT

# drop packets protected segment -> external, where the source MAC address is that of a restricted device, and the destination MAC address is not permitted
sudo ebtables -A NOX-MAC-FILTER-OUT -i ! eth0 -o eth0 --among-src $(IFS=, ; echo "${PROTECTED_SEGMENT_RESTRICT[*]}") --among-dst ! $(IFS=, ; echo "${PROTECTED_SEGMENT_RESTRICT_TO_EXTERNAL_NETWORK_PERMITTED[*]}") -j DROP

sudo netfilter-persistent save

echo -e "Default Gateway MAC Address: ${purple}$DEFAULT_GATEWAY_MAC_ADDRESS${reset}"
