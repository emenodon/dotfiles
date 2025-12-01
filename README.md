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

---

# 🧹 System Maintenance Tools  
Extra utilities included in this repo.

<details>
  <summary><strong>[GUIDE] Automatic Cleanup Setup (Systemd Service + Timer)</strong></summary>

### Ultra Fast Cleaner — Systemd Setup Guide

Follow these steps to enable automatic weekly cleanup on Arch/CachyOS.

---

## 1. Download the cleaner script  
Download the script to your system:

``wget -O /usr/local/bin/cleaner.sh https://raw.githubusercontent.com/emenodon/dotfiles/master/cleaner.sh``

Make it executable:

``sudo chmod +x /usr/local/bin/cleaner.sh``

---

## 2. Create the systemd service

``sudo nano /etc/systemd/system/cleaner.service``

Paste:

```ini
[Unit]
Description=Ultra Fast Cleaner for Arch

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cleaner.sh
```

---

## 3. Create the systemd timer

``sudo nano /etc/systemd/system/cleaner.timer``

Paste:

```ini
[Unit]
Description=Run Ultra Fast Cleaner Weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
```

---

## 4. Enable the timer

``sudo systemctl daemon-reload
sudo systemctl enable --now cleaner.timer``

---

## 5. (Optional) Check next run time  
``systemctl list-timers | grep cleaner``

---

Automatic cleanup is now enabled. 🎉

</details>