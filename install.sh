#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$ROOT_DIR/scripts/lib/common.sh"

WITH_CODIUM=0
NO_SHELL_CHANGE=0
DRY_RUN=0

usage() {
    cat <<USAGE
Usage: ./install.sh [options]

Options:
  --codium             Install Flatpak + VSCodium (Flathub)
  --no-shell-change    Do not change the login shell to fish
  --dry-run            Show detected distro and package plan only
  -h, --help           Show this help

Supported families:
  Alpine, Debian/Ubuntu, Fedora, Arch/Manjaro/EndeavourOS
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --codium) WITH_CODIUM=1 ;;
        --no-shell-change) NO_SHELL_CHANGE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

[ "$(id -u)" -ne 0 ] || die "Run this installer as your normal user, not root."

load_os_release
select_adapter

log "Detected: $DISTRO_PRETTY"
log "Adapter:  $DISTRO_FAMILY"

if [ "$DRY_RUN" -eq 1 ]; then
    distro_print_plan
    exit 0
fi

init_privilege_helper
backup_dotfiles

distro_prepare
distro_install_core
distro_setup_runtime

install_dotfiles
configure_fish
configure_session_services
configure_systemd_user_services

if [ "$WITH_CODIUM" -eq 1 ]; then
    install_codium
fi

if [ "$NO_SHELL_CHANGE" -eq 0 ]; then
    change_login_shell
fi

refresh_caches
validate_configs

cat <<DONE

Installation complete.

Next steps:
  1. Log out to tty1 and log back in (or reboot).
  2. Sway will auto-start on tty1.
  3. Run ./doctor.sh after first login if anything looks wrong.

Backup: $BACKUP_DIR
DONE
