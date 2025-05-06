#!/bin/bash
set -e

# Configuration
DEFAULT_BITRATE=250
CAN_INTERFACE="can0"

# Parse arguments
USER_INPUT=${1:-$DEFAULT_BITRATE}

# Validate input and calculate bitrate
if [[ "$USER_INPUT" =~ ^[0-9]+$ ]]; then
    BITRATE=$(( USER_INPUT * 1000 ))  # Multiply by 1000
else
    echo "ERROR: Bitrate must be a number (e.g., 250 or 500)"
    exit 1
fi

# Check root privileges
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root/sudo"
    exit 1
fi

# Function to check current bitrate
get_current_bitrate() {
    ip -details link show "$CAN_INTERFACE" 2>/dev/null | \
    awk '/bitrate/ {print $2}' | cut -d/ -f1 || echo "0"
}

# Function to configure CAN interface
configure_can() {
    echo "Setting $CAN_INTERFACE to ${BITRATE} bps"
    
    # Bring interface down if exists
    ip link set "$CAN_INTERFACE" down 2>/dev/null || true
    
    # Configure bitrate (quoted BITRATE)
    ip link set "$CAN_INTERFACE" type can bitrate "$BITRATE"
    
    # Bring interface up
    ip link set "$CAN_INTERFACE" up
    
    # Verify
    CURRENT_BITRATE=$(get_current_bitrate)
    if [ "$CURRENT_BITRATE" -eq "$BITRATE" ]; then
        echo "Success: $CAN_INTERFACE configured at ${BITRATE} bps"
    else
        echo "ERROR: Failed to set bitrate! Current: ${CURRENT_BITRATE} bps"
        exit 1
    fi
}

# Main execution
if ! ip link show "$CAN_INTERFACE" &>/dev/null; then
    echo "ERROR: $CAN_INTERFACE not found!"
    echo "Possible causes:"
    echo "1) CAN device not connected"
    echo "2) Drivers not loaded (run install.sh first)"
    echo "3) Interface renamed (check 'ip link show')"
    exit 1
fi

CURRENT_BITRATE=$(get_current_bitrate)

if [ "$CURRENT_BITRATE" -eq "$BITRATE" ]; then
    echo "$CAN_INTERFACE already at ${BITRATE} bps"
elif [ "$CURRENT_BITRATE" -eq "0" ]; then
    configure_can
else
    echo "Reconfiguring from ${CURRENT_BITRATE} bps to ${BITRATE} bps"
    configure_can
fi

# Show final status
echo -e "\nInterface status:"
ip -details -statistics link show "$CAN_INTERFACE"
