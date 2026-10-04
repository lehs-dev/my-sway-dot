function res --description 'Set Sway output resolution and scale'
    if test (count $argv) -lt 1
        echo 'Usage: res <mode> [scale]'
        echo 'Examples:'
        echo '  res 1920x1200'
        echo '  res 2560x1600 1.25'
        echo '  res 1920x1200@59.950Hz'
        return 1
    end

    if not command -q swaymsg
        echo 'swaymsg not found' >&2
        return 127
    end

    set -l mode $argv[1]
    set -l scale 1
    if test (count $argv) -ge 2
        set scale $argv[2]
    end

    swaymsg output '*' mode $mode; or return $status
    swaymsg output '*' scale $scale
end
