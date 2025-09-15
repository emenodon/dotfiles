#!/usr/bin/env bash
# ==========================================================
# Ultimate Arch Linux Ryzen Optimizer (dwm / Arch / Ryzen)
#
# Features:
#   [1] Optimize : auto-cpufreq, TLP, powertop, optional ZRAM
#   [2] Rollback : disable/remove everything, reinstall power-profiles-daemon
#   [3] Status   : show CPU/battery/governor/temp/service status
#   [4] Battery  : set charge thresholds (80% / 90% / 100%)
# ==========================================================

set -e

optimize() {
    echo "🔧 Updating system..."
    sudo pacman -Syu --noconfirm

    echo "🔧 Removing power-profiles-daemon (conflicts with TLP)..."
    sudo pacman -Rns --noconfirm power-profiles-daemon || true

    echo "🔧 Installing power management tools..."
    sudo pacman -S --needed --noconfirm \
        tlp tlp-rdw auto-cpufreq powertop lm_sensors

    echo "🔧 Masking rfkill conflicts..."
    sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket || true

    echo "⚡ Enabling services..."
    sudo systemctl enable --now tlp.service
    sudo systemctl enable --now auto-cpufreq

    echo "🔧 Creating powertop autotune service..."
    sudo tee /etc/systemd/system/powertop.service >/dev/null <<EOF
[Unit]
Description=Powertop tunings

[Service]
Type=oneshot
ExecStart=/usr/bin/powertop --auto-tune

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl enable powertop.service

    echo "🗜️ Do you want to enable ZRAM for compressed swap? (y/n)"
    read -r ZRAM
    if [[ "$ZRAM" == "y" ]]; then
        echo "🔧 Installing ZRAM setup..."
        sudo pacman -S --needed --noconfirm zram-generator

        echo "🔧 Configuring ZRAM (50% of RAM, zstd)..."
        sudo tee /etc/systemd/zram-generator.conf >/dev/null <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF

        echo "🔧 Enabling ZRAM..."
        sudo systemctl daemon-reexec
        sudo systemctl start systemd-zram-setup@zram0.service
    fi

    echo "✅ Optimization complete! Please reboot to apply changes."
}

rollback() {
    echo "🔧 Disabling optimization services..."
    sudo systemctl disable --now tlp.service || true
    sudo systemctl disable --now auto-cpufreq || true
    sudo systemctl disable --now powertop.service || true
    sudo rm -f /etc/systemd/system/powertop.service

    echo "🔧 Disabling ZRAM if enabled..."
    sudo systemctl disable --now systemd-zram-setup@zram0.service || true
    sudo rm -f /etc/systemd/zram-generator.conf

    echo "🔧 Unmasking rfkill..."
    sudo systemctl unmask systemd-rfkill.service systemd-rfkill.socket || true

    echo "🔧 Reinstalling power-profiles-daemon..."
    sudo pacman -S --needed --noconfirm power-profiles-daemon
    sudo systemctl enable --now power-profiles-daemon.service || true

    echo "🧹 Optionally remove packages installed by optimizer? (y/n)"
    read -r REMOVE
    if [[ "$REMOVE" == "y" ]]; then
        sudo pacman -Rns --noconfirm tlp tlp-rdw auto-cpufreq powertop zram-generator lm_sensors || true
    fi

    echo "✅ Rollback complete! Reboot to restore defaults."
}

battery_menu() {
    clear
    echo "============================================"
    echo " 🔋 Battery Charge Thresholds"
    echo "============================================"
    echo "1) Max 80% (best battery health)"
    echo "2) Max 90% (balanced)"
    echo "3) Max 100% (full runtime, more wear)"
    echo "q) Back"
    echo "============================================"
    read -rp "Choose option [1/2/3/q]: " bchoice

    # Make sure TLP config has threshold lines
    sudo grep -q '^START_CHARGE_THRESH_BAT0' /etc/tlp.conf || \
        echo "START_CHARGE_THRESH_BAT0=40" | sudo tee -a /etc/tlp.conf >/dev/null

    sudo grep -q '^STOP_CHARGE_THRESH_BAT0' /etc/tlp.conf || \
        echo "STOP_CHARGE_THRESH_BAT0=80" | sudo tee -a /etc/tlp.conf >/dev/null

    case $bchoice in
        1)
            sudo sed -i 's/^STOP_CHARGE_THRESH_BAT0.*/STOP_CHARGE_THRESH_BAT0=80/' /etc/tlp.conf
            echo "🔋 Battery cap set to 80%"
            ;;
        2)
            sudo sed -i 's/^STOP_CHARGE_THRESH_BAT0.*/STOP_CHARGE_THRESH_BAT0=90/' /etc/tlp.conf
            echo "🔋 Battery cap set to 90%"
            ;;
        3)
            sudo sed -i 's/^STOP_CHARGE_THRESH_BAT0.*/STOP_CHARGE_THRESH_BAT0=100/' /etc/tlp.conf
            echo "🔋 Battery cap set to 100%"
            ;;
        q|Q)
            return
            ;;
        *)
            echo "Invalid choice!"
            ;;
    esac

    # Apply changes immediately
    sudo tlp start
    echo
    echo "✅ Applied! Current threshold:"
    grep "STOP_CHARGE_THRESH_BAT0" /etc/tlp.conf
    sudo tlp-stat -b | grep "charge_control_end_threshold"
}

status_check() {
    echo "============================================"
    echo " 📊 Ryzen Optimizer Status"
    echo "============================================"

    echo "⚡ CPU Governor:"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "❌ Not available"

    echo
    echo "📈 CPU Frequency (MHz):"
    awk '{sum+=$1} END {if(NR>0) print int(sum/NR/1000)}' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null || echo "❌ Not available"

    echo
    echo "🌡️ CPU Temperature:"
    sensors 2>/dev/null | grep -E 'Package id 0|Tctl' || echo "❌ sensors not configured (run: sudo sensors-detect)"

    echo
    echo "🔋 Battery Status:"
    upower -i $(upower -e | grep BAT) | grep -E "state|percentage" || echo "❌ upower not available"
    echo
    echo "Charge thresholds:"
    sudo tlp-stat -b | grep -E "charge_control" || echo "❌ Not available"

    echo
    echo "⚙️ Services:"
    for svc in tlp auto-cpufreq powertop systemd-zram-setup@zram0 power-profiles-daemon; do
        if systemctl is-enabled --quiet $svc 2>/dev/null; then
            echo "✅ $svc enabled"
        else
            echo "❌ $svc not enabled"
        fi
    done

    echo "============================================"
    echo "✅ Status check complete."
}

# ------------------------------
# Menu
# ------------------------------
clear
echo "============================================"
echo " 🔧 Ultimate Arch Ryzen Optimizer"
echo "============================================"
echo "1) Optimize (Enable auto power saving)"
echo "2) Rollback (Restore defaults)"
echo "3) Status   (Check current settings)"
echo "4) Battery  (Set charge thresholds)"
echo "q) Quit"
echo "============================================"
read -rp "Choose option [1/2/3/4/q]: " choice

case $choice in
    1) optimize ;;
    2) rollback ;;
    3) status_check ;;
    4) battery_menu ;;
    q|Q) echo "❌ Quit." ;;
    *) echo "Invalid choice!" ;;
esac
