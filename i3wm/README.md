(i3Config) Install paket dasar
sudo apt update && sudo apt upgrade -y

# i3 + utilitas dasar
sudo apt install -y i3-wm i3status dmenu feh picom lxappearance \
    lightdm lightdm-gtk-greeter

# Network, audio, file manager
sudo apt install -y network-manager network-manager-gnome \
    pulseaudio pavucontrol thunar thunar-volman gvfs gvfs-backends \
    volumeicon-alsa clipit arandr xrandr brightnessctl

# Terminal
sudo apt install -y alacritty

# Fonts (untuk ikon)
sudo apt install -y fonts-font-awesome fonts-noto-color-emoji

--------------------------------------

# File to be placed
File: ~/.config/i3/config
File: ~/.config/i3status/config
File: ~/.config/i3/i3status_wrapper.py

-------------------------------------

(i3RyzenOptimization) just run the script ryzen-laptop-tool.sh
