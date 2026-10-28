# Look and motion

## Looks

A Look is a whole style in one word: a glass material, a corner shape, how round and how roomy things are, fonts and a type weight. Pick one with `look.preset`:

| Look | Material | Feel |
|---|---|---|
| `lumen` (default) | lumen | bright glass with a soft highlight, glow and shadow, squircle corners, Inter Display titles |
| `classic` | resin | Sylvaris 1.1 exactly, for anyone who liked it as it was |
| `frost` | frost | thick frosted glass, roomy, light type |
| `ink` | ink | nearly solid dark panels, tight and compact |
| `neon` | neon | thin glass with a glowing rim and bevelled corners |
| `paper` | paper | matte and grainy, serif titles |

SylSettings › Style shows every Look as a card and has a control for each key below, plus a font finder and a button to save what you made.

Change any part of a Look without leaving it. Each key under `look` overrides the preset:

| Key | Values | What it does |
|---|---|---|
| `material` | `lumen` `resin` `frost` `ink` `neon` `paper` | the glass recipe |
| `corners` | `round` `squircle` `bevel` `sharp` | corner shape |
| `radius` | 0 to 2 | how round, as a multiple of the normal radius |
| `density` | `compact` `cozy` `roomy` | padding, gaps and row heights |
| `fonts.ui`, `fonts.mono`, `fonts.display` | a font family | an installed font; a missing one falls back to the Look's |
| `weight` | `light` `regular` `medium` | weight of titles |
| `shadow`, `grain`, `highlight`, `glow` | 0 to 1 | extra layers on the glass |
| `accent` | `theme` `wallpaper` or `#rrggbb` | where the accent colour comes from: the theme, the most colourful part of your wallpaper, or a colour you pick |
| `parts.<part>` | `material`, `radius` and any glass key | a different material for one part, such as `"parts": {"bar": {"material": "ink"}}` |
| `followTheme` | `true` `false` | switch to the Look a theme names when you apply that theme |
| `aurora` | `true` `false` | slow accent lights drifting behind SylSettings, SylPad, SylPower, the lock and login screens; on for every material except `resin` |

Your own `glass` keys still beat the material. Picking a Look clears the overrides above and your glass levels, so it shows as designed.

### Your own Looks

`sylvaris look save Night Owl` keeps the Look you have now, overrides and all, as `~/.config/sylvaris/looks/night-owl.json`; it then shows in `sylvaris look list` and `look.preset` takes `night-owl`. A Look file can also carry a `settings` block, such as `{"motion": {"preset": "calm"}}`, and picking that Look applies it.

Share one with `sylvaris look export ~/night-owl.json night-owl` (leave out the name to export the Look you have now) and add a friend's with `sylvaris look import ~/their-look.json`. Importing never replaces a Look you already have, and a Look cannot take the name of a built-in one.

### A theme from your wallpaper

`sylvaris theme generate` reads the wallpaper you have now, finds its main colours and writes a full theme to your themes folder as `wall-<id>.json`, then prints that id. Apply it with `sylvaris theme set <id>`. Give a path to use another picture, and add `dark` or `light` to choose the base; otherwise a bright picture gets a light theme. Text always keeps a contrast of at least 7:1 on the base, dimmed text 4.5:1, and text on the accent 4.5:1.

A theme can name the Look it was made for with a `"look"` key. Turn on `look.followTheme` and applying that theme switches to its Look as well.

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

`links` themes the rest of your desktop without a script. Each key is a path under `~/.config`, each value the file it should point to while this theme is active. When the theme is applied, Sylvaris symlinks every entry that changed, then reloads the compositor and signals kitty and waybar. A real file or folder of your own at one of those paths is moved to `<name>.before-sylvaris` first; if that backup already exists, your file stays and the link is skipped and reported. Sources that do not exist are skipped and reported in `sylvaris state theme`. When you switch to a theme without one of those paths, Sylvaris removes the link, as long as it still points where one of your themes put it, and moves your `.before-sylvaris` backup back; links it did not make and real files are never touched. Previewing a theme in the picker does not touch links. A theme with `links` rewrites files under `~/.config`, so install one only from someone you trust, as you would a plugin. For colours in GTK, Qt, terminals, editors and browsers without writing files yourself, turn on [SylSync](parts/sync.md).

## Motion and performance

Every panel opens, moves and closes with one set of curves.

| Key | Default | Meaning |
|---|---|---|
| `motion.reveal` | `edges` | how full-screen backgrounds (SylSettings, SylPad, SylPower) open: `edges`, `center` or `fade` |
| `motion.preset` | `smooth` | the feel of every animation: `calm` (slower, gentle), `smooth`, `snappy` (quicker, tighter) or `playful` (springy overshoot) |
| `motion.open` | `grow` | how panels appear: `grow` from their corner, `morph` out of the bar button you clicked, `drop` in from the edge, `unfold`, `blur` into focus or `swing` down like a door |
| `motion.stagger` | `0.35` | 0 to 0.9: how far apart the pieces of SylClock and the notification list arrive |
| `motion.springiness` | `-1` | 0 to 1: how much buttons and badges overshoot; `-1` follows `motion.preset` |
| `motion.scale` | `1` | stretches or shortens every animation; `0.5` is twice as fast |
| `motion.reduced` | `false` | panels appear without moving; they only fade, whatever `motion.open` says |
| `iconTint` | `true` | app icons in the bar, deck, launcher, switcher and notifications take the accent colour |
| `performance` | `auto` | `off`, `auto` or `on`. Lite mode drops blurred backdrops, sheen and ambient movement, and shortens every animation. `auto` keeps the look and only pauses ambient movement (drift, pulses, orbits) while a full-screen window has focus, such as a game; `on` does all of it always |

With `on`, Hyprland and sway also lose their animations, blur, shadows and gaps, and leaving `on` reloads the compositor config to bring them back. `auto` never touches the compositor. The Performance tile in SylCenter switches between `on` and `auto`. An older `true` reads as `on` and an older `false` as `auto`.
