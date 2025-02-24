#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi

# Update package list and install UFW
apt update && apt install -y ufw

# Enable UFW
ufw --force enable

# Allow essential services
ufw default deny incoming
ufw default allow outgoing
ufw allow proto tcp from 192.168.0.0/16 to any port 22

# Reload UFW to apply changes
ufw reload

# Show UFW status
ufw status verbose

echo "UFW installation and configuration completed successfully!"
