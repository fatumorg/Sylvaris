#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
seeds="$here/../fixtures/seed"
failed=0

for steps in "$here"/*.steps; do
    name="$(basename "$steps" .steps)"
    case "$name" in
    theme-empty) seed="" ;;
    theme*) seed="$seeds/tp" ;;
    broken | notice) seed="$seeds/broken" ;;
    blackout) seed="$seeds/blackout" ;;
    keybinds-sync) seed="$seeds/keybinds-sync" ;;
    *) seed="$seeds/warm" ;;
    esac
    extra=()
    if [ "$name" = niri-toggles ] || [ "$name" = workspaces-niri ]; then
        extra=(env HL_NIRI_SOCKET=/nonexistent PATH="$here/fake-niri:$PATH")
    fi
    if [ "$name" = fatest ]; then
        extra=(env PATH="$here/fake-fatest:$PATH")
    fi
    if [ "$name" = files-drives ]; then
        extra=(env PATH="$here/fake-drives:$PATH")
    fi
    if [ "$name" = keybinds-sync ] || [ "$name" = remote-text ] || [ "$name" = files-identity ] || [ "$name" = performance-auto ]; then
        extra=(env SYLVARIS_DEMO=0)
    fi
    if [ "$name" = island-voice ]; then
        extra=(env SYLVARIS_DEMO=0 HL_PIPEWIRE=1)
    fi
    if [ "$name" = lock ]; then
        extra=(env SYLVARIS_PAM_DIR="$here/../fixtures/pam")
    fi
    if [ "$name" = greet ]; then
        seed=""
        gdir="$(mktemp -d)"
        python3 "$here/fake-greetd.py" "$gdir/greetd.sock" "$gdir/log" &
        gpid=$!
        extra=(env HL_ENTRY=greet.qml GREETD_SOCK="$gdir/greetd.sock" SYLVARIS_GREET_PASSWD="$here/../fixtures/greet/passwd" SYLVARIS_GREET_SESSIONS="$here/../fixtures/greet/sessions" SYLVARIS_GREET_STATE="$gdir" SYLVARIS_GREET_DRY=1)
    fi
    if ! "${extra[@]}" "$here/run.sh" "$here/out/$name" "$steps" ${seed:+"$seed"} >/dev/null 2>&1; then
        echo "FAIL $name (run.sh)"
        failed=1
    elif grep -qE "TypeError|ReferenceError|is not a function|Cannot read property" "$here/out/$name/qs.log"; then
        echo "FAIL $name (script error)"
        grep -E "TypeError|ReferenceError|is not a function|Cannot read property" "$here/out/$name/qs.log" | head -3
        failed=1
    else
        echo "ok   $name"
    fi
    if [ "$name" = greet ]; then
        if ! grep -q '"start_session"' "$gdir/log" 2>/dev/null; then
            echo "FAIL greet (no session started)"
            failed=1
        fi
        kill "$gpid" 2>/dev/null
        rm -rf "$gdir"
    fi
done
exit "$failed"
