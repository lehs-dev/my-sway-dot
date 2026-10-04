# my-sway-dot

Portable, minimal Sway desktop dotfiles with distro-aware installation.

## What this config includes

- Sway + Waybar
- Foot terminal
- Fuzzel launcher
- Mako notifications
- Fish + Starship
- PipeWire/WirePlumber volume integration
- wlr + GTK XDG portals for Flatpak/file pickers/screensharing
- Firefox launcher helper
- optional VSCodium Flatpak
- a `res` Fish function for quick output mode/scale changes
- backup + restore and a `doctor.sh` health check

No display manager is installed. On a local `tty1` Fish login, `~/.local/bin/start-sway` starts Sway
automatically with the correct Wayland/Flatpak environment. SSH/PTTY logins do not start Sway.

## Supported installer families

The installer contains adapters for:

- Alpine Linux (OpenRC)
- Debian / Ubuntu family (systemd)
- Fedora (systemd)
- Arch / Manjaro / EndeavourOS family (systemd)

This is Linux-specific, not a universal installer for every OS. Package names
and session-service handling are intentionally isolated under `scripts/distros/`.

## Install

Run as your normal user (not root):

```sh
chmod +x install.sh
./install.sh
```

Install VSCodium via Flathub too:

```sh
./install.sh --codium
```

Preview distro detection/package strategy without making changes:

```sh
./install.sh --dry-run
```

Existing configs are backed up under:

```text
~/.local/state/my-sway-dot/backups/<timestamp>/
```

Restore the newest backup with:

```sh
./restore-latest.sh
```

## Wallpaper

Place an image at `Pictures/wall.jpg` before installing. If it is absent, the
session falls back to a solid `#1e1e2e` background instead of failing Sway.

## Daily shortcuts

| Action | Binding |
|---|---|
| Terminal | `Super+Enter` |
| Launcher | `Super+D` |
| Browser | `Super+Shift+B` |
| Close window | `Super+Shift+Q` |
| Fullscreen | `Super+F` |
| Toggle floating | `Super+Shift+Space` |
| Resize mode | `Super+R` |
| Reload Sway | `Super+Shift+C` |
| Exit Sway | `Super+Shift+E` |
| Screenshot | `Print` |
| Region to clipboard | `Super+Shift+S` |

In Fish:

```fish
modes
res 1920x1200
res 2560x1600 1.25
```

## VSCodium

`--codium` installs VSCodium from Flathub (`com.vscodium.codium`). Keeping it
in Flatpak avoids mixing distro testing/edge repositories into the base OS.

## Health check

If you launch Sway manually, use `~/.local/bin/start-sway` rather than calling `sway` directly.

After the first login:

```sh
./doctor.sh
```

It checks commands, Fish/Sway syntax, Waybar duplication, PipeWire, portals,
login shell and the distro's user service manager.

## Design notes / fixes from the original layout

- `/sbin` and `/usr/sbin` are added to Fish PATH, so `apk`, `rc-service`, etc.
  remain discoverable on Alpine.
- `fish_variables` is not tracked; it is machine-generated Fish state.
- Fonts are installed through the distro package manager instead of vendored
  binary font files.
- Volume bindings use `wpctl` consistently with PipeWire/WirePlumber.
- D-Bus/systemd/OpenRC environment setup is centralized in
  `~/.local/bin/sway-session-env`.
- Alpine-only `openrc -U gui` is no longer hard-coded directly in Sway config.
- Waybar is launched only through Sway's `bar { swaybar_command waybar }`, which
  avoids duplicate Waybar processes after reloads.
- The wallpaper helper has a safe fallback if `wall.jpg` is missing.
- Guest agents such as `spice-vdagent` are intentionally not configured here;
  VM clipboard behavior is hypervisor/compositor-specific.
