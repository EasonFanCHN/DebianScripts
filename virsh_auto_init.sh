#!/bin/bash
set -e          # Exit on error
set -o pipefail # Ensure failures in piped commands stop the script

# Default values
ramsize_default_value="2048"
vcpus_default_value="2"
disksize_default_value="20"
diskpath_default_value="/mnt/nvme/kvm/images"
isopath_default_value="/mnt/nvme/OSInstallImages"
network_default_value="bridge=br0"
os_valid_options=("debian" "rocky")

# URLs for fetching latest ISO links
declare -A iso_urls=(
    ["debian"]="https://cdimage.debian.org/debian-cd/current/amd64/iso-dvd/"
    ["rocky"]="https://download.rockylinux.org/pub/rocky/"
    ["ubuntu"]="https://releases.ubuntu.com/"
)

# Function to display help message
show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --name=<value>      Provide a custom value for VM name (required)."
    echo "  --variant=<value>   Provide a custom value for OS variant."
    echo "                      Default value is '$os_default_value'"
    echo "  --ramsize=<value>   Provide a custom value for ram size."
    echo "                      If not provided, the script will prompt for input."
    echo "                      Default value is '$ramsize_default_value' MB"
    echo "  --vcpus=<value>     Specify a custom value for vcpus."
    echo "                      If not provided, the script will prompt for input."
    echo "                      Default value is '$vcpus_default_value'"
    echo "  --disksize=<value>  Specify a custom value for disk size."
    echo "                      If not provided, the script will prompt for input."
    echo "                      Default value is '$disksize_default_value' GB"
    echo "  --diskpath=<value>  Specify a custom value for disk path."
    echo "                      If not provided, the script will prompt for input."
    echo "                      Default value is '$diskpath_root_default_value'"
    echo "  --isopath=<value>   Specify a custom value for iso path."
    echo "                      If not provided, the script will prompt for input."
    echo "                      Default value is '$isopath_root_default_value'"
    echo "  --network=<value>   Specify a custom value for network."
    echo "                      If not provided, the script will prompt for input."
    echo "                      Default value is '$network_default_value'"
    echo "  -h, --help          Show this help message and exit."
    echo
    echo "Example:"
    echo "  $0 --os=debian --ramsize=2 --vcpus=2 --disksize=10"
    echo
    exit 0
}

# Function to check if KVM is installed
check_kvm_installed() {
    if command -v kvm &>/dev/null || command -v qemu-system-x86_64 &>/dev/null; then
        return 0
    else
        echo "Error: KVM is not installed."
        echo "Please install KVM manually using your package manager."
        exit 1
    fi
}

# Function to check if KVM service is running
check_kvm_service() {
    if systemctl is-active --quiet libvirtd; then
        return 0
    else
        echo "Error: KVM service (libvirtd) is NOT running."
        echo "Please start it manually using: sudo systemctl start libvirtd"
        exit 1
    fi
}

# Function to check if a command exists and install it if missing
check_and_install() {
    local cmd=$1
    local pkg=$2

    if ! command -v "$cmd" &>/dev/null; then
        echo "$cmd is not installed. Installing $cmd..."

        if [[ -f /etc/debian_version ]]; then
            sudo apt update && sudo apt install -y "$pkg"
        elif [[ -f /etc/redhat-release ]]; then
            sudo dnf install -y "$pkg"
        elif [[ -f /etc/arch-release ]]; then
            sudo pacman -Sy --noconfirm "$pkg"
        else
            echo "Unsupported OS. Please install $cmd manually."
            exit 1
        fi

        echo "$cmd installed successfully."
    else
        echo "$cmd is already installed."
    fi
}

