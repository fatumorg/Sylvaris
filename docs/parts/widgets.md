# SylWidget

Widgets on the desktop: a clock, the weather, a calendar, device batteries, photos, a terminal, an audio visualizer, your Diver plans and stacks that hold several of them. They sit under your windows by default, take their glass from your Look and hide while a window is full screen or maximized on their screen.

```sh
sylvaris widgets add clock
sylvaris widgets edit
```

## Adding and arranging

`sylvaris widgets edit` (or **Edit widgets** in SylSettings › Desktop › Widgets) dims every screen and shows a grid with an outline for each widget:

- **Drag** a widget to move it; it snaps to the grid.
- **Pull** the dot in its corner to resize it.
- **−** removes it, and the bar at the top adds any type.
- **Keys**: arrows move the picked widget by one cell, Shift and the arrows resize it, Tab picks the next one, Delete removes it, Ctrl+Z undoes, Esc or Enter is done.

Changes are saved when you are done; two widgets that ended up on top of each other are moved apart.

## Types

| Type | What it shows | Options |
|---|---|---|
| `clock` | digital, flip, analog, word clock, giant or orbit face | 24-hour time, seconds, date format, other time zones like `Tokyo +9`, font, align |
| `weather` | now and the coming days, from [SylClock](clock.md)'s forecast | feels like, wind, humidity |
| `calendar` | this month, with dots on days that have Diver plans | weeks start on Monday, dots |
| `batteries` | a ring per device: the laptop, AirPods (left, right and case), mice and keyboards | devices, ring width |
| `photos` | one picture or a slideshow from a folder; click to open it in [SylViewer](viewer.md) | folder or picture, folders inside, interval, shuffle, frame, recolour (tint or mono) |
| `terminal` | a kitty panel running any command, like `cava` or `btop` | command, font size, background, padding, typing, start again |
| `visualizer` | bars, mirrored bars, dots, a wave or a ring from `cava` | style, bars, frame rate, smoothing, colour, glow |
| `diver` | today's plans (with the Diver plugin) | how many, done ones |
| `stack` | several widgets in one place; scroll to flip, or let it turn by itself | seconds per turn |

The terminal widget needs kitty 0.42 or newer; Sylvaris starts `kitty +kitten panel` at the widget's place and moves it with the widget. The command runs as given, never through a shell. The visualizer needs `cava`, which the Nix package brings along.

## Settings

Everything lives under `widgets` in `settings.json`:

| Key | Default | |
|---|---|---|
| `widgets.enabled` | `true` | show widgets at all |
| `widgets.cell` | `80` | grid cell in pixels |
| `widgets.gap` | `12` | space between cells |
| `widgets.style` | `{"material": "inherit", ...}` | material (`inherit`, `glass`, `frosted`, `solid`, `clear`), opacity, roundness, shadow and accent for every widget |
| `widgets.items` | `[]` | the widgets |

Each item has an `id`, a `type`, the `screen` it is on (empty means the first screen), the corner it hangs from (`anchor`), `col` and `row` counted in cells from that corner, its size `w` × `h` in cells, a `layer` (`desktop` under windows, `above` them, or `overlay`), `clickThrough`, `hideFullscreen`, `workspaces` (only show on these), its own `style` and the type's `options`:

```json
{ "id": "w000", "type": "clock", "anchor": "top-right", "col": 0, "row": 1, "w": 4, "h": 2, "options": { "face": "analog" } }
```

A widget whose plugin is off (Diver, SylTemp) stays in the list and comes back when the plugin does. Up to 24 widgets fit.

## Commands

| Command | |
|---|---|
| `sylvaris widgets` | list them: id, type, screen, place and size |
| `sylvaris widgets add <type>` | add one on the focused screen and print its id |
| `sylvaris widgets remove <id>` | |
| `sylvaris widgets edit`, `done` | start and finish arranging |
| `sylvaris widgets state` | the same as JSON |
