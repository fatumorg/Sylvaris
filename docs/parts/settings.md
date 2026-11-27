# SylSettings

The gear in SylCenter, `sylvaris settings` or `sylvaris settings open <section>` opens SylSettings.

Pages sit in nine groups: **Look** (style, theme & colours, wallpaper, widgets, motion, app colours), **Panels** (bar, deck, Control Center, island, notifications, launcher, switcher), **Apps** (files, archive, viewer, capture, clipboard, notes, task manager), **Clock & weather** (clock & sky, weather), **System** (general, displays, sound, power, accessibility, keyboard), **Shortcuts** (key bindings, commands), **Security** (lock, authentication), **Plugins** (plugins, plus Diver, FaTest, SylTemp and lighting once their plugins are on) and **About**. An open page fills a wide window with every page listed in a sidebar on its left, under its group, and the search box on top. `sylvaris settings open <section>` opens any page, and `sylvaris settings open <group>` opens the page you used last in that group.

## Home screen

`settings.home` picks what SylSettings shows before you pick a page. Change it under General › Settings home, at the foot of the sidebar or in the top corner of any home screen.

- `cards` (default): a card per group with its pages as buttons; click a page to open it or the card to open the group.
- `sidebar`: no home screen, SylSettings opens straight on the page you used last (General the first time) and Escape closes it.
- `constellation`: the groups as stars around a core, each with its pages written under it. Tab and Shift+Tab walk the stars and Enter opens one.

Escape on a page goes back to the home screen, and Escape there closes SylSettings.

## Search

Start typing anywhere and the search pill takes it: every setting is listed by name and by the words people use for it, so "dock", "blur" or "dnd" all find something. Arrow keys pick a result and Enter jumps to the section and lights up the row. Switches can be flipped right in the results. `sylvaris settings search <words>` prints the same matches.

## Simple and full

By default (`settings.detail: "simple"`) the options most people never touch wait behind a **more options** row at the bottom of each section. **All options** under the page title, or `sylvaris set settings.detail full`, shows everything everywhere.

## Style studio

Look › Style starts with a live sample: a panel, a few chips and a title drawn with your Look. Point at another Look for half a second and the sample shows that one instead, with its name, material, corners and spacing; nothing changes until you click it.

## Changes, reset and undo

A setting you changed carries a small accent dot next to its name; click it to reset that setting to its default (or to the Look's value). Every change made here shows an **Undo** toast, and Ctrl+Z undoes the last twenty changes. The same from a script: `sylvaris settings reset <key>` and `sylvaris settings undo`.

The About page shows statistics (uptime, the shell's memory, apps, themes, windows, workspaces, screens, notifications), the version and the config folder. While the constellation is the home screen it also tunes the constellation itself (drift speed, ring, silk links, labels, starfield), which also changes SylCenter's orbits.

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
| `settings.home` | `"cards"` | the home screen: `cards`, `sidebar` or `constellation` |
