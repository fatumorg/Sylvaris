#!/bin/sh
set -eu
rss="$(sed -n 's/^VmRSS:[[:space:]]*\([0-9]*\) kB/\1/p' "/proc/$SHELL_PID/status")"
ticks="$(awk '{print $14 + $15}' "/proc/$SHELL_PID/stat")"
printf '%s %s %s %s\n' "$1" "$rss" "$ticks" "$(date +%s%3N)" >>"$OUT/bench.txt"
