# SylSettings

The gear in SylCenter, `sylvaris settings` or `sylvaris settings open <section>` opens SylSettings over a starfield.

Seven hubs sit around the core: **Look** (style, appearance, motion, app colours), **Desktop** (wallpaper, sky, weather), **Panels** (bar, deck, Control Center, island, notifications, launcher, switcher), **Apps** (files, archive, viewer, capture, clipboard), **System** (general, displays, sound, power, accessibility, key bindings, commands), **Security** (lock, authentication) and **Plugins** (plugins, plus Diver, FaTest and lighting once their plugins are on). Picking a hub shrinks the constellation to the top and opens it below with a tab for each section; it remembers the tab you used last. Tab and Shift+Tab walk the hubs and Enter opens one. `sylvaris settings open <section>` still opens any section, and `sylvaris settings open <hub>` opens a hub.

## Search

Start typing anywhere and the search pill takes it: every setting is listed by name and by the words people use for it, so "dock", "blur" or "dnd" all find something. Arrow keys pick a result and Enter jumps to the section and lights up the row. Switches can be flipped right in the results. `sylvaris settings search <words>` prints the same matches.

## Simple and full

By default (`settings.detail: "simple"`) the options most people never touch wait behind a **more options** row at the bottom of each section. **All options** in the tab strip, or `sylvaris set settings.detail full`, shows everything everywhere.

## Changes, reset and undo

A setting you changed carries a small accent dot next to its name; click it to reset that setting to its default (or to the Look's value). Every change made here shows an **Undo** toast, and Ctrl+Z undoes the last twenty changes. The same from a script: `sylvaris settings reset <key>` and `sylvaris settings undo`.

On the left you tune the constellation itself (drift speed, ring, silk links, labels, starfield), which also changes SylCenter's orbits. On the right are statistics (uptime, the shell's memory, apps, themes, windows, workspaces, screens, notifications) and About.

## One screen at a time

With more than one screen connected, a picker next to the section title chooses **All screens** or one screen. With a screen picked, the settings that can differ per screen change only there: the bar, the dock, where panels open, the island's spot and the wallpaper look. Everything else stays shared, and **Reset** drops that screen's own values. `sylvaris settings screen DP-2` does the same from a script. More in [configuration](../configuration.md#one-screen-at-a-time).

Every switch is also a `sylvaris set` away, and values that come from `config.json` show where to change them.

| Key (`constellation.`) | Default | Meaning |
|---|---|---|
| `speed` | `1` | how fast the stars drift |
| `ring`, `links`, `labels`, `stars` | `true` | the dashed ring, silk links, labels and starfield |

| Key | Default | Meaning |
|---|---|---|
| `settings.detail` | `"simple"` | `simple` keeps rarely used options behind more options, `full` shows them all |
