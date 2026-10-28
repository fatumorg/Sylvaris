# Configuration

Everything lives in one folder, `~/.config/sylvaris/`. `sylvaris config` prints the exact paths.

- `config.json` is yours, or Nix's through `programs.sylvaris.settings`. Sylvaris never writes to it.
- `settings.json` belongs to Sylvaris. It holds only what you change in SylSettings, SylCenter or with `sylvaris set`.
- `themes/` holds theme bundles (see [look and motion](look.md#theme-bundles)).

Every key of `settings.json` can also go in `config.json`, where it becomes the default. Declare your bar, deck, equalizer or panel spots in Nix, and anything you change in the UI is saved as an override in `settings.json` and wins. Remove a key from `settings.json` to fall back to your declared value. Both files are watched, so changes apply as soon as they are saved.

```nix
programs.sylvaris.settings = {
  bar.right = [ "tray" "audio" "network" "notifications" "center" ];
  deck = { enabled = true; pinned = [ "firefox" "kitty" ]; };
  notifications.corner = "top-right";
  media.eq = { enabled = true; preset = "bass"; };
};
```

Every key, with its default, is in the [settings reference](reference/settings.md).

## Invalid values

A value that is not valid is replaced by the one below it (your `config.json`, then the default), one key at a time, and SylCenter shows a notice. `sylvaris set` refuses invalid values and says why. If `settings.json` stops being valid JSON, Sylvaris keeps a copy as `settings.json.bak` and carries on with the last good settings.

Both files carry a `version` (currently 1; Home Manager writes it for you). A file without one is upgraded step by step in memory, keeping every key it does not know. A file from a newer Sylvaris is refused with a clear message in `sylvaris doctor`: defaults are used and the file is never overwritten, so going back to an older version cannot damage it.

## Turning parts off

```sh
sylvaris set parts.center false   # exclude SylCenter
sylvaris set parts.center true    # bring it back, no reinstall or reload
```

A part that is off is never loaded, along with anything only it uses, and it runs no process, timer or watcher. The parts are `access`, `bar`, `capture`, `center`, `clip`, `clock`, `deck`, `diver`, `fatest`, `island`, `lock`, `media`, `notify`, `pad`, `paper`, `plugins`, `polkit`, `power`, `settings`, `switcher`, `sync`, `temp`, `theme` and `widgets`. All are on by default except `island`. SylSettings lists them under General.

With Nix, `programs.sylvaris.parts = { center = false; };` writes the same key and also leaves the tools only that part needs off the package's `PATH`. Parts are separate from `bar.left`, `bar.center` and `bar.right`, which only choose what the bar shows.

## Where panels open

SylCenter, SylClock and the notifications each have a corner (`center.corner`, `clock.corner`, `notifications.corner`): `top-left`, `top-center` or `top-right`. The other panels have a spot in `placement`, which also takes `center` for the middle of the screen:

| Key | Default |
|---|---|
| `placement.media` | `auto` (wherever SylCenter opens) |
| `placement.clip` | `top-center` |
| `placement.capture` | `top-center` |
| `placement.access` | `top-center` |
| `placement.diver` | `center` |
| `placement.fatest` | `top-right` |
| `placement.temp` | `top-right` |

With the bar at the bottom or on a side, the top spots follow the bar, so a bar on the left opens panels along the left edge. SylSettings › General sets all of these.

## One screen at a time

Some settings can be different on each screen: the whole bar, the dock (except pinned apps), every panel spot, the island's position, idle look and shortcuts, and the wallpaper look. They live under `screens.<output>`, on top of the shared settings:

```json
"screens": {
  "DP-2": { "bar": { "position": "left" }, "deck": { "hide": "always" } },
  "eDP-1": { "island": { "position": "bottom-center" } }
}
```

```sh
sylvaris set screens.DP-2.bar.position left
sylvaris set screens.DP-2 '{}'        # back to the shared settings
```

In SylSettings, pick the screen next to the section title; changes to per-screen settings then apply only there, and **Reset** clears that screen. The [settings reference](reference/settings.md) marks which keys can differ. Output names are the ones your compositor uses, such as `DP-2` or `HDMI-A-1`.

## Custom toggles

`toggles` in `config.json` adds your own tiles to SylCenter:

```json
"toggles": [
  { "id": "vpn", "label": "VPN", "on": "nmcli con up home-vpn", "off": "nmcli con down home-vpn", "status": "nmcli -t con show --active | grep -q home-vpn" }
]
```

`id` is lowercase letters, digits, `_` and `-`. `status` is a command whose exit code 0 means "on"; without it Sylvaris remembers the last state in `toggleState`. `icon` takes a Nerd Font glyph. A toggle with the id `performance` replaces the built-in Performance tile.

## config.json only

| Key | Default | Meaning |
|---|---|---|
| `themesDir` | `~/.config/sylvaris/themes` | folder of theme bundles |
| `themeHook` | `""` | optional command run with the theme id when a theme is applied |
| `themeStateFile` | `~/.local/state/sylvaris/theme` | file holding the active theme id; Sylvaris watches it |
| `avatar` | `~/.face` | image in the control center and power menu |
| `lockCommand` | `loginctl lock-session` | what SylPower's Lock runs; `sylvaris lock` uses SylLock |
| `terminal` | `kitty` | terminal for terminal apps from SylPad and SylDeck |
| `location` | from your time zone | `{ latitude, longitude }` for SylClock's sky and weather |
| `notifications` | `{ server: true, history: 100 }` | whether Sylvaris is the notification daemon, and how many the center keeps |
| `toggles` | `[]` | custom tiles, above |
| `greeterShare` | `/var/lib/sylvaris-greet/shared` | where the theme is copied for SylGreet |