# Function to get the latest ISO URL based on the selected distribution
get_latest_iso_url() {
    local distro=$1
    local base_url="${iso_urls[${distro}]}"

    case "$distro" in
    "debian")
        echo "Fetching latest Debian ISO..."
        # iso_file=$(curl -s "${base_url}" | grep -oP 'debian-[0-9]+(\.[0-9]+)*-amd64-netinst.iso' | head -1)
        iso_file=$(curl -s "${base_url}" | grep -oP 'debian-[0-9]+(\.[0-9]+)*-amd64-DVD-1.iso' | head -1)
        variant="debian$(echo "${iso_file}" | grep -oE '[0-9]+' | head -n 1)"
        cfg="debian.cfg"
        extraargs="auto=true priority=critical preseed/file=/${cfg}"
        ;;
    "rocky")
        echo "Fetching latest Rocky ISO..."
        latest_version=$(curl -s "${base_url}" | grep -oE 'href="[0-9]+/' | cut -d '"' -f 2 | sort -V | tail -1 | tr -d '/')
        iso_file=$(curl -s "${base_url}${latest_version}/isos/x86_64/" | grep -oP 'Rocky-[0-9]+(\.[0-9]+)*-x86_64-dvd.iso' | head -1)
        base_url="${base_url}${latest_version}/isos/x86_64/"
        variant="rocky${latest_version}"
        cfg="rocky.cfg"
        extraargs="inst.ks=file:/${cfg}"
        ;;
    # "ubuntu")
    #     echo "Fetching latest Ubuntu ISO..."
    #     latest_version=$(curl -s "$base_url" | grep -oP '[0-9]{2}\.[0-9]{2}(\.[0-9]+)?/' | sort -V | tail -1 | tr -d '/')
    #     iso_file=$(curl -s "${base_url}${latest_version}/" | grep -oP 'ubuntu-[0-9]+(\.[0-9]+)*-live-server-amd64.iso' | head -1)
    #     base_url="${base_url}${latest_version}/"
    #     ;;
    *)
        echo "Unsupported distribution."
        exit 1
        ;;
    esac

    if [[ -z "$iso_file" ]]; then
        echo "Failed to find the latest ISO for $distro. Check the URL or network connection."
        exit 1
    fi

    echo "Found latest ISO: $iso_file"
    echo "$base_url$iso_file"
    iso_url="$base_url$iso_file"

}

download_iso() {
    local distro=$1
    echo "Downloading latest $distro from: $iso_url"
    curl -L -o "$isopath/$iso_file" "$iso_url" &
    wait
    echo "Download complete!"
}

validate_isnumber() {
    local input=$1
    if [[ "$input" =~ ^[0-9]+$ && "$input" -gt 0 ]]; then
        return 0 # Valid
    else
        return 1 # Invalid
    fi
}

# Function to check if a folder path exists
check_folder_exists() {
    local folder_path=$1
    if [[ -d "$folder_path" ]]; then
        return 0 # Folder exists
    else
        echo "Error: Folder not found - $folder_path"
        return 1 # Folder does not exist
    fi
}

# Function to check if a file path exists
check_file_exists() {
    local file_path=$1
    if [[ -f "$file_path" ]]; then
        return 0 # File exists
    else
        return 1 # File does not exist
    fi
}

# Function to check if a file exists in the current directory
check_file_in_current_path() {
    local file_name=$1
    if [[ -f "./$file_name" ]]; then
        return 0
    else
        return 1 # File does not exist
    fi
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
    --name=*) name="${1#*=}" ;;
    --ramsize=*) ramsize="${1#*=}" ;;
    --vcpus=*) vcpus="${1#*=}" ;;
    --disksize=*) disksize="${1#*=}" ;;
    --diskpath=*) diskpath="${1#*=}" ;;
    --isopath=*) isopath="${1#*=}" ;;
    --network=*) network="${1#*=}" ;;
    -h | --help) show_help ;;
    *)
        echo "Unknown parameter: $1"
        exit 1
        ;;
    esac
    shift
done

# Interactive prompt for os if not provided or invalid
while true; do
    echo "Choose Your Linux Distribution："
    echo "1) debian"
    echo "2) rocky"
    echo "3) exit"
    read -p "Enter a number: " num

    case "$num" in
    1)
        os="debian"
        break
        ;;
    2)
        os="rocky"
        break
        ;;
    3)
        exit 0
        ;;
    *) echo "Enter a valid number from 1 ~ 3" ;;
    esac
done

