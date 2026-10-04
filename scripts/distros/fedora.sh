#!/bin/sh

distro_print_plan() {
    cat <<'PLAN'
Fedora plan:
  - dnf install native Sway desktop packages
  - PipeWire/WirePlumber managed by the systemd user session
  - install wlr + GTK portals, Firefox, Flatpak, fonts
PLAN
}

distro_prepare() { as_root dnf -y makecache; }

distro_install_core() {
    as_root dnf -y install \
        sway swaybg swayidle swaylock waybar foot fuzzel mako \
        grim slurp wl-clipboard \
        fish starship git neovim util-linux-user \
        xorg-x11-server-Xwayland \
        pipewire pipewire-alsa pipewire-pulseaudio wireplumber \
        xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
        brightnessctl flatpak \
        dejavu-sans-fonts google-noto-color-emoji-fonts \
        firefox
}

distro_setup_runtime() { :; }
