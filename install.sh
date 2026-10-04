#!/bin/sh
set -eu

REPO_URL="https://github.com/lehs-dev/my-sway-dot.git"
INSTALL_CODIUM=0
SKIP_PACKAGES=0

usage() {
    cat <<'USAGE'
Usage: ./install.sh [options]

Options:
  --codium        Install Flatpak + VSCodium from Flathub.
  --skip-packages Only copy/configure dotfiles; do not install APK packages.
  -h, --help      Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --codium) INSTALL_CODIUM=1 ;;
        --skip-packages) SKIP_PACKAGES=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this installer as your normal user, not root." >&2
    exit 1
fi

if [ ! -f /etc/alpine-release ]; then
    echo "This installer targets Alpine Linux." >&2
    exit 1
fi

if command -v doas >/dev/null 2>&1; then
    ROOT=doas
elif command -v sudo >/dev/null 2>&1; then
    ROOT=sudo
else
    echo "Need doas or sudo for package/service setup." >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ ! -f "$SCRIPT_DIR/.config/sway/config" ]; then
    echo "Run install.sh from a clone of $REPO_URL" >&2
    exit 1
fi

if [ "$SKIP_PACKAGES" -eq 0 ]; then
    if ! grep -Eq '^[[:space:]]*[^#].*/community([/?]|$)' /etc/apk/repositories; then
        echo "==> Enabling Alpine community repository"
        $ROOT /sbin/setup-apkrepos -c
    fi

    echo "==> Updating APK indexes"
    $ROOT /sbin/apk update

    NEED_DESKTOP=0
    /sbin/apk info -e sway >/dev/null 2>&1 || NEED_DESKTOP=1
    if ! /sbin/apk info -e seatd >/dev/null 2>&1 && \
       ! /sbin/apk info -e elogind >/dev/null 2>&1; then
        NEED_DESKTOP=1
    fi

    if [ "$NEED_DESKTOP" -eq 1 ]; then
        echo "==> Installing the Alpine Sway desktop base"
        $ROOT /sbin/setup-desktop sway
    fi

    echo "==> Installing dotfile dependencies"
    $ROOT /sbin/apk add \
        sway xwayland foot fuzzel waybar mako \
        grim slurp wl-clipboard swaylock swayidle swaybg \
        fish starship shadow git neovim firefox \
        fontconfig font-dejavu font-nerd-fonts-symbols brightnessctl \
        pipewire wireplumber pipewire-pulse \
        pipewire-openrc wireplumber-openrc pipewire-pulse-openrc \
        xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
        xdg-desktop-portal-openrc xdg-desktop-portal-wlr-openrc \
        xdg-document-portal-openrc

    if [ "$INSTALL_CODIUM" -eq 1 ]; then
        echo "==> Installing Flatpak"
        $ROOT /sbin/apk add flatpak
    fi
elif [ "$INSTALL_CODIUM" -eq 1 ] && ! command -v flatpak >/dev/null 2>&1; then
    echo "--codium with --skip-packages requires Flatpak to be installed already." >&2
    exit 1
fi

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$HOME/.local/state/my-sway-dot-backup/$STAMP"
mkdir -p "$BACKUP_DIR"

echo "==> Backing up managed paths to $BACKUP_DIR"
for path in \
    .config/sway \
    .config/waybar \
    .config/foot \
    .config/fuzzel \
    .config/mako \
    .config/fish \
    .config/rc \
    Pictures/wall.jpg
do
    if [ -e "$HOME/$path" ]; then
        mkdir -p "$BACKUP_DIR/$(dirname "$path")"
        cp -a "$HOME/$path" "$BACKUP_DIR/$path"
    fi
done

echo "==> Installing dotfiles"
mkdir -p "$HOME/.config" "$HOME/Pictures"
cp -a "$SCRIPT_DIR/.config/." "$HOME/.config/"
cp -a "$SCRIPT_DIR/Pictures/wall.jpg" "$HOME/Pictures/wall.jpg"

# Universal Fish state is machine-local and is intentionally not deployed.
rm -f "$HOME/.config/fish/fish_variables"

if command -v fc-cache >/dev/null 2>&1; then
    echo "==> Refreshing font cache"
    fc-cache -f
fi

if [ "$SKIP_PACKAGES" -eq 0 ]; then
    echo "==> Configuring OpenRC user GUI services"
    mkdir -p "$HOME/.config/rc/runlevels/gui"

    TEMP_RUNTIME=""
    if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
        if [ -d "/run/user/$(id -u)" ]; then
            export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        else
            TEMP_RUNTIME=$(mktemp -d)
            chmod 700 "$TEMP_RUNTIME"
            export XDG_RUNTIME_DIR="$TEMP_RUNTIME"
        fi
    fi

    for svc in pipewire wireplumber pipewire-pulse xdg-desktop-portal xdg-desktop-portal-wlr xdg-document-portal; do
        if [ -x "/etc/user/init.d/$svc" ]; then
            if /sbin/rc-update -U add "$svc" gui >/dev/null 2>&1; then
                echo "    enabled: $svc"
            else
                echo "WARN: could not enable user service: $svc" >&2
            fi
        fi
    done

    if [ -n "$TEMP_RUNTIME" ]; then
        rm -rf "$TEMP_RUNTIME"
        unset XDG_RUNTIME_DIR
    fi

    LOGIN_SHELL=$(awk -F: -v user="$(id -un)" '$1 == user { print $7 }' /etc/passwd)
    if [ "$LOGIN_SHELL" != "/usr/bin/fish" ]; then
        echo "==> Setting Fish as login shell"
        $ROOT /usr/bin/chsh -s /usr/bin/fish "$(id -un)"
    fi
fi

if [ "$INSTALL_CODIUM" -eq 1 ]; then
    echo "==> Installing VSCodium from Flathub"
    flatpak remote-add --user --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --user -y flathub com.vscodium.codium
fi

if command -v sway >/dev/null 2>&1; then
    echo "==> Validating Sway configuration"
    TMP_RUNTIME=$(mktemp -d)
    chmod 700 "$TMP_RUNTIME"
    if XDG_RUNTIME_DIR="$TMP_RUNTIME" \
       WLR_BACKENDS=headless \
       WLR_RENDERER=pixman \
       WLR_LIBINPUT_NO_DEVICES=1 \
       sway --validate -c "$HOME/.config/sway/config" >/dev/null 2>&1; then
        echo "    Sway config: OK"
    else
        echo "ERROR: Sway config validation failed." >&2
        echo "Restore from: $BACKUP_DIR" >&2
        rm -rf "$TMP_RUNTIME"
        exit 1
    fi
    rm -rf "$TMP_RUNTIME"
else
    echo "WARN: sway is not installed; skipped config validation." >&2
fi

cat <<EOF2

Done.

Backup: $BACKUP_DIR

Next steps:
  1. Log out and log back in on tty1 (or reboot).
  2. Fish will start Sway automatically on tty1.
  3. If Flatpak apps are missing from Fuzzel, log out/in once more.

SPICE guest-agent startup is intentionally not configured here: resize and
clipboard behavior differ across Sway/Wayland guests. Configure it separately
for the VM you are using.
EOF2
