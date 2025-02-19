#!/bin/bash

set -e

DEFAULT_TIMEZONE="Asia/Shanghai"

# Function to update timezone
update_timezone() {
    echo "Use timedatectl list-timezones | less to check Available timezones"
    read -p "Enter your desired timezone (default: $DEFAULT_TIMEZONE): " TZ
    TZ=${TZ:-$DEFAULT_TIMEZONE}
    if [ -n "$TZ" ]; then
        timedatectl set-timezone "$TZ"
        echo "Timezone updated to $TZ."
    else
        echo "No timezone change made."
    fi
}

# Function to update hostname
update_hostname() {
    read -p "Enter the new hostname: " NEW_HOSTNAME
    if [ -n "$NEW_HOSTNAME" ]; then
        OLD_HOSTNAME=$(cat /etc/hostname)
        hostnamectl set-hostname "$NEW_HOSTNAME"
        sed -i "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
        echo "Hostname updated to $NEW_HOSTNAME."
    else
        echo "No hostname change made."
    fi
}

# Function to update network
update_ip() {
    ACTIVE_IFACE=$(ip -o -4 route show default | awk '{print $5}')
    ACTIVE_IP=$(ip -o -4 addr show $ACTIVE_IFACE | awk '{print $4}' | awk -F'/' '{print $1}')
    ACTIVE_NETMASK=$(ip -o -4 addr show $ACTIVE_IFACE | awk '{print $4}' | awk -F'/' '{print $2}')
    ACTIVE_GATEWAY=$(ip -o -4 route show default | awk '{print $3}')
    echo "Current active network interface: $ACTIVE_IFACE"
    echo "Current IP address: $ACTIVE_IP"
    echo "Current Gateway: $ACTIVE_GATEWAY"
    read -p "Enter network interface (default: $ACTIVE_IFACE): " IFACE
    IFACE=${IFACE:-$ACTIVE_IFACE}
    read -p "Enter new static IP address(default: $ACTIVE_IP): " NEW_IP
    NEW_IP=${NEW_IP:-$ACTIVE_IP}
    read -p "Enter subnet mask (default: $ACTIVE_NETMASK): " NETMASK
    NETMASK=${NETMASK:-$ACTIVE_NETMASK}
    read -p "Enter gateway IP address (default: $ACTIVE_GATEWAY): " GATEWAY
    GATEWAY=${GATEWAY:-$ACTIVE_GATEWAY}

    if [ -n "$IFACE" ] && [ -n "$NEW_IP" ] && [ -n "$NETMASK" ] && [ -n "$GATEWAY" ]; then
        cat <<EOF >/etc/network/interfaces
# The loopback network interface
auto lo
iface lo inet loopback

# Static IP configuration for $IFACE
allow-hotplug $IFACE
iface $IFACE inet static
        address $NEW_IP/$NETMASK
        gateway $GATEWAY
EOF
        sudo echo "nameserver $GATEWAY" >/etc/resolv.conf
        echo "Network Interfaces updated on $IFACE as: "
        echo $(cat /etc/network/interfaces)
        echo "Resolve.conf updated as: "
        echo $(cat /etc/resolv.conf)
        echo "New Configuration will take effect after reboot"
    else
        echo "Invalid input, no Network change made."
    fi
}

# Main menu
echo "Choose an option to modify:"
echo "1) Timezone"
echo "2) Hostname"
echo "3) Network"
echo "4) All"
read -p "Enter your choice: " CHOICE

case "$CHOICE" in
1) update_timezone ;;
2) update_hostname ;;
3) update_ip ;;
4)
    update_timezone
    update_hostname
    update_ip
    ;;
*) echo "Invalid choice" ;;
esac

# Confirm changes
echo "Changes applied. Reboot may be required for full effect."
read -p "Reboot now? (y/n): " REBOOT
if [[ "$REBOOT" == "y" ]]; then
    reboot
fi
