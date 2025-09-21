#!/bin/bash
# MacBook Power Management Tool (Arch Linux)
# Features: Optimize (TLP + mbpfan + powertop), Rollback, Status, Uninstall
# Version: paru edition + powertop.service

set -e

BACKUP_DATE=$(date +%F-%H%M)
POWERTOP_SERVICE="/etc/systemd/system/powertop.service"

optimize() {
    echo "[1/6] Install required packages..."
    sudo pacman -Syu --noconfirm tlp tlp-rdw powertop
    paru -S --noconfirm mbpfan-git

    echo "[2/6] Backup configs..."
    sudo cp /etc/tlp.conf /etc/tlp.conf.backup.$BACKUP_DATE 2>/dev/null || true
    sudo cp /etc/mbpfan.conf /etc/mbpfan.conf.backup.$BACKUP_DATE 2>/dev/null || true

    echo "[3/6] Apply TLP config..."
    sudo tee /etc/tlp.conf > /dev/null <<'EOF'
# --- MacBook Power Saving Config ---
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power

PCIE_ASPM_ON_AC=performance
PCIE_ASPM_ON_BAT=powersave

USB_AUTOSUSPEND=1

SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_ON_AC=0

WIFI_PWR_ON_BAT=on
WIFI_PWR_ON_AC=off

DISK_APM_LEVEL_ON_BAT="128"
DISK_APM_LEVEL_ON_AC="254"
EOF

    echo "[4/6] Apply mbpfan config..."
    sudo tee /etc/mbpfan.conf > /dev/null <<'EOF'
[general]
min_fan1_speed = 2000
max_fan1_speed = 6000
low_temp = 55
high_temp = 68
max_temp = 80
polling_interval = 7
EOF

    echo "[5/6] Create powertop service..."
    sudo tee $POWERTOP_SERVICE > /dev/null <<'EOF'
[Unit]
Description=Powertop tunings

[Service]
Type=oneshot
ExecStart=/usr/bin/powertop --auto-tune
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    echo "[6/6] Enable services..."
    sudo systemctl daemon-reload
    sudo systemctl enable --now tlp
    sudo systemctl enable --now mbpfan
    sudo systemctl enable --now powertop

    echo "✅ Optimization applied. Reboot recommended!"
}

rollback() {
    echo "[1/3] Disable services..."
    sudo systemctl disable --now tlp || true
    sudo systemctl disable --now mbpfan || true
    sudo systemctl disable --now powertop || true

    echo "[2/3] Restore configs if backup exists..."
    if ls /etc/tlp.conf.backup.* 1> /dev/null 2>&1; then
        sudo cp "$(ls -t /etc/tlp.conf.backup.* | head -n 1)" /etc/tlp.conf
        echo "Restored TLP config."
    else
        echo "No TLP backup found."
    fi

    if ls /etc/mbpfan.conf.backup.* 1> /dev/null 2>&1; then
        sudo cp "$(ls -t /etc/mbpfan.conf.backup.* | head -n 1)" /etc/mbpfan.conf
        echo "Restored mbpfan config."
    else
        echo "No mbpfan backup found."
    fi

    echo "[3/3] Rollback complete. Reboot recommended!"
}

status() {
    echo "=== Service Status ==="
    systemctl is-enabled tlp 2>/dev/null && echo "TLP: enabled" || echo "TLP: disabled"
    systemctl is-enabled mbpfan 2>/dev/null && echo "mbpfan: enabled" || echo "mbpfan: disabled"
    systemctl is-enabled powertop 2>/dev/null && echo "Powertop: enabled" || echo "Powertop: disabled"

    echo
    echo "=== Battery/Power Info ==="
    tlp-stat -b 2>/dev/null || echo "TLP not running."

    echo
    echo "=== Powertop Suggestion ==="
    echo "(Run: sudo powertop --html=report.html to generate a detailed report)"
}

uninstall_all() {
    echo "[1/4] Disable services..."
    sudo systemctl disable --now tlp || true
    sudo systemctl disable --now mbpfan || true
    sudo systemctl disable --now powertop || true

    echo "[2/4] Remove packages..."
    sudo pacman -Rns --noconfirm tlp tlp-rdw powertop || true
    paru -Rns --noconfirm mbpfan-git || true

    echo "[3/4] Remove powertop service..."
    sudo rm -f $POWERTOP_SERVICE
    sudo systemctl daemon-reload

    echo "[4/4] Cleanup configs..."
    sudo rm -f /etc/tlp.conf /etc/mbpfan.conf

    echo "✅ Uninstall complete. System back to default. Reboot recommended!"
}

menu() {
    echo "==================================="
    echo " MacBook Power Management Tool"
    echo "==================================="
    echo "1) Optimize (install & configure)"
    echo "2) Rollback (restore backup)"
    echo "3) Status (check current state)"
    echo "4) Uninstall (remove everything)"
    echo "5) Exit"
    read -p "Choose option [1-5]: " choice

    case $choice in
        1) optimize ;;
        2) rollback ;;
        3) status ;;
        4) uninstall_all ;;
        5) exit 0 ;;
        *) echo "Invalid option";;
    esac
}

menu