#!/usr/bin/env bash
# =================================================
# Ryzen Laptop Optimizer Tool for Ubuntu + i3
# Features:
#   [1] Optimize : TLP, ZRAM, GRUB tweaks, GPU setup
#   [2] Rollback : Restore default Ubuntu settings
#   [3] Status   : Show system optimization status
# =================================================

optimize() {
    echo "🔧 Updating system..."
    sudo apt update && sudo apt upgrade -y

    echo "🔧 Installing essential packages..."
    sudo apt install -y \
        tlp tlp-rdw powertop zram-tools \
        mesa-vulkan-drivers mesa-utils \
        htop btop lm-sensors

    echo "⚡ Enabling TLP..."
    sudo systemctl enable tlp
    sudo systemctl start tlp

    echo "🗜️ Configuring ZRAM..."
    sudo bash -c 'cat > /etc/default/zramswap <<EOF
ALGO=zstd
PERCENT=50
EOF'
    sudo systemctl enable --now zramswap

    echo "📝 Optimizing GRUB..."
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash mitigations=off nowatchdog"/' /etc/default/grub
    sudo update-grub

    echo "🎮 Checking GPU..."
    if lspci | grep -i nvidia > /dev/null; then
        echo "⚠️ NVIDIA GPU detected → installing driver..."
        sudo ubuntu-drivers autoinstall
    else
        echo "✅ AMD iGPU detected, Mesa driver already installed."
    fi

    echo "🌡️ Setting up sensors..."
    sudo sensors-detect --auto

    echo "✅ Optimization complete!"
    echo "📌 Please reboot your system to apply changes."
}

rollback() {
    echo "🔧 Restoring default system..."

    echo "⚡ Removing TLP..."
    sudo systemctl disable tlp
    sudo systemctl stop tlp
    sudo apt purge -y tlp tlp-rdw

    echo "🗜️ Disabling ZRAM..."
    sudo systemctl disable --now zramswap
    sudo apt purge -y zram-tools

    echo "📝 Restoring GRUB defaults..."
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub
    sudo update-grub

    echo "🧹 Removing extra tools..."
    sudo apt purge -y powertop htop btop lm-sensors mesa-vulkan-drivers mesa-utils
    sudo apt autoremove -y

    echo "🧽 Cleaning configs..."
    sudo rm -f /etc/default/zramswap

    echo "✅ Rollback complete!"
    echo "📌 Please reboot your system to apply changes."
}

status_check() {
    echo "========================================"
    echo " 📊 Ryzen Laptop Optimization Status"
    echo "========================================"

    echo "⚡ TLP status:"
    systemctl is-active tlp && tlp-stat -s | head -n 5 || echo "❌ TLP not running"

    echo
    echo "🗜️ ZRAM status:"
    swapon --show || echo "❌ No active swap/zram"

    echo
    echo "🎮 GPU info:"
    glxinfo | grep "OpenGL renderer" || echo "❌ mesa-utils not installed"

    echo
    echo "🌡️ CPU Temperature:"
    sensors | grep "Package" || echo "❌ sensors not configured"

    echo
    echo "💻 Kernel GRUB params:"
    cat /proc/cmdline

    echo "========================================"
    echo "✅ Status check complete."
}

# ------------------------------
# Menu
# ------------------------------
clear
echo "========================================"
echo " 🔧 Ryzen Laptop Optimizer Tool"
echo "========================================"
echo "1) Optimize (Enable TLP, ZRAM, GRUB tweaks, GPU check)"
echo "2) Rollback (Restore default settings)"
echo "3) Status   (Check current optimization status)"
echo "q) Quit"
echo "========================================"
read -rp "Choose option [1/2/3/q]: " choice

case $choice in
    1) optimize ;;
    2) rollback ;;
    3) status_check ;;
    q|Q) echo "❌ Quit." ;;
    *) echo "Invalid choice!" ;;
esac
