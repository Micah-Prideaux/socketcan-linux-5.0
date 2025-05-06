#!/bin/bash
set -e

# Configuration
FIRMWARE_FILE="ixx-can-ib-1.9.3.fw"
CAN_BITRATE="250000"
MIN_GCC_MAJOR=11

# --- Installation Process ---
echo "=== IXXAT CAN Driver Installation ==="

# 1. Check root privileges
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root/sudo"
    exit 1
fi

# 2. Verify repository structure
if [ ! -f "Makefile" ] || [ ! -d "can-ibxxx_socketcan" ]; then
    echo "ERROR: Must be executed from repository root directory!"
    exit 1
fi

# 3. Check GCC version
check_gcc_version() {
    if ! command -v gcc &> /dev/null; then
        echo "ERROR: GCC not found!"
        exit 1
    fi
    
    GCC_VERSION=$(gcc -dumpversion)
    GCC_MAJOR=$(echo "$GCC_VERSION" | cut -d. -f1)  # Fixed
    
    if [ "$GCC_MAJOR" -lt "$MIN_GCC_MAJOR" ]; then  # Fixed
        echo "ERROR: GCC ${MIN_GCC_MAJOR}+ required (found $GCC_VERSION)"
        echo "Installing GCC-11..."
        apt-get install -y gcc-11 g++-11
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 100
        update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 100
    fi
}

# 4. Install dependencies
echo "Installing dependencies..."
apt-get update
apt-get install -y build-essential "linux-headers-$(uname -r)" can-utils  # Fixed

# 5. Compile drivers
echo "Compiling drivers..."
make clean
if ! make; then
    echo "Compilation failed! Check for errors above"
    exit 1
fi

# 6. Install firmware
echo "Installing firmware..."
cp "can-ibxxx_socketcan/${FIRMWARE_FILE}" "/lib/firmware/" 2>/dev/null || {
    echo "ERROR: Firmware file ${FIRMWARE_FILE} not found in repo!"
    exit 1
}

# 7. Install kernel modules
echo "Installing kernel modules..."
INSTALL_PATH="/lib/modules/$(uname -r)/kernel/drivers/net/can/ixxat"
mkdir -p "$INSTALL_PATH"
cp can-ibxxx_socketcan/ixx_pci.ko usb-to-can_socketcan/ixx_usb.ko "$INSTALL_PATH"

# 8. Update module dependencies
depmod -a

# 9. Configure udev rules
echo "Configuring udev rules..."
cat << EOF > /etc/udev/rules.d/99-ixxat-can.rules
ACTION=="add", SUBSYSTEM=="net", ATTRS{idVendor}=="08d8", ATTRS{idProduct}=="0014", NAME="can0"
EOF

# 10. Handle Secure Boot
if [ -d "/sys/firmware/efi" ] && mokutil --sb-state | grep -q "enabled"; then
    echo -e "\nWARNING: Secure Boot is enabled!"
    echo "You must either:"
    echo "1) Disable Secure Boot in BIOS, OR"
    echo "2) Sign the kernel modules manually"
    echo "Continuing without Secure Boot handling..."
fi

# 11. Load drivers and configure interface
echo "Loading drivers..."
modprobe can can_raw
modprobe ixx_usb || {
    echo "Failed to load ixx_usb module! Check dmesg for errors."
    exit 1
}

# 12. Wait for interface (max 10 seconds)
echo "Waiting for interface (max 10 seconds)..."
for _ in {1..10}; do  # Fixed (underscore for unused variable)
    if ip link show can0 &>/dev/null; then
        break
    fi
    sleep 1
done

#13. Configure CAN0 if found
if ip link show can0 &>/dev/null; then
    echo "Configuring can0..."
    ip link set can0 down
    ip link set can0 type can bitrate $CAN_BITRATE
    ip link set can0 up
else
    echo "ERROR: can0 interface not found!"
    echo "Check:"
    echo "1) Device is connected"
    echo "2) Firmware file exists: /lib/firmware/$FIRMWARE_FILE"
    echo "3) udev rules: /etc/udev/rules.d/99-ixxat-can.rules"
    exit 1
fi

# --- Verification ---
echo -e "\n=== Installation Complete ==="
echo "Device status:"
ip -details link show can0
echo -e "\nTest with:"
echo "  candump can0"
