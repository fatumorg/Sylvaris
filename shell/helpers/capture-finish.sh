#!/bin/sh
file="$1"
uri="$2"
case "$file" in
*.mp4)
    tmp="${file%/*}/.${file##*/}.part"
    if ffmpeg -v error -y -i "$file" -map 0 -c copy -movflags +faststart -f mp4 "$tmp" </dev/null; then
        mv -f "$tmp" "$file"
    else
        rm -f "$tmp"
    fi
    ;;
esac
if [ -n "$uri" ]; then
    wl-copy -t text/uri-list "$uri" </dev/null >/dev/null 2>&1
fi
exit 0
