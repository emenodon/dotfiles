#!/bin/bash

# Ultra Fast Cleaner for Arch

if [ "$EUID" -ne 0 ]; then
    echo "Run with sudo"
    exit 1
fi

# Pacman cache
pacman -Sc --noconfirm &>/dev/null

# AUR
[ -x "$(command -v yay)" ] && yay -Sc --clean --noconfirm &>/dev/null
[ -x "$(command -v paru)" ] && paru -Sc --clean --noconfirm &>/dev/null

# Orphans
orphans=$(pacman -Qdtq 2>/dev/null)
[ -n "$orphans" ] && pacman -Rns --noconfirm $orphans &>/dev/null

# Language runtimes
pip cache purge &>/dev/null
npm cache clean --force &>/dev/null
rm -rf ~/.cargo/registry/* ~/.cargo/git/* &>/dev/null

# Misc caches
rm -rf ~/.cache/thumbnails/* ~/.cache/fontconfig/* &>/dev/null
find ~/.config -maxdepth 1 -type d -name "*-electron*" -exec rm -rf {}/Cache/* \; &>/dev/null

# Systemd log minimal
journalctl --vacuum-size=200M &>/dev/null

exit 0