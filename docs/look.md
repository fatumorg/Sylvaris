# Look and motion

## Looks

A Look (a style) reshapes everything the shell draws: the glass, the corners and spacing, the fonts, how switches, sliders, tabs, buttons, cards, hover and icons are built, the motion, the layout of the bar, Control Center, notifications, the lock clock, the island, the dock and the launcher, and how the accent and wallpaper are treated. Themes still own the colours. Pick one with `look.preset`:

| | `lumen` (default) | `classic` | `frost` | `ink` | `neon` | `paper` |
|---|---|---|---|---|---|---|
| Feel | soft light through frosted glass | the dependable desktop | cold air, quiet, lots of room | printed, dense, decisive | night city, synthwave | stationery and ink on paper |
| Glass | lumen | resin | frost | ink | neon | paper, extra grain |
| Shape | squircle, cozy | round, cozy | round, roomy, outlines | sharp, compact, thick outlines | bevel, cozy, outlines | soft round, roomy, outlines |
| Fonts | Inter, Inter Display | IBM Plex Sans and Mono | Geist, Geist Mono, light | Geist, heavy, upper case | Geist Mono, Orbitron, Departure Mono, upper case | Lora, Fraunces, small caps |
| Switches, sliders | pill, fill | pill, line | pill, line | block, ticks | lamp, ticks | check box, line |
| Tabs, buttons, cards | pill, glass, glass | boxed, solid, solid | underline, text, outline | boxed, outline, outline | boxed, outline, outline | underline, text, lifted |
| Hover, icons, dividers | lift, plain, none | glow, plain, hairline | glow, ring, hairline | invert, plain, hairline | glow, glow, dashed | underline, plain, dashed |
| Motion | smooth, morph, springy | calm, grow | calm, blur | snappy, drop | playful, swing, very springy | calm, unfold |
| Bar, workspaces | float, dots | slab, numbers | minimal, dots | slab, numbers | islands, pills | minimal, numbers |
| Center, notifications | bento, cards | grid, list | grid, list | grid, list | bento, cards | grid, list |
| Lock clock, island at rest | giant, pill | default, clock | analog, hidden | digital, clock | flip, pill | word, hidden |
| Dock, launcher | magnify with glow, launchpad | bloom, launchpad | magnify, launchpad | no effect, list | bloom with glow, launchpad | no effect, list |
| Atmosphere | aurora, accent 60% | accent 50% | aurora, accent 30%, wallpaper blur | accent 100%, wallpaper dimmed | aurora, accent 100%, wallpaper tinted | accent 40% |

The motion, layout and wallpaper choices are ordinary settings that a Look supplies as defaults: anything you set yourself, in SylSettings or `config.json`, wins until you pick a Look again. The fonts come with the Nix modules (`programs.sylvaris.fonts.enable`); elsewhere a missing font falls back to Inter and JetBrainsMono Nerd Font, see [fonts for the styles](install.md#fonts-for-the-styles). Lite mode turns off every glow, blur, grain, sheen and hard shadow in every Look.

SylSettings › Look shows every Look as a card; [edit one](#editing-styles) to change any of this.

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
| `shuffle` | `off` `daily` | pick a new Look and theme each day, never the ones you have now; `sylvaris look shuffle` picks one right away |

Your own `glass` keys still beat the material. Picking a Look clears the overrides above and your glass levels, so it shows as designed.

### Editing styles

SylSettings › Look shows every style as a card. Click one to use it. **Edit** opens the style editor on it: a name and the seven sections of a style, each with its own values and two buttons at the top. **Take from** copies that whole section from any other style, which is how you mix them (Neon's layout with Paper's type, say). **Reset section** brings back the original section for a built-in style, or Classic's for your own. Every change applies at once. A value that your `config.json` sets (from Nix, for example) says "Set in your config; your config wins", because config beats a style.

Editing a built-in style saves your version as `looks/<id>.json`, and its card says Edited; **Reset to original** deletes that file. **New style** starts from the style you have now under a new name, and your own styles also have **Duplicate** and **Delete**.

### Your own Looks

`sylvaris look save Night Owl` keeps the Look you have now, overrides and all, as `~/.config/sylvaris/looks/night-owl.json`; it then shows in `sylvaris look list` and `look.preset` takes `night-owl`.

A style file has `"version": 2`, a `name` and the sections `glass`, `shape`, `type`, `controls`, `motion`, `layout` and `atmosphere`; anything it leaves out comes from Classic, and values that are not valid are ignored. Files from before version 2 (flat keys such as `material` and `corners`, plus a `settings` block such as `{"motion": {"preset": "calm"}}`) still load and apply as before; they are written in the new format only when you save them.

Share one with `sylvaris look export ~/night-owl.json night-owl` (leave out the name to export the Look you have now) and add a friend's with `sylvaris look import ~/their-look.json`. Importing never replaces a Look you already have, and a Look cannot take the name of a built-in one.

`sylvaris look styles` lists every style as `id origin name`, where the origin is `built-in`, `edited` (a built-in you changed) or `yours`. `sylvaris look take <section> <style> [id]` copies one whole section (`glass`, `shape`, `type`, `controls`, `motion`, `layout` or `atmosphere`) from another style into the one you have now, or into `id`. Taking into a built-in saves your edit as `looks/<id>.json`, which then replaces it; `sylvaris look reset <id>` deletes that file and brings the original back. `sylvaris look remove <id>` deletes one of your own styles. A style file that is not valid JSON is ignored, and the built-in is used.

### A theme from your wallpaper

`sylvaris theme generate` reads the wallpaper you have now, finds its main colours and writes a full theme to your themes folder as `wall-<id>.json`, then prints that id. Apply it with `sylvaris theme set <id>`. Give a path to use another picture, and add `dark` or `light` to choose the base; otherwise a bright picture gets a light theme. Text always keeps a contrast of at least 7:1 on the base, dimmed text 4.5:1, and text on the accent 4.5:1.

A theme can name the Look it was made for with a `"look"` key. SylTheme draws that theme's card in its Look, and with `look.followTheme` on, applying the theme switches to its Look as well.

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

## Sounds

SylSettings › Sound › UI sounds plays a short sound when you flip a toggle, open or close a panel and when a notification pops up. Sylvaris ships no sounds of its own: point `sounds.pack` at a folder holding `toggle`, `open`, `close` and `notify` files (`.oga`, `.ogg`, `.wav` or `.flac`); any you leave out stay quiet. `sounds.volume` runs from 0 to 1, and sounds play through `pw-play`.
