#!/usr/bin/env bash
# =================================================
# Ryzen Laptop Optimizer Tool (Universal)
# Supports: Ubuntu/Debian, Arch/Endeavour/CachyOS
# Bootloaders: GRUB, Limine (warning for manual edit)
# Features:
#   [1] Optimize
#   [2] Rollback
#   [3] Status Check
# =================================================

# ------------------------------
# Detect distro
# ------------------------------
if [ -f /etc/arch-release ]; then
    DISTRO="arch"
    PKG_INSTALL="sudo pacman -S --noconfirm --needed"
    PKG_REMOVE="sudo pacman -Rns --noconfirm"
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
    PKG_INSTALL="sudo apt install -y"
    PKG_REMOVE="sudo apt purge -y"
else
    echo "❌ Unsupported distro"
    exit 1
fi

# ------------------------------
# Detect bootloader
# ------------------------------
if [ -f /boot/grub/grub.cfg ]; then
    BOOTLOADER="grub"
elif [ -f /boot/limine/limine.cfg ]; then
    BOOTLOADER="limine"
else
    BOOTLOADER="unknown"
fi

# ------------------------------
# Functions
# ------------------------------
optimize() {
    echo "🔧 Updating system..."
    if [ "$DISTRO" = "arch" ]; then
        sudo pacman -Syu --noconfirm
    else
        sudo apt update && sudo apt upgrade -y
    fi

    echo "🔧 Installing essential packages..."
    if [ "$DISTRO" = "arch" ]; then
        $PKG_INSTALL tlp powertop zram-generator mesa mesa-utils htop btop lm_sensors
    else
        $PKG_INSTALL tlp tlp-rdw powertop zram-tools mesa-vulkan-drivers mesa-utils htop btop lm-sensors
    fi

    echo "⚡ Enabling TLP..."
    sudo systemctl enable tlp
    sudo systemctl start tlp

    echo "🗜️ Configuring ZRAM..."
    if [ "$DISTRO" = "arch" ]; then
        sudo bash -c 'cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF'
        sudo systemctl daemon-reexec
        sudo systemctl start systemd-zram-setup@zram0
    else
        sudo bash -c 'cat > /etc/default/zramswap <<EOF
ALGO=zstd
PERCENT=50
EOF'
        sudo systemctl enable --now zramswap
    fi

    echo "📝 Optimizing kernel boot parameters..."
    if [ "$BOOTLOADER" = "grub" ]; then
        if [ "$DISTRO" = "arch" ]; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash mitigations=off nowatchdog"/' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        else
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash mitigations=off nowatchdog"/' /etc/default/grub
            sudo update-grub
        fi
    elif [ "$BOOTLOADER" = "limine" ]; then
        echo "⚠️ Limine detected. Kernel parameters need manual editing in /boot/limine/limine.cfg"
    else
        echo "⚠️ Bootloader not detected. Skipping kernel parameter tweaks."
    fi

    echo "🎮 Checking GPU..."
    if lspci | grep -i nvidia > /dev/null; then
        echo "⚠️ NVIDIA GPU detected..."
        if [ "$DISTRO" = "arch" ]; then
            $PKG_INSTALL nvidia nvidia-utils
        else
            sudo ubuntu-drivers autoinstall
        fi
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
    $PKG_REMOVE tlp

    echo "🗜️ Disabling ZRAM..."
    if [ "$DISTRO" = "arch" ]; then
        sudo rm -f /etc/systemd/zram-generator.conf
        sudo systemctl stop systemd-zram-setup@zram0
    else
        sudo systemctl disable --now zramswap
        $PKG_REMOVE zram-tools
        sudo rm -f /etc/default/zramswap
    fi

    echo "📝 Restoring kernel boot parameters..."
    if [ "$BOOTLOADER" = "grub" ]; then
        if [ "$DISTRO" = "arch" ]; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        else
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub
            sudo update-grub
        fi
    elif [ "$BOOTLOADER" = "limine" ]; then
        echo "⚠️ Limine detected. Rollback of kernel parameters must be done manually."
    else
        echo "⚠️ Bootloader not detected. Skipping kernel parameter restore."
    fi

    echo "🧹 Removing extra tools..."
    if [ "$DISTRO" = "arch" ]; then
        $PKG_REMOVE powertop htop btop lm_sensors mesa mesa-utils nvidia nvidia-utils
    else
        $PKG_REMOVE powertop htop btop lm-sensors mesa-vulkan-drivers mesa-utils nvidia*
        sudo apt autoremove -y
    fi

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
    if command -v glxinfo >/dev/null 2>&1; then
        glxinfo | grep "OpenGL renderer"
    else
        echo "❌ glxinfo not available"
    fi

    echo
    echo "🌡️ CPU Temperature:"
    sensors | grep "Package" || echo "❌ sensors not configured"

    echo
    echo "💻 Kernel Bootloader:"
    echo "Detected: $BOOTLOADER"
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
echo "Detected distro: $DISTRO"
echo "Detected bootloader: $BOOTLOADER"
echo "----------------------------------------"
echo "1) Optimize (Enable TLP, ZRAM, kernel tweaks if GRUB, GPU check)"
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