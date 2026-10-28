# SylPaper

Sylvaris draws the wallpaper itself on every screen and changes it with the theme. Stop hyprpaper, swaybg or swww first, or set `paper.enabled = false` to keep yours.

`sylvaris paper` opens a picker for the images in `paper.folder` (`~/Pictures/wallpapers`). Pick one for the current theme or only for the screen you are on, and add blur, dim or an accent tint.

```sh
sylvaris paper next          # also: prev
sylvaris paper set ~/Pictures/wallpapers/lake.jpg
sylvaris paper reset         # back to the theme's own wallpaper
sylvaris paper current
sylvaris paper menu          # the desktop menu, in the middle of the focused screen
```

Right-click the wallpaper for the desktop menu: edit widgets, the next wallpaper, the picker, your Look and SylSettings.

| Key (`paper.`) | Default | Meaning |
|---|---|---|
| `enabled` | `true` | draw the wallpaper |
| `folder` | `~/Pictures/wallpapers` | where the picker looks |
| `fit` | `cover` | `cover`, `contain`, `center` or `tile` |
| `blur`, `dim`, `tint` | `0` | blur, darken, or tint with the accent |
| `transition` | `zoom` | `zoom`, `fade` or `slide` when it changes |
| `duration` | `900` | transition length in ms |
| `parallax` | `0.4` | 0 to 1: how far the wallpaper sways when you switch workspace; `0` keeps it still |

The look (fit, blur, dim, tint and the transition) can differ per screen. The images themselves are stored per theme and per screen in `paper.themes` and `paper.outputs`, which the picker fills in for you.
