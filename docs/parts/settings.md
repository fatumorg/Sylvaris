# SylSettings

The gear in SylCenter, `sylvaris settings` or `sylvaris settings open <section>` opens SylSettings over a starfield.

Tabs at the top split the sections into six groups: System (general, displays, sound, power, accessibility, and lighting once its plugin is on), Look (appearance, wallpaper, motion, app colours), Panels (bar, deck, Control Center, island, notifications, launcher, switcher, sky, weather), Apps (files, viewer, capture, clipboard, and Diver and FaTest once their plugins are on), Security (lock, authentication) and Advanced (key bindings, commands, plugins). Tab and Shift+Tab switch between them. Every section is a star around the core; picking one shrinks the constellation to the top and opens the section below it.

On the left you tune the constellation itself (drift speed, ring, silk links, labels, starfield), which also changes SylCenter's orbits. On the right are statistics (uptime, the shell's memory, apps, themes, windows, workspaces, screens, notifications) and About.

## One screen at a time

With more than one screen connected, a picker next to the section title chooses **All screens** or one screen. With a screen picked, the settings that can differ per screen change only there: the bar, the dock, where panels open, the island's spot and the wallpaper look. Everything else stays shared, and **Reset** drops that screen's own values. `sylvaris settings screen DP-2` does the same from a script. More in [configuration](../configuration.md#one-screen-at-a-time).

Every switch is also a `sylvaris set` away, and values that come from `config.json` show where to change them.

| Key (`constellation.`) | Default | Meaning |
|---|---|---|
| `speed` | `1` | how fast the stars drift |
| `ring`, `links`, `labels`, `stars` | `true` | the dashed ring, silk links, labels and starfield |
