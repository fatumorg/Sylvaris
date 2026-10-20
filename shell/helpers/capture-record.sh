#!/bin/sh
dir="$1"
name="$2"
mode="$3"
output="$4"
audio="$5"
countdown="$6"
shift 6
trap 'exit 3' INT TERM
mkdir -p "$dir" || exit 4
file="$dir/$name"
n=2
while [ -e "$file" ]; do
    file="$dir/${name%.*} ($n).${name##*.}"
    n=$((n + 1))
done
if [ "$mode" = region ]; then
    geometry="$(slurp -d </dev/null)" || exit 3
    set -- "$@" -g "$geometry"
else
    set -- "$@" -o "$output"
fi
case "$audio" in
output) set -- "$@" "--audio=$(pactl get-default-sink).monitor" ;;
mic) set -- "$@" "--audio=$(pactl get-default-source)" ;;
esac
if [ "$countdown" -gt 0 ]; then
    printf 'wait %s\n' "$countdown"
    sleep "$countdown" &
    wait $!
fi
printf '%s\n' "$file"
exec wf-recorder "$@" -f "$file"
