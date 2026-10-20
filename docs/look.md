# Look and motion

## Resin Glass

Every Sylvaris surface is drawn in Resin Glass: a translucent body the compositor blurs, the theme's accent suspended in it, a soft light that drifts like liquid and leans toward the pointer and a lit rim. Tune it with a `glass` block in `config.json` (or from Nix) and in `settings.json`; `settings.json` wins, and changes apply live.

| Key | Default | Range | What it does |
|---|---|---|---|
| `enabled` | `true` | | `false` brings back the solid look |
| `opacity` | `0.55` | 0 to 1 | panel body |
| `layerOpacity` | `0.35` | 0 to 1 | tiles, rows, nodes and cards on top of a panel |
| `tint` | `0.14` | 0 to 1 | accent suspended in the glass |
| `sheen` | `0.35` | 0 to 1 | the drifting light |
| `flow` | `1` | 0 to 3 | how fast the light drifts; `0` stops it |
| `rim` | `0.5` | 0 to 1 | brightness of the lit edge |

```nix
programs.sylvaris.settings.glass = { opacity = 0.5; sheen = 0.45; flow = 0.6; };
```

Blur comes from your compositor through `ext-background-effect-v1` (see [compositors](compositors.md)). sway has no blur, so there the glass is translucent only.

## Theme bundles

A theme is a JSON file in `~/.config/sylvaris/themes/` (or `programs.sylvaris.themes.<id>` in Home Manager).

```json
{
  "id": "midnight",
  "name": "Midnight",
  "description": "Deep blue",
  "wallpaper": "~/Pictures/midnight.png",
  "workspaceIcon": "moon",
  "colors": {
    "base": "#0f1117", "surface": "#1a1d27", "accent": "#7aa2f7", "accentHi": "#9ab8ff",
    "accentDeep": "#4c6ab3", "onAccent": "#0f1117", "text": "#e6e9f2", "textDim": "#8d94a8",
    "textSoft": "#c8cdda", "danger": "#e06c75"
  },
  "alpha": { "surface": 0.9, "glass": 0.62, "line": 0.16, "tint": 0.08 },
  "links": {
    "kitty/theme.conf": "~/dotfiles/kitty/midnight.conf",
    "hypr/looknfeel.lua": "~/dotfiles/hypr/looknfeel-midnight.lua"
  }
}
```

Missing or invalid colours fall back to the built-in theme, one value at a time. An optional `rgb` colour sets what [SylRGB](plugins/rgb.md) sends to your lights while this theme is active, for when the accent looks right on screen but not on LEDs.

`links` themes the rest of your desktop without a script. Each key is a path under `~/.config`, each value the file it should point to while this theme is active. When the theme is applied, Sylvaris symlinks every entry that changed, then reloads the compositor and signals kitty and waybar. Sources that do not exist are skipped and reported in `sylvaris state theme`. For colours in GTK, Qt, terminals, editors and browsers without writing files yourself, turn on [SylSync](parts/sync.md).

## Motion and performance

Every panel opens, moves and closes with one set of curves.

| Key | Default | Meaning |
|---|---|---|
| `motion.reveal` | `edges` | how full-screen backgrounds (SylSettings, SylPad, SylPower) open: `edges`, `center` or `fade` |
| `motion.scale` | `1` | stretches or shortens every animation; `0.5` is twice as fast |
| `motion.reduced` | `false` | panels appear without moving |
| `iconTint` | `true` | app icons in the bar, deck, launcher, switcher and notifications take the accent colour |
| `performance` | `auto` | `off`, `auto` or `on`. Lite mode drops blurred backdrops, sheen and ambient movement, and shortens every animation. `auto` turns it on only while a full-screen window has focus, such as a game; `on` keeps it on |

With `on`, Hyprland and sway also lose their animations, blur, shadows and gaps, and leaving `on` reloads the compositor config to bring them back. `auto` never touches the compositor. The Performance tile in SylCenter switches between `on` and `auto`. An older `true` reads as `on` and an older `false` as `auto`.
