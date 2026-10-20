#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
    echo "usage: run.sh OUTDIR STEPS [SEED_DIR]" >&2
    exit 2
fi

out="$(realpath -m "$1")"
steps="$(realpath "$2")"
seed="${3:-}"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
shell_dir="${SYLVARIS_DIR:-$repo/shell}"
entry="$shell_dir${HL_ENTRY:+/$HL_ENTRY}"
qs_bin="$(command -v qs)"
rt="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/syl-hl-$$"
home="$out/home"

rm -rf "$out"
mkdir -p "$out" "$home/.config" "$rt"
chmod 700 "$rt"
if [ -n "$seed" ]; then
    cp -r "$seed"/. "$home/.config/"
fi

bg="output HEADLESS-1 resolution 2560x1440"
if [ -n "${HL_WALLPAPER:-}" ]; then
    bg="$bg bg $HL_WALLPAPER fill"
else
    bg="$bg bg #2a1a12 solid_color"
fi
printf '%s\n' "$bg" >"$out/sway.conf"

cleanup() {
    kill "${qs_pid:-}" "${wp_pid:-}" "${pw_pid:-}" "${sway_pid:-}" "${dbus_pid:-}" 2>/dev/null || true
    wait 2>/dev/null || true
    rm -rf "$rt"
}
trap cleanup EXIT

gpu_env=()
while IFS= read -r var; do
    gpu_env+=("$var")
done < <(env | grep -E '^(__EGL_[A-Z_]+|LD_LIBRARY_PATH|WLR_RENDER_DRM_DEVICE)=' || true)

env -i "${gpu_env[@]}" HOME="$home" PATH="$PATH" XDG_RUNTIME_DIR="$rt" \
    WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER="${HL_RENDERER:-pixman}" \
    sway -c "$out/sway.conf" >"$out/sway.log" 2>&1 &
sway_pid=$!

display=""
for _ in $(seq 50); do
    display="$(command ls "$rt" | grep -m1 -E '^wayland-[0-9]+$' || true)"
    [ -n "$display" ] && break
    sleep 0.1
done
if [ -z "$display" ]; then
    echo "headless sway did not start" >&2
    cat "$out/sway.log" >&2
    exit 1
fi
sock="$rt/$(command ls "$rt" | grep -m1 '^sway-ipc')"

dbus_addr="unix:path=$rt/bus"
dbus_conf="$(dirname "$(readlink -f "$(command -v dbus-daemon)")")/../share/dbus-1/session.conf"
dbus_pid="$(dbus-daemon --config-file="$dbus_conf" --address="$dbus_addr" --fork --print-pid=1)"

hl_env=(env -i DBUS_SESSION_BUS_ADDRESS="$dbus_addr" HOME="$home" PATH="${HL_QS_PATH:-$PATH}" XDG_RUNTIME_DIR="$rt"
    XDG_CONFIG_HOME="$home/.config" WAYLAND_DISPLAY="$display" SWAYSOCK="$sock"
    QT_QUICK_BACKEND="${HL_QT_BACKEND:-software}" SYLVARIS_DEMO="${SYLVARIS_DEMO:-1}" SYLVARIS_TRACE=1
    SYLVARIS_SKY_TIME="${SYLVARIS_SKY_TIME:-}"
    SYLVARIS_PAM_DIR="${SYLVARIS_PAM_DIR:-}"
    USER="${USER:-user}" LANG="${LANG:-C.UTF-8}")
while IFS= read -r var; do
    hl_env+=("$var")
done < <(env | grep -E '^(SYLVARIS_GREET_[A-Z]+|GREETD_SOCK|QML_IMPORT_PATH|QT_PLUGIN_PATH)=' || true)
hl_env+=("${gpu_env[@]}")
if [ -n "${HL_NIRI_SOCKET:-}" ]; then
    hl_env+=(NIRI_SOCKET="$HL_NIRI_SOCKET")
fi

if [ -n "${HL_PIPEWIRE:-}" ]; then
    "${hl_env[@]}" pipewire >"$out/pipewire.log" 2>&1 &
    pw_pid=$!
    for _ in $(seq 50); do
        [ -S "$rt/pipewire-0" ] && break
        sleep 0.1
    done
    if command -v wireplumber >/dev/null 2>&1; then
        "${hl_env[@]}" wireplumber >"$out/wireplumber.log" 2>&1 &
        wp_pid=$!
        sleep 1
    fi
