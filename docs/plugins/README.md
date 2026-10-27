# SylPlugins

Plugins add widgets, panels and background helpers to Sylvaris. Four come built in, and you can write or install your own.

Every plugin, built in or not, stays off until you turn it on in SylSettings › Plugins or from a terminal:

```sh
sylvaris plugins enable diver     # also: disable <id>
sylvaris plugins list
```

With Home Manager: `programs.sylvaris.plugins.enabled = { diver = true; airpods = true; };`

## Built-in plugins

- [Diver](diver.md) brings your [Diver](https://diver.fatum.cc) plans, reminders and alarms to the desktop.
- [AirPods](airpods.md) shows battery, listening modes and conversation awareness for AirPods and Beats.
- [FaTest](fatest.md) runs internet speed tests.
- [Keep Awake](awake.md) keeps the screen on while you watch, present or wait.
- [SylRGB](rgb.md) controls the lights on your mouse, keyboard, memory, graphics card and every other device OpenRGB supports.

They are listed first, turn on and off like any other plugin, and cannot be removed. A built-in plugin that is off runs nothing, and its commands, settings page, bar module and launcher tile are hidden.

## Installing a plugin

```sh
sylvaris plugins install https://github.com/someone/sylvaris-weather-plus
```

Sylvaris fetches it and prints the exact commit it resolved to, with a warning. Nothing lands in the plugins folder until you answer yes (or run `sylvaris plugins confirm`; `sylvaris plugins discard` drops it). SylSettings › Plugins shows the same commit and warning with Install and Discard buttons.

> **Plugins run with your full user permissions.** They can read and change your files and run any program. Only install code you trust, and read it first.

`sylvaris plugins remove <id>` deletes one, and `sylvaris plugins refresh` rescans the folder after you edit files by hand.

## Writing a plugin

A plugin is a folder in `~/.config/sylvaris/plugins/<id>/` with a `plugin.json` and a QML file. `sylvaris plugins new <id> [bar|panel|service]` writes a working starter you can edit.

```json
{
  "id": "uptime",
  "name": "Uptime",
  "version": "1.0.0",
  "kind": "bar",
  "entry": "Plugin.qml",
  "description": "How long this computer has been on",
  "author": "you"
}
```

| Field | Rules |
|---|---|
| `id` | lowercase letters, digits and dashes, the same as the folder name |
| `name` | shown in SylSettings |
| `kind` | `bar` (a widget; add `plugin:<id>` to a bar group), `panel` (opens with `sylvaris plugins open <id>`) or `service` (runs in the background) |
| `entry` | a `.qml` file inside the plugin folder |
| `version`, `description`, `author` | shown in SylSettings |

Give every `Text` that shows something from outside (a window title, a song, a network name, a file) `textFormat: Text.PlainText`. Without it, Qt treats text that looks like HTML as HTML, and an `<img>` tag in a window title would make your plugin load that address from the internet.

### The api object

Your root item gets an `api` property if it declares one:

```qml
property var api: null
```

| Member | What it does |
|---|---|
| `api.id` | your plugin's id |
| `api.config` | your settings, from `plugins.config.<id>` |
| `api.set(key, value)` | saves a setting under `plugins.config.<id>.<key>` |
| `api.run(words)` | runs any Sylvaris command, such as `api.run(["center", "open"])`, and returns its reply |

Plugin QML can `import qs`, `qs.services` and `qs.components`, so it can use the theme (`Theme.accent`), the sizes in `Tokens`, and components such as `Glass` and `Glyph` to look like the rest of the shell.

### A complete bar plugin

[`examples/plugins/uptime`](../../examples/plugins/uptime) shows the uptime in the bar: a `FileView` reads `/proc/uptime`, a `Timer` refreshes it every minute, and a `Glyph` with a `Text` draw it in the bar's style. Copy the folder to `~/.config/sylvaris/plugins/uptime`, turn it on, and add `plugin:uptime` to `bar.right`.
