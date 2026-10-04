#!/bin/sh

apk_has() { apk search -e "$1" >/dev/null 2>&1; }
apk_add_if_available() {
    pkgs=""
    for p in "$@"; do
        if apk_has "$p"; then pkgs="$pkgs $p"; else warn "Alpine package not found, skipping: $p"; fi
    done
    [ -z "$pkgs" ] || as_root apk add $pkgs
}

distro_print_plan() {
    cat <<'PLAN'
Alpine plan:
  - enable community repository
  - use setup-desktop sway on fresh installs when available
  - install Sway/Waybar/Foot/Fuzzel/Mako/Fish/Starship
  - install PipeWire/WirePlumber + OpenRC user services
  - install wlr/GTK portals, Firefox, Flatpak, fonts
PLAN
}

distro_prepare() {
    if [ -x /sbin/setup-apkrepos ]; then
        as_root /sbin/setup-apkrepos -c >/dev/null 2>&1 || true
    fi
    as_root apk update
    if ! command_exists sway && [ -x /sbin/setup-desktop ]; then
        log "Bootstrapping Alpine Sway session with setup-desktop"
        as_root /sbin/setup-desktop sway
    fi
}

distro_install_core() {
    as_root apk add \
        sway swaybg swayidle swaylock waybar foot fuzzel mako \
        grim slurp wl-clipboard \
        fish starship git neovim shadow \
        xwayland dbus \
        pipewire wireplumber pipewire-pulse pipewire-alsa \
        xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
        brightnessctl flatpak \
        font-dejavu font-noto-emoji \
        firefox

    apk_add_if_available \
        pipewire-openrc wireplumber-openrc pipewire-pulse-openrc \
        xdg-desktop-portal-openrc xdg-desktop-portal-wlr-openrc xdg-desktop-portal-gtk-openrc
}

distro_setup_runtime() {
    # setup-desktop handles seat/session setup on normal Alpine installs.
    if ! command_exists sway; then
        die "Sway is still unavailable after Alpine package installation."
    fi
}
