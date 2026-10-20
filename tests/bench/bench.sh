#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$(realpath -m "${1:-$repo/tests/bench/out}")"
idle="${BENCH_IDLE:-20}"
settle="${BENCH_SETTLE:-15}"
steps="$(mktemp)"
seed="$(mktemp -d)"
trap 'rm -rf "$steps" "$seed"' EXIT
cp -r "$repo/tests/fixtures/seed/warm/." "$seed/"
if [ -n "${BENCH_SETTINGS:-}" ]; then
    mkdir -p "$seed/sylvaris"
    printf '%s' "$BENCH_SETTINGS" >"$seed/sylvaris/settings.json"
fi
sample="$here/sample.sh"

{
    echo "sleep $settle"
    echo "check $sample idle"
    echo "sleep $idle"
    echo "check $sample idle-end"
    for part in center clock media notify pad power clip capture theme access plugins; do
        echo "syl $part open"
        echo "sleep 1.2"
        echo "syl $part close"
        echo "sleep 0.4"
    done
    for section in general appearance bar deck sound displays diver keybinds; do
        echo "syl settings open $section"
        echo "sleep 1"
    done
    echo "syl settings close"
    echo "sleep 1"
    echo "check $sample used"
    echo "sleep 25"
    echo "check $sample used-settled"
} >"$steps"

"$repo/tests/headless/run.sh" "$out" "$steps" "$seed" >/dev/null
tck="$(getconf CLK_TCK)"
awk -v tck="$tck" '
    { rss[$1] = $2; ticks[$1] = $3; at[$1] = $4 }
    END {
        cpu = (ticks["idle-end"] - ticks["idle"]) / tck / ((at["idle-end"] - at["idle"]) / 1000) * 100
        printf "idle RSS            %6.1f MB\n", rss["idle"] / 1024
        printf "idle CPU            %6.2f %%  (one core, over %.0f s)\n", cpu, (at["idle-end"] - at["idle"]) / 1000
        printf "RSS after use       %6.1f MB  (every panel opened once, just closed)\n", rss["used"] / 1024
        printf "RSS after use, 25 s %6.1f MB  (closed panels freed)\n", rss["used-settled"] / 1024
    }
' "$out/bench.txt"
