# SylTemp

Every temperature in your computer, read by [TempInfoCLI](https://github.com/fatumorg/TempInfoCLI), which must be on your `PATH`. Version 0.3 or newer streams live readings; with 0.2 SylTemp asks every 5 seconds.

Turn it on in SylSettings › Plugins or with `sylvaris plugins enable temp`, then:

```sh
sylvaris temp                    # what it reads right now, as JSON (also: state)
sylvaris temp toggle             # open the panel (also: open, close)
sylvaris temp overlay toggle     # the overlay (also: on, off)
sylvaris temp pin "Board/fan1"   # pin a sensor, or unpin it; ids come from state
```

The panel has a card per device: the processor, each graphics card, the board, the drives and the rest. Each card shows its main reading, how close it is to its limit, the last two minutes and the peak, with every sensor below it. The limits come from TempInfoCLI, so the colours match the terminal.

TempInfoCLI only runs while something shows a temperature: the panel, the overlay, the bar chip or a SylTemp widget. Close them all and it stops.

| Key (`temp.`) | Default | Meaning |
|---|---|---|
| `alerts` | `true` | notify when a sensor reaches its hot limit |
| `cooldown` | `300` | seconds before the same sensor warns again; it also has to cool below its warm limit first |
| `interval` | `1` | seconds between readings |
| `pinned` | `[]` | sensors the overlay, bar chip and widgets show instead of the processor, graphics and hottest drive |
| `overlay.show` | `off` | `toggle` (only when you toggle it), `fullscreen` (whenever a full-screen window has focus) or `apps` |
| `overlay.apps` | `[]` | window classes for `apps`, as patterns such as `steam_app_.*` or `gamescope` |
| `overlay.style` | `compact` | `compact` (one line), `card`, `bars` or `graph` |
| `overlay.corner`, `overlay.x`, `overlay.y` | `top-left`, `16`, `16` | where it sits on the focused screen |
| `overlay.scale`, `overlay.opacity` | `1`, `0.85` | size and opacity |

The overlay sits above everything and never takes a click. Add `temp` to a side of the bar (or flip Show in the bar in SylSettings › SylTemp) for the bar chip; it opens the panel. SylWidget has a SylTemp widget with rings, a list or graphs. `placement.temp` sets where the panel opens.