# Interactive prompt for name if not provided or invalid
while [[ -z "$name" ]]; do
    read -p "Enter value for VM name: " name
done

# Interactive prompt for vcpus if not provided
while [[ -z "$vcpus" ]] || ! validate_isnumber "$vcpus"; do
    read -p "Enter value for vcpus (Press Enter to use default: $vcpus_default_value): " vcpus
    vcpus="${vcpus:-$vcpus_default_value}" # Use default if input is empty

    if ! validate_isnumber "$vcpus"; then
        echo "Invalid input. Please enter a number greater than 0."
        vcpus=""
    fi
done

# Interactive prompt for ramsize if not provided
while [[ -z "$ramsize" ]] || ! validate_isnumber "$ramsize"; do
    read -p "Enter value for ramsize (Press Enter to use default: $ramsize_default_value): " ramsize
    ramsize="${ramsize:-$ramsize_default_value}" # Use default if input is empty

    if ! validate_isnumber "$ramsize"; then
        echo "Invalid input. Please enter a number greater than 0."
        ramsize=""
    fi
done

# Interactive prompt for disksize if not provided
while [[ -z "$disksize" ]] || ! validate_isnumber "$disksize"; do
    read -p "Enter value for disksize (Press Enter to use default: $disksize_default_value): " disksize
    disksize="${disksize:-$disksize_default_value}" # Use default if input is empty

    if ! validate_isnumber "$disksize"; then
        echo "Invalid input. Please enter a number greater than 0."
        disksize=""
    fi
done

# Interactive prompt for diskpath if not provided
while [[ -z "$diskpath" ]] || ! check_folder_exists "$diskpath"; do
    read -p "Enter value for diskpath (Press Enter to use default: $diskpath_default_value): " diskpath
    diskpath="${diskpath:-$diskpath_default_value}" # Use default if input is empty

    if ! check_folder_exists "$diskpath"; then
        echo "Invalid diskpath. Please enter an exist disk path."
        diskpath=""
    fi
done

# Interactive prompt for isopath if not provided
while [[ -z "$isopath" ]] || ! check_folder_exists "$isopath"; do
    read -p "Enter value for diskpath (Press Enter to use default: $isopath_default_value): " isopath
    isopath="${isopath:-$isopath_default_value}" # Use default if input is empty

    if ! check_folder_exists "$isopath"; then
        echo "Invalid isopath. Please enter an exist disk path."
        isopath=""
    fi
done

# Interactive prompt for network if not provided or invalid
while [[ -z "$network" ]]; do
    read -p "Enter value for network (Press Enter to use default: $network_default_value): " network
    network="${network:-$network_default_value}"
done

# Check for required dependencies
check_and_install "curl" "curl"

# Download the latest ISO for the selected Linux distribution
get_latest_iso_url "$os"
if check_file_exists "$isopath/$iso_file"; then
    read -p "Enter yes or no for using existing "$os.iso": " yn
    if [[ "$yn" =~ ^(n|no)$ ]]; then
        download_iso "$os"
    fi
else
    download_iso "$os"
fi

# Print the parameters
echo "VM Name: $name"
echo "OS Variant: $variant"
echo "Linux Distro: $os"
echo "Vcpus: $vcpus"
echo "Ram Size: $ramsize"
echo "Network: $network"
echo "Disk Size: $disksize"
echo "Disk Path: $diskpath"
echo "ISO Path: $isopath"

# Run checks
check_kvm_installed
check_kvm_service
if ! check_file_in_current_path "$cfg"; then
    echo "Please put $cfg file into current location"
    exit 1
fi

# Run the KVM installation
sudo virt-install \
    --name "$name" \
    --ram "$ramsize" \
    --vcpus "$vcpus" \
    --disk path="$diskpath"/"$name".img,size="$disksize" \
    --os-variant $variant \
    --network "$network" \
    --graphics none \
    --console pty,target_type=serial \
    --location "$isopath/$iso_file" \
    --initrd-inject="$cfg" \
    --extra-args="$extraargs console=ttyS0,115200n8"

echo "$name"" VM installation completed"
