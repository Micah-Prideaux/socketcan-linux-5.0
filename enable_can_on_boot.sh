#!/bin/bash
set -e

# Auto-detect script location
SCRIPT_DIR=$(dirname "$(realpath "$0")")
SERVICE_NAME="can0-bitrate"
DEFAULT_BITRATE="250"

# Derived paths
CONFIGURE_SCRIPT="${SCRIPT_DIR}/configure_can.sh"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Check root privileges
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root/sudo"
    exit 1
fi

# Verify systemd is available
if ! command -v systemctl >/dev/null; then
    echo "ERROR: Systemd is required for this setup"
    exit 1
fi

# Verify configure script exists
if [ ! -f "$CONFIGURE_SCRIPT" ]; then
    echo "ERROR: configure_can.sh not found in script directory!"
    echo "Expected at: $CONFIGURE_SCRIPT"
    exit 1
fi

# Create service file
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Configure CAN0 Interface Bitrate
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$CONFIGURE_SCRIPT $DEFAULT_BITRATE
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chmod 644 "$SERVICE_FILE"
chmod +x "$CONFIGURE_SCRIPT"

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable "$SERVICE_NAME.service"

echo -e "\n[+] Service installed successfully!"
echo "    Service name:    ${SERVICE_NAME}"
echo "    Service purpose: Configures CAN0 interface to ${DEFAULT_BITRATE}bps at boot"
echo "    Config script:   ${CONFIGURE_SCRIPT}"
echo -e "\nManagement commands:"
echo "  Start service:      systemctl start ${SERVICE_NAME}"
echo "  Check status:       systemctl status ${SERVICE_NAME}"
echo "  View logs:          journalctl -u ${SERVICE_NAME}"
echo "  Disable:            systemctl disable ${SERVICE_NAME}"
