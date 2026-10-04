#!/bin/sh

distro_print_plan() {
    cat <<'PLAN'
Arch-family plan:
  - pacman install native Sway desktop packages
  - PipeWire/WirePlumber managed by the systemd user session
  - install wlr + GTK portals, Firefox, Flatpak, fonts
PLAN
}

distro_prepare() { :; }

distro_install_core() {
    as_root pacman -Syu --needed --noconfirm \
        sway swaybg swayidle swaylock waybar foot fuzzel mako \
        grim slurp wl-clipboard \
        fish starship git neovim \
        xorg-xwayland \
        pipewire pipewire-alsa pipewire-pulse wireplumber \
        xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
        brightnessctl flatpak \
        ttf-dejavu noto-fonts-emoji \
        firefox
}

distro_setup_runtime() { :; }
