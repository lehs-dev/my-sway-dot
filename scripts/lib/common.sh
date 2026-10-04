#!/bin/sh

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

load_os_release() {
    [ -r /etc/os-release ] || die "/etc/os-release not found; unsupported system."
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID=${ID:-unknown}
    DISTRO_LIKE=${ID_LIKE:-}
    DISTRO_PRETTY=${PRETTY_NAME:-$DISTRO_ID}
}

select_adapter() {
    case "$DISTRO_ID" in
        alpine) DISTRO_FAMILY=alpine ;;
        debian|ubuntu|linuxmint|pop) DISTRO_FAMILY=debian ;;
        fedora) DISTRO_FAMILY=fedora ;;
        arch|manjaro|endeavouros) DISTRO_FAMILY=arch ;;
        *)
            case " $DISTRO_LIKE " in
                *" alpine "*) DISTRO_FAMILY=alpine ;;
                *" debian "*) DISTRO_FAMILY=debian ;;
                *" fedora "*) DISTRO_FAMILY=fedora ;;
                *" arch "*) DISTRO_FAMILY=arch ;;
                *) die "Unsupported distro: $DISTRO_PRETTY" ;;
            esac
            ;;
    esac
    # shellcheck disable=SC1090
    . "$ROOT_DIR/scripts/distros/$DISTRO_FAMILY.sh"
}

init_privilege_helper() {
    if command_exists doas; then
        PRIV=doas
    elif command_exists sudo; then
        PRIV=sudo
    else
        die "Need doas or sudo for package installation."
    fi
}

as_root() {
    "$PRIV" "$@"
}

backup_dotfiles() {
    stamp=$(date +%Y%m%d-%H%M%S)
    BACKUP_DIR="$HOME/.local/state/my-sway-dot/backups/$stamp"
    mkdir -p "$BACKUP_DIR"
    for rel in \
        .config/sway \
        .config/waybar \
        .config/foot \
        .config/fuzzel \
        .config/mako \
        .config/fish \
        .config/xdg-desktop-portal \
        .config/rc \
        .local/bin/open-browser \
        .local/bin/start-sway \
        .local/bin/set-wallpaper \
        .local/bin/sway-session-env \
        Pictures/wall.jpg
    do
        if [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
            cp -a "$HOME/$rel" "$BACKUP_DIR/$rel"
        fi
    done
    log "Backed up existing configs to $BACKUP_DIR"
}

copy_path() {
    src=$1
    dst=$2
    [ -e "$src" ] || return 0
    mkdir -p "$(dirname "$dst")"
    if [ -d "$src" ]; then
        mkdir -p "$dst"
        cp -a "$src"/. "$dst"/
    else
        cp -a "$src" "$dst"
    fi
}

install_dotfiles() {
    log "Installing dotfiles"
    # These directories are fully managed by this repo. They were backed up above,
    # so replacing them avoids stale snippets such as a second `exec waybar`.
    for rel in .config/sway .config/waybar .config/foot .config/fuzzel .config/mako .config/fish .config/xdg-desktop-portal; do
        rm -rf "$HOME/$rel"
    done

    copy_path "$ROOT_DIR/.config/sway" "$HOME/.config/sway"
    copy_path "$ROOT_DIR/.config/waybar" "$HOME/.config/waybar"
    copy_path "$ROOT_DIR/.config/foot" "$HOME/.config/foot"
    copy_path "$ROOT_DIR/.config/fuzzel" "$HOME/.config/fuzzel"
    copy_path "$ROOT_DIR/.config/mako" "$HOME/.config/mako"
    copy_path "$ROOT_DIR/.config/fish" "$HOME/.config/fish"
    copy_path "$ROOT_DIR/.config/xdg-desktop-portal" "$HOME/.config/xdg-desktop-portal"
    copy_path "$ROOT_DIR/.local/bin" "$HOME/.local/bin"

    mkdir -p "$HOME/Pictures"
    if [ -f "$ROOT_DIR/Pictures/wall.jpg" ]; then
        cp -f "$ROOT_DIR/Pictures/wall.jpg" "$HOME/Pictures/wall.jpg"
    elif [ ! -f "$HOME/Pictures/wall.jpg" ]; then
        warn "Pictures/wall.jpg is not bundled; Sway will use a solid fallback until you add one."
    fi

    chmod +x "$HOME/.local/bin/"* 2>/dev/null || true
}

configure_fish() {
    mkdir -p "$HOME/.config/fish/functions"
    rm -f "$HOME/.config/fish/fish_variables"
}

configure_session_services() {
    if [ "$DISTRO_FAMILY" = alpine ]; then
        mkdir -p "$HOME/.config/rc/runlevels/gui"
        cat > "$HOME/.config/rc/rc.conf" <<'RC'
rc_env_allow="WAYLAND_DISPLAY DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS"
RC
        for svc in pipewire wireplumber pipewire-pulse xdg-desktop-portal xdg-desktop-portal-wlr; do
            if [ -e "/etc/user/init.d/$svc" ]; then
                /sbin/rc-update -U add "$svc" gui >/dev/null 2>&1 || warn "Could not add $svc to OpenRC user gui runlevel"
            fi
        done
    fi
}

configure_systemd_user_services() {
    [ "$DISTRO_FAMILY" != alpine ] || return 0
    command_exists systemctl || return 0
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    for unit in pipewire.socket pipewire-pulse.socket wireplumber.service; do
        if systemctl --user list-unit-files "$unit" >/dev/null 2>&1; then
            systemctl --user enable --now "$unit" >/dev/null 2>&1 || true
        fi
    done
}

install_codium() {
    command_exists flatpak || die "Flatpak was not installed by the distro adapter."
    log "Installing VSCodium from Flathub"
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --user -y flathub com.vscodium.codium
}

change_login_shell() {
    fish_path=$(command -v fish || true)
    [ -n "$fish_path" ] || { warn "fish not found; keeping current shell"; return 0; }
    current_shell=$(awk -F: -v u="$(id -un)" '$1 == u {print $7}' /etc/passwd)
    if [ "$current_shell" != "$fish_path" ]; then
        log "Changing login shell to $fish_path"
        if command_exists chsh; then
            as_root chsh -s "$fish_path" "$(id -un)"
        elif command_exists usermod; then
            as_root usermod -s "$fish_path" "$(id -un)"
        else
            warn "Neither chsh nor usermod is available; keeping current login shell."
        fi
    fi
}

refresh_caches() {
    command_exists fc-cache && fc-cache -f >/dev/null 2>&1 || true
    command_exists update-desktop-database && update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
}

validate_configs() {
    log "Validating configs"
    if command_exists fish; then
        fish -n "$HOME/.config/fish/config.fish" || die "Fish config validation failed."
    fi
    if command_exists sway; then
        tmp=$(mktemp -d)
        chmod 700 "$tmp"
        if ! XDG_RUNTIME_DIR="$tmp" WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
            sway --validate -c "$HOME/.config/sway/config" >/dev/null 2>&1; then
            rm -rf "$tmp"
            die "Sway config validation failed. Restore from $BACKUP_DIR if needed."
        fi
        rm -rf "$tmp"
    fi
}
