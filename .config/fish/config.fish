if status is-interactive
    starship init fish | source
end

set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx BROWSER firefox
set -g fish_greeting
# Start Sway automatically on local tty1 only.
if status is-login
    if test (tty) = /dev/tty1; and not set -q WAYLAND_DISPLAY
        exec dbus-run-session sway
    end
end
