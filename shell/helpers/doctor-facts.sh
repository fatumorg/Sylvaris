#!/bin/sh
shell_dir="$1"
shift
printf 'quickshell=%s\n' "$(qs --version 2>/dev/null | head -n 1)"
if [ -r "$shell_dir/COMMIT" ]; then
    printf 'commit=%s\n' "$(head -n 1 "$shell_dir/COMMIT")"
else
    printf 'commit=%s\n' "$(git -C "$shell_dir" rev-parse --short HEAD 2>/dev/null)"
fi
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    printf 'compositor=hyprland %s\n' "$(hyprctl version 2>/dev/null | sed -n 's/^Tag: \([^,]*\).*/\1/p' | head -n 1)"
elif [ -n "${NIRI_SOCKET:-}" ]; then
    printf 'compositor=%s\n' "$(niri --version 2>/dev/null | head -n 1)"
elif [ -n "${SWAYSOCK:-}" ]; then
    printf 'compositor=%s\n' "$(sway --version 2>/dev/null | head -n 1)"
else
    printf 'compositor=unknown (XDG_CURRENT_DESKTOP=%s)\n' "${XDG_CURRENT_DESKTOP:-unset}"
fi
for card in /sys/class/drm/card[0-9]*; do
    case "$card" in *-*) continue ;; esac
    [ -r "$card/device/vendor" ] || continue
    driver=""
    [ -e "$card/device/driver" ] && driver="$(basename "$(readlink -f "$card/device/driver")")"
    printf 'gpu=%s %s\n' "$(cat "$card/device/vendor")" "$driver"
done
for bin in "$@"; do
    command -v "$bin" >/dev/null 2>&1 && printf 'bin=%s\n' "$bin"
done
exit 0
