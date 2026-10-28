# SylBar

The bar runs on every screen and keeps its space free of windows. It can sit on any edge, and the side positions turn it vertical. You get separate glass islands for each side, one continuous slab, one floating pill, or a thin line with no glass at all.

```sh
sylvaris set bar.position left     # top, bottom, left or right
sylvaris set bar.style float       # islands, slab, float or minimal
sylvaris set bar.floating false    # span the whole edge
```

Every screen can have its own bar. Pick the screen at the top of SylSettings, or set it directly: `sylvaris set screens.DP-2.bar.position left`. See [one screen at a time](../configuration.md#one-screen-at-a-time).

## What the bar does

Everything opens where you clicked it. The clock opens [SylClock](clock.md), the options button opens [SylCenter](center.md), the bell opens the [notification center](notify.md) (middle click toggles Do Not Disturb), and the apps button opens [SylPad](pad.md). The Wi-Fi, Bluetooth and volume items open their SylCenter views.

Scroll over the workspaces to switch, over the volume to change it, and over the media title to skip tracks. Tray apps live in a drawer behind an arrow that points where it opens, and right-clicking a tray icon shows the app's own menu in glass.

Click the window title to minimize that app. While nothing else has focus the bar keeps showing it, faded, and a second click brings it back. Hyprland parks it on the `special:minimized` workspace and sway in the scratchpad; niri has no minimize. `sylvaris wm minimize` and `sylvaris wm restore` do the same from a key.

## Modules

Choose the modules and their order. Each module appears once.

```json
"bar": {
  "left": ["pad", "workspaces", "window"],
  "center": ["clock"],
  "right": ["media", "tray", "audio", "network", "bluetooth", "battery", "notifications", "center"]
}
```

| Module | Shows |
|---|---|
| `pad` | a button for SylPad |
| `workspaces` | your workspaces, with app icons on the current one |
| `window` | the focused window's title |
| `clock` | time and date |
| `media` | what is playing |
| `tray` | the system tray, in a drawer |
| `audio` | volume |
| `network` | Wi-Fi |
| `bluetooth` | Bluetooth |
| `battery` | battery, hidden on computers without one |
| `notifications` | the bell with a count |
| `center` | a button for SylCenter |
| `power` | a button for SylPower |
| `diver` | what's next in Diver, with a countdown ([Diver plugin](../plugins/diver.md)) |
| `plugin:<id>` | a bar plugin ([SylPlugins](../plugins/README.md)) |

## Workspaces

The workspace you are on is a capsule with its number and the icons of the apps on it. Other workspaces show their number, bright when something is open there, with a tick under it for each window (up to three), and a red ring when one of them asks for attention. App icons and ticks need Hyprland or niri.

`bar.workspaceStyle` sets how each workspace is drawn: `pills` (the default: a capsule per workspace, the current one filled with its apps), `dots` (small dots, the current one stretched), `numbers` (plain numbers, the current one in your accent) or `icons` (the apps open on each workspace).

`bar.workspaceIcons` adds a glyph to the current capsule or turns the others into dots: `numbers`, `dots`, `paw`, `bone`, `heart`, `star`, `leaf`, `flower`, `fire`, `diamond`, `tree`, `ghost`, `moon`, `cat`, `fish` or `music`. The default, `auto`, uses the theme's `workspaceIcon`, and numbers when it has none.

Panels such as SylCenter and SylClock open next to the bar wherever it sits, so a bar on the left opens them along the left edge. `bar.enabled = false` turns the bar off without excluding the part.
