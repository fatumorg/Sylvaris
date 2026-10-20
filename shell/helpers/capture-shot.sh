#!/bin/sh
dir="$1"
name="$2"
mode="$3"
delay="$4"
copy="$5"
save="$6"
rects="$7"
output="$8"
mime="$9"
shift 9
if [ "$save" = 1 ]; then
    mkdir -p "$dir" || exit 4
    file="$dir/$name"
    n=2
    while [ -e "$file" ]; do
        file="$dir/${name%.*} ($n).${name##*.}"
        n=$((n + 1))
    done
else
    file="${XDG_RUNTIME_DIR:-/tmp}/sylvaris-shot.${name##*.}"
fi
case "$mode" in
region) geometry="$(slurp -d </dev/null)" || exit 3 ;;
window) geometry="$(printf '%s\n' "$rects" | slurp -r)" || exit 3 ;;
*) geometry="" ;;
esac
sleep "$delay"
if [ -n "$geometry" ]; then
    grim "$@" -g "$geometry" "$file" || exit 4
else
    grim "$@" -o "$output" "$file" || exit 4
fi
if [ "$copy" = 1 ]; then
    wl-copy -t "$mime" <"$file" >/dev/null 2>&1
fi
printf '%s\n' "$file"
