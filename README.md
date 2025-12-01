# 🏠 Dotfiles  

Personal configuration files for my Linux setup.  
Built with a focus on **minimalism**, **lightweight performance**, and a **functional workflow**.  


## 📂 Window Managers  

✨ Choose your preferred environment:  

-  [**i3WM**](./i3wm)  
-  [**DWM**](https://github.com/emenodon/nub-dwm)


## 🎯 Goals  

- 🚀 Fast startup, minimal resource usage  
- ⌨️ Keyboard-driven workflow  
- 🎨 Clean look with only essential theming  
- 🛠 Easy to reproduce on any system  


<details>
  <summary><strong>Automatic Cleanup Setup (Systemd Service + Timer)</strong></summary>

### Ultra Fast Cleaner — Systemd Setup Guide

Follow these steps to enable automatic weekly cleanup on Arch/CachyOS.

---

## 1. Save the cleaner script  
Create the file:

``sudo nano /usr/local/bin/clean-ultrafast.sh``

Paste this:

``#!/bin/bash
# Ultra Fast Cleaner for Arch

if [ "$EUID" -ne 0 ]; then
    echo "Run with sudo"
    exit 1
fi

pacman -Sc --noconfirm &>/dev/null

[ -x "$(command -v yay)" ] && yay -Sc --clean --noconfirm &>/dev/null
[ -x "$(command -v paru)" ] && paru -Sc --clean --noconfirm &>/dev/null

orphans=$(pacman -Qdtq 2>/dev/null)
[ -n "$orphans" ] && pacman -Rns --noconfirm $orphans &>/dev/null

pip cache purge &>/dev/null
npm cache clean --force &>/dev/null
rm -rf ~/.cargo/registry/* ~/.cargo/git/* &>/dev/null

rm -rf ~/.cache/thumbnails/* ~/.cache/fontconfig/* &>/dev/null
find ~/.config -maxdepth 1 -type d -name "*-electron*" -exec rm -rf {}/Cache/* \; &>/dev/null

journalctl --vacuum-size=200M &>/dev/null

exit 0
``

Make executable:

``sudo chmod +x /usr/local/bin/clean-ultrafast.sh``

---

## 2. Create the systemd service

``sudo nano /etc/systemd/system/clean-ultrafast.service``

Paste:

``[Unit]
Description=Ultra Fast Cleaner for Arch/CachyOS

[Service]
Type=oneshot
ExecStart=/usr/local/bin/clean-ultrafast.sh
``

---

## 3. Create the systemd timer

``sudo nano /etc/systemd/system/clean-ultrafast.timer``

Paste:

``[Unit]
Description=Run Ultra Fast Cleaner Weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
``

---

## 4. Enable the timer

``sudo systemctl daemon-reload
sudo systemctl enable --now clean-ultrafast.timer``

---

## 5. (Optional) Check next run time  
``systemctl list-timers | grep clean-ultrafast``

---

Automatic cleanup is now enabled. 🎉

</details>