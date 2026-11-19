# SylAccessibility

`sylvaris access toggle` opens zoom, colour filters, text size, pointer size, reduce motion and reduce transparency.

```sh
sylvaris access zoom in        # also: out, or a factor from 1 to 5
sylvaris access filter grayscale
```

| Key (`access.`) | Default | Meaning |
|---|---|---|
| `zoom` | `1` | screen zoom, 1 to 5 |
| `filter` | `none` | `grayscale`, `invert`, `protanopia`, `deuteranopia`, `tritanopia` (corrections for red-, green- and blue-weak colour vision) |
| `text` | `1` | text size of every Sylvaris panel |
| `cursor` | `0` | pointer size, 16 to 128 px; `0` keeps your system's |

Zoom and filters need Hyprland; the rest works everywhere. If Orca is installed, the screen reader is one click away. The on-screen keyboard button opens [SylKeyboard](keyboard.md) when it is on, or wvkbd if that is installed. Reduce motion and reduce transparency set `motion.reduced` and turn off the glass (see [look and motion](../look.md)).
