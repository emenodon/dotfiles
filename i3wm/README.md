# i3 Config & Ryzen Optimization

Minimal setup for i3 window manager on Ubuntu/Debian-based systems, plus Ryzen laptop optimization.



## 🚀 Quick Start (Copy & Run)

### Update system
```bash
sudo apt update && sudo apt upgrade -y
```
### i3 + utilities
```bash
sudo apt install -y i3-wm i3status dmenu feh picom lxappearance \
    lightdm lightdm-gtk-greeter
```
### Network, audio, file manager
```bash
sudo apt install -y network-manager network-manager-gnome \
    pulseaudio pavucontrol thunar thunar-volman gvfs gvfs-backends \
    volumeicon-alsa clipit arandr xrandr brightnessctl
```
### Terminal
```bash
sudo apt install -y alacritty
```
### Fonts
```bash
sudo apt install -y fonts-font-awesome fonts-noto-color-emoji
```
## ⚙️ Config Files

Copy the following to your home directory:
```bash
cp config ~/.config/i3/config
```
```bash
cp i3status_config ~/.config/i3status/config
```
```bash
cp i3status_wrapper.py ~/.config/i3/i3status_wrapper.py
```

## ⚡ Ryzen Optimization
For Ryzen laptops, just run:
```bash
./ryzen-laptop-tool.sh
```
