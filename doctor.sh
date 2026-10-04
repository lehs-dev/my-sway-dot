#!/bin/sh
set -u

ok=0
warns=0
fails=0

pass() { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; ok=$((ok+1)); }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; warns=$((warns+1)); }
fail() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*"; fails=$((fails+1)); }

printf 'my-sway-dot doctor\n\n'

for cmd in sway swaymsg waybar foot fuzzel mako fish starship grim slurp wl-copy wpctl; do
    if command -v "$cmd" >/dev/null 2>&1; then
        pass "$cmd -> $(command -v "$cmd")"
    else
        fail "missing command: $cmd"
    fi
done

if command -v fish >/dev/null 2>&1; then
    if fish -n "$HOME/.config/fish/config.fish" >/dev/null 2>&1; then
        pass 'Fish config parses'
    else
        fail 'Fish config has syntax errors'
    fi
fi

if command -v sway >/dev/null 2>&1 && [ -f "$HOME/.config/sway/config" ]; then
    tmp=$(mktemp -d)
    chmod 700 "$tmp"
    if XDG_RUNTIME_DIR="$tmp" WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
        sway --validate -c "$HOME/.config/sway/config" >/dev/null 2>&1; then
        pass 'Sway config validates headlessly'
    else
        fail 'Sway config validation failed'
    fi
    rm -rf "$tmp"
fi

if [ -n "${SWAYSOCK:-}" ] && [ -S "${SWAYSOCK:-}" ]; then
    if swaymsg -t get_version >/dev/null 2>&1; then
        pass "Live Sway IPC works (${SWAYSOCK})"
    else
        warn 'SWAYSOCK exists but swaymsg IPC failed'
    fi
else
    warn 'No live Sway session detected; runtime checks skipped'
fi

waybars=$(pgrep -x waybar 2>/dev/null | wc -l | tr -d ' ')
case "$waybars" in
    0) warn 'Waybar is not running' ;;
    1) pass 'Exactly one Waybar process is running' ;;
    *) fail "Multiple Waybar processes are running: $waybars" ;;
esac

if command -v wpctl >/dev/null 2>&1; then
    if wpctl status >/dev/null 2>&1; then
        pass 'PipeWire/WirePlumber responds to wpctl'
    else
        warn 'wpctl cannot connect to PipeWire (normal outside a GUI/user session)'
    fi
fi

if [ -f "$HOME/.config/xdg-desktop-portal/portals.conf" ]; then
    pass 'Portal preference config exists'
else
    warn 'Portal preference config missing'
fi

if command -v flatpak >/dev/null 2>&1; then
    if flatpak info com.vscodium.codium >/dev/null 2>&1; then
        pass 'VSCodium Flatpak installed'
    else
        warn 'VSCodium Flatpak is not installed (optional)'
    fi
fi

current_shell=$(awk -F: -v u="$(id -un)" '$1 == u {print $7}' /etc/passwd)
case "$current_shell" in
    */fish) pass "Login shell is Fish ($current_shell)" ;;
    *) warn "Login shell is not Fish ($current_shell)" ;;
esac

if [ -f /etc/alpine-release ]; then
    for svc in pipewire wireplumber pipewire-pulse; do
        if [ -e "/etc/user/init.d/$svc" ]; then
            if /sbin/rc-update -U show gui 2>/dev/null | grep -q "^[[:space:]]*$svc[[:space:]]*|"; then
                pass "OpenRC user service enabled: $svc"
            else
                warn "OpenRC user service not in gui runlevel: $svc"
            fi
        fi
    done
elif command -v systemctl >/dev/null 2>&1; then
    if systemctl --user is-system-running >/dev/null 2>&1; then
        pass 'systemd user manager reachable'
    else
        warn 'systemd user manager not currently reachable'
    fi
fi

printf '\nSummary: %s OK, %s warnings, %s failures\n' "$ok" "$warns" "$fails"
[ "$fails" -eq 0 ]
