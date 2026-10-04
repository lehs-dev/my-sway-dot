# Keep admin commands visible in interactive/login Fish sessions.
fish_add_path /usr/local/sbin /usr/sbin /sbin

# Flatpak desktop files must stay visible even on distros where Fish does not
# source /etc/profile (notably minimal Alpine installs).
set -l _xdg_data_dirs $HOME/.local/share/flatpak/exports/share /var/lib/flatpak/exports/share
if set -q XDG_DATA_DIRS
    for _dir in (string split : $XDG_DATA_DIRS)
        if not contains -- $_dir $_xdg_data_dirs
            set -a _xdg_data_dirs $_dir
        end
    end
else
    set -a _xdg_data_dirs /usr/local/share /usr/share
end
set -gx XDG_DATA_DIRS (string join : $_xdg_data_dirs)
set -e _dir _xdg_data_dirs

if status is-interactive
    if command -q starship
        starship init fish | source
    end
end

set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx BROWSER "$HOME/.local/bin/open-browser"
set -g fish_greeting

# Start Sway only for a local tty1 login. SSH/PTYS are unaffected.
if status is-login
    if test (tty) = /dev/tty1; and not set -q WAYLAND_DISPLAY
        exec "$HOME/.local/bin/start-sway"
    end
end
