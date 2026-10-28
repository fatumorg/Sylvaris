# SylCenter

The control center: Wi-Fi, Bluetooth, night light, Do Not Disturb, the hotspot, volume, what is playing, displays and your theme, in one panel.

```sh
sylvaris center              # toggle (also: open, close)
sylvaris view orbit-wifi     # open on a view
```

Views are `compact`, `orbit-bluetooth`, `orbit-wifi`, `calendar`, `outputs`, `displays` and `hotspot`. Add `:<key>` to focus one device or network, for example `sylvaris view orbit-bluetooth:AA:BB:CC:DD:EE:FF`.

The `outputs` view picks the sound output and, like pavucontrol, lists every app under Apps (playing) and Recording (capturing), each with its stream title and its own volume slider; click an app's icon to mute just that app, and click the output on the right of its slider to move it to the next output or microphone. Apps that stop keep their row, dimmed, until the shell restarts, and a volume set there applies when the app plays again.

The Wi-Fi and Bluetooth views are orbits: your devices or networks circle a glowing core, and picking one turns the orbit into that device's actions (connect, forget, trust, battery, copy the address). While something connects, pairs or disconnects, its label says so.

## Tiles

SylSettings › Control Center picks what the panel shows.

- `center.hidden` lists tiles to leave out: `wifi`, `bluetooth`, `night`, `dnd`, `hotspot`, or `toggle:<id>` for one of your [custom toggles](../configuration.md#custom-toggles).
- `center.volume` and `center.media` turn the volume slider and the now playing card off.
- `center.layout` is `grid` (even tiles, two to a row) or `bento` (the first two tiles wide, the rest as small squares, four to a row; click a square to switch it).
- `center.extra` adds optional tiles: `screenshot` and `record` (an area, or stop a recording), `clip` (clipboard history), `lock`, and, once their plugins are on, `fatest`, `airpods`, `rgb` and `awake`.

`center.corner` sets where it opens: `top-left`, `top-center` or `top-right`. With the bar at the bottom or on a side, the panel follows the bar. The corner can differ per screen.

## Night light

The night light tile warms the screen with `wlsunset`. `nightLight.temperature` sets how warm (4000 K by default).

Hyprland does not pass gamma on to mirrored outputs, so while a monitor mirrors another, Sylvaris warms the picture with a screen shader instead, and the mirror gets it too. It combines with any SylAccessibility colour filter and needs the access part on. Screenshots and recordings stay untinted.

## Hotspot

Share your connection over Wi-Fi. `hotspot.ssid` names the network (1 to 32 characters) and `hotspot.band` picks `bg` (2.4 GHz) or `a` (5 GHz). If the card or your country's rules do not allow 5 GHz, the hotspot falls back to 2.4 GHz. The password is passed to NetworkManager without landing in any file or process list.

## Displays

The displays view arranges your screens: drag them into place and pick the mode and scale for each. `displays.layouts` remembers a layout for each set of connected screens.

**Brightness** has a slider under each screen's modes. A laptop panel uses its backlight through `brightnessctl`; an external monitor uses DDC/CI through `ddcutil`, which needs the `i2c-dev` kernel module and write access to `/dev/i2c-*` (on NixOS, `hardware.i2c.enable = true` and your user in the `i2c` group). A monitor that doesn't answer DDC/CI, like most TVs, shows no slider. Bind keys with `sylvaris brightness up 5` and `sylvaris brightness down 5`; without an output they change the first screen.

**Virtual display** (Hyprland only) adds an extra screen named `virtual` that a tablet such as an iPad shows through any VNC app. Press **Virtual display** under the screens, then drag, scale and save it like any other screen. Pick its size from the presets (`displays.virtual.width` and `height`); it comes back on at login while `displays.virtual.enabled` is true. The view shows the addresses, user and password to connect with. Sylvaris uses wayvnc's own config, `~/.config/wayvnc/config`, and creates it on first use with a random 128-bit password and RSA-AES encryption. A config Sylvaris made earlier with a shorter password gets a new one, and nothing else in it changes. Allow TCP port 5900 in your firewall, and keep the tablet on a fast network: a 5 GHz hotspot from SylCenter works well.
