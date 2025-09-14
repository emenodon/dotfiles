# 🌙 Rose-Pine BSPWM Taste (No Compositor)

A lightweight bspwm using the **Rose-Pine Moon** color palette.  
Designed for old hardware – **no compositor needed**. Uses only efficient tools: `bspwm`, `sxhkd`, `polybar`, `rofi`, `dunst`, and `alacritty`.

---

## ✨ Preview
- Minimal tiling window manager (`bspwm`)
- Themed status bar (`polybar`)
- App launcher (`rofi`)
- Notifications (`dunst`)
- Modern terminal (`alacritty` with Nerd Font + colors)
- Rose-Pine GTK theme + Papirus icons
- Wallpaper from [rose-pine/wallpapers](https://github.com/rose-pine/wallpapers)
- Screenshot (`scrot`)
---

## 🪜 Installation Steps

### 1. Install packages
```bash
sudo pacman -S bspwm sxhkd polybar rofi dunst feh alacritty ttf-jetbrains-mono-nerd lxappearance papirus-icon-theme scrot
```
### 2. Create config folders
```bash
mkdir -p ~/.config/{bspwm,sxhkd,polybar,rofi,dunst,alacritty}
```
### 3. Copy configs
- `~/.config/bspwm/bspwmrc` → bspwm settings (gaps, borders, autostart apps).
- `~/.config/sxhkd/sxhkdrc` → keybindings for bspwm.
- `~/.config/polybar/config.ini` → bar modules + colors.
- `~/.config/polybar/launch.sh` → script to launch polybar.
- `~/.config/rofi/config.rasi` → themed launcher.
- `~/.config/dunst/dunstrc` → notifications style.
- `~/.config/alacritty/alacritty.yml` → terminal colors + font.
i'm prefer symlink the file

### 4. Wallpaper
Download a Rose-Pine wallpaper:
[rose-pine/wallpapers](https://github.com/rose-pine/wallpapers)
Set it:
```bash
feh --bg-fill ~/Pictures/wallpapers/rosepine-moon.png
```

### 5. GTK theme & icons
Use lxappearance to set:
- Theme: Rose-Pine GTK
- Icons: Papirus-Dark

### 6. Autostart bspwm
Edit ```sh ~/.xinitrc ```:
```bash
exec bspwm
```
Start with:
```bash
startx
```
