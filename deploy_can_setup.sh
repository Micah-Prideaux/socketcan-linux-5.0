#!/bin/bash
set -e

# Configuration
REPO_URL="git@github.com:Micah-Prideaux/socketcan-linux-5.0.git"  # <<< CHANGE THIS
TARGET_DIR="/usr/local/bin"
INSTALL_DIR="/tmp/can_setup_$(date +%s)"

# Check root privileges
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root/sudo"
    exit 1
fi

# Cleanup function
cleanup() {
    echo -e "\n[+] Cleaning up..."
    rm -rf "$INSTALL_DIR"
    rm -f "${TARGET_DIR}/enable_can_on_boot.sh"
    echo "=============================================="
    echo "  CAN interface setup complete!"
    echo "  Use 'configure_can' command to change bitrates"
    echo "=============================================="
}

# 1. Clone repository
echo "=== Cloning repository ==="
git clone "$REPO_URL" "$INSTALL_DIR" || {
    echo "ERROR: Failed to clone repository"
    exit 1
}

# 2. Run install script
echo -e "\n=== Running installation ==="
cd "$INSTALL_DIR"
./install.sh || {
    echo "ERROR: Installation failed"
    cleanup
    exit 1
}

# 3-4. Move and set permissions for scripts
echo -e "\n=== Deploying scripts ==="
mv -v "$INSTALL_DIR/configure_can.sh" "${TARGET_DIR}/configure_can"
mv -v "$INSTALL_DIR/enable_can_on_boot.sh" "${TARGET_DIR}/"
chmod +x "${TARGET_DIR}/configure_can" "${TARGET_DIR}/enable_can_on_boot.sh"

# 5. Enable on boot
echo -e "\n=== Configuring boot setup ==="
"${TARGET_DIR}/enable_can_on_boot.sh"

# 6-7. Cleanup and finalize
cleanup
