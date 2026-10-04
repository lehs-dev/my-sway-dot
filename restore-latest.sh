#!/bin/sh
set -eu

base="$HOME/.local/state/my-sway-dot/backups"
[ -d "$base" ] || { echo "No backups found at $base" >&2; exit 1; }
latest=$(find "$base" -mindepth 1 -maxdepth 1 -type d -print | sort | tail -n 1)
[ -n "$latest" ] || { echo 'No backup directory found.' >&2; exit 1; }

printf 'Restore dotfiles from %s? [y/N] ' "$latest"
read ans
case "$ans" in y|Y|yes|YES) ;; *) echo 'Cancelled.'; exit 0 ;; esac

for rel in .config/sway .config/waybar .config/foot .config/fuzzel .config/mako .config/fish .config/xdg-desktop-portal .config/rc; do
    if [ -e "$latest/$rel" ]; then
        rm -rf "$HOME/$rel"
        mkdir -p "$HOME/$(dirname "$rel")"
        cp -a "$latest/$rel" "$HOME/$rel"
    fi
done

for rel in .local/bin/open-browser .local/bin/start-sway .local/bin/set-wallpaper .local/bin/sway-session-env Pictures/wall.jpg; do
    if [ -e "$latest/$rel" ]; then
        mkdir -p "$HOME/$(dirname "$rel")"
        cp -a "$latest/$rel" "$HOME/$rel"
    fi
done

echo "Restored $latest"
