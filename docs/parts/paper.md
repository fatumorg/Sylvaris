# SylPaper

Sylvaris draws the wallpaper itself on every screen and changes it with the theme. Stop hyprpaper, swaybg or swww first, or set `paper.enabled = false` to keep yours.

`sylvaris paper` opens a picker for the images in `paper.folder` (`~/Pictures/wallpapers`). Pick one for everywhere (the default), only for the current theme or only for the screen you are on, and add blur, dim or an accent tint.

```sh
sylvaris paper next          # also: prev
sylvaris paper set ~/Pictures/wallpapers/lake.jpg
sylvaris paper reset         # back to each theme's own wallpaper
sylvaris paper current       # the wallpaper you picked
sylvaris paper shown         # what each screen is drawing right now
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

The look (fit, blur, dim, tint and the transition) can differ per screen. The picker stores an everywhere pick in `paper.wallpaper` and clears the per-theme and per-screen picks in `paper.themes` and `paper.outputs`; a screen pick beats a theme pick, which beats `paper.wallpaper`, which beats the theme's own wallpaper. The login screen and the blurred panels show the same wallpaper as the desktop. The theme picker shows each theme with its own wallpaper (or the one you picked for just that theme), and applying a theme that has its own wallpaper from the picker clears the everywhere pick, so you get the wallpaper you saw.
