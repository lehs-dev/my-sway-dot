#!/bin/sh

apt_has() { apt-cache show "$1" >/dev/null 2>&1; }
apt_install_available() {
    pkgs=""
    for p in "$@"; do
        if apt_has "$p"; then pkgs="$pkgs $p"; else warn "APT package not found, skipping: $p"; fi
    done
    [ -z "$pkgs" ] || as_root apt-get install -y $pkgs
}

distro_print_plan() {
    cat <<'PLAN'
Debian/Ubuntu plan:
  - apt install native Sway desktop packages
  - PipeWire/WirePlumber managed by the systemd user session
  - install wlr + GTK portals
  - install Flatpak; VSCodium only with --codium
PLAN
}

distro_prepare() { as_root apt-get update; }

distro_install_core() {
    apt_install_available \
        sway swaybg swayidle swaylock waybar foot fuzzel mako-notifier \
        grim slurp wl-clipboard \
        fish starship git neovim \
        xwayland dbus-user-session \
        pipewire wireplumber pipewire-pulse pipewire-alsa \
        xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
        brightnessctl flatpak \
        fonts-dejavu-core fonts-noto-color-emoji

    if ! command_exists firefox && ! command_exists firefox-esr; then
        if apt_has firefox-esr; then
            as_root apt-get install -y firefox-esr
        elif apt_has firefox; then
            as_root apt-get install -y firefox
        else
            warn "No Firefox package found in configured APT repositories."
        fi
    fi
}

distro_setup_runtime() { :; }