fi

"${hl_env[@]}" "$qs_bin" -p "$entry" >"$out/qs.log" 2>&1 &
qs_pid=$!

ipc() {
    "${hl_env[@]}" "$qs_bin" -p "$entry" ipc call sylvaris run "$*"
}

checks_failed=0
for _ in $(seq 100); do
    "${hl_env[@]}" "$qs_bin" -p "$entry" ipc show 2>/dev/null | grep -q sylvaris && break
    sleep 0.1
done

while read -r cmd rest; do
    case "$cmd" in
    "") ;;
    ipc)
        printf '$ ipc %s\n' "$rest" >>"$out/ipc.log"
        read -r -a args <<<"$rest"
        ipc "${args[@]}" >>"$out/ipc.log" 2>&1 || true
        printf '\n' >>"$out/ipc.log"
        ;;
    syl)
        printf '$ sylvaris %s\n' "$rest" >>"$out/ipc.log"
        read -r -a args <<<"$rest"
        "${hl_env[@]}" SYLVARIS_DIR="$shell_dir" "$repo/bin/sylvaris" "${args[@]}" >>"$out/ipc.log" 2>&1 || printf 'exit %s\n' "$?" >>"$out/ipc.log"
        printf '\n' >>"$out/ipc.log"
        ;;
    bg)
        "${hl_env[@]}" SYLVARIS_DIR="$shell_dir" PATH="$repo/bin:$PATH" OUT="$out" SHELL_PID="$qs_pid" sh -c "$rest" &
        ;;
    shot)
        env -i XDG_RUNTIME_DIR="$rt" WAYLAND_DISPLAY="$display" PATH="$PATH" grim "$out/$rest.png"
        ;;
    sleep)
        sleep "$rest"
        ;;
    sway)
        read -r -a args <<<"$rest"
        env -i XDG_RUNTIME_DIR="$rt" SWAYSOCK="$sock" PATH="$PATH" swaymsg "${args[@]}" >/dev/null
        ;;
    mark)
        printf 'MARK %s %s\n' "$rest" "$(date +%s%3N)" >>"$out/ipc.log"
        ;;
    check)
        if ! "${hl_env[@]}" SYLVARIS_DIR="$shell_dir" PATH="$repo/bin:$PATH" OUT="$out" SHELL_PID="$qs_pid" sh -c "$rest" >>"$out/ipc.log" 2>&1; then
            printf 'CHECK FAILED: %s\n' "$rest" | tee -a "$out/ipc.log" >&2
            checks_failed=1
        fi
        ;;
    wait)
        waited=0
        until "${hl_env[@]}" SYLVARIS_DIR="$shell_dir" PATH="$repo/bin:$PATH" OUT="$out" SHELL_PID="$qs_pid" sh -c "$rest" >/dev/null 2>&1; do
            waited=$((waited + 1))
            if [ "$waited" -ge 100 ]; then
                printf 'CHECK FAILED: wait %s\n' "$rest" | tee -a "$out/ipc.log" >&2
                checks_failed=1
                break
            fi
            sleep 0.2
        done
        ;;
    killshell)
        kill -9 "$qs_pid"
        ;;
    pointer)
        if [ -z "${vnc_port:-}" ]; then
            vnc_port=$((5900 + $$ % 1000))
            "${hl_env[@]}" wayvnc 127.0.0.1 "$vnc_port" >"$out/wayvnc.log" 2>&1 &
            for _ in $(seq 50); do
                vncdo -s "127.0.0.1::$vnc_port" pause 0 >/dev/null 2>&1 && break
                sleep 0.1
            done
        fi
        read -r -a args <<<"$rest"
        timeout 30 vncdo -s "127.0.0.1::$vnc_port" "${args[@]}" >>"$out/ipc.log" 2>&1 || printf 'pointer failed: %s\n' "$rest" >>"$out/ipc.log"
        ;;
    write)
        target="$home/.config/${rest%% *}"
        mkdir -p "$(dirname "$target")"
        printf '%s' "${rest#* }" >"$target"
        ;;
    *)
        echo "unknown step: $cmd" >&2
        exit 2
        ;;
    esac
done <"$steps"
exit "$checks_failed"
