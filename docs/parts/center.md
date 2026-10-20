# SylCenter

The control center: Wi-Fi, Bluetooth, night light, Do Not Disturb, the hotspot, volume, what is playing, displays and your theme, in one panel.

```sh
sylvaris center              # toggle (also: open, close)
sylvaris view orbit-wifi     # open on a view
```

Views are `compact`, `orbit-bluetooth`, `orbit-wifi`, `calendar`, `outputs`, `displays` and `hotspot`. Add `:<key>` to focus one device or network, for example `sylvaris view orbit-bluetooth:AA:BB:CC:DD:EE:FF`.

The `outputs` view picks the sound output and, under Apps, gives every app that is playing its own volume slider; click an app's speaker icon to mute just that app.

The Wi-Fi and Bluetooth views are orbits: your devices or networks circle a glowing core, and picking one turns the orbit into that device's actions (connect, forget, trust, battery, copy the address). While something connects, pairs or disconnects, its label says so.

## Tiles

SylSettings › Control Center picks what the panel shows.

- `center.hidden` lists tiles to leave out: `wifi`, `bluetooth`, `night`, `dnd`, `hotspot`, or `toggle:<id>` for one of your [custom toggles](../configuration.md#custom-toggles).
- `center.volume` and `center.media` turn the volume slider and the now playing card off.
- `center.extra` adds optional tiles: `screenshot` and `record` (an area, or stop a recording), `clip` (clipboard history), `lock`, and, once their plugins are on, `fatest` and `airpods`.

`center.corner` sets where it opens: `top-left`, `top-center` or `top-right`. With the bar at the bottom or on a side, the panel follows the bar. The corner can differ per screen.

## Night light

The night light tile warms the screen with `wlsunset`. `nightLight.temperature` sets how warm (4000 K by default).

Hyprland does not pass gamma on to mirrored outputs, so while a monitor mirrors another, Sylvaris warms the picture with a screen shader instead, and the mirror gets it too. It combines with any SylAccessibility colour filter and needs the access part on. Screenshots and recordings stay untinted.

## Hotspot

Share your connection over Wi-Fi. `hotspot.ssid` names the network (1 to 32 characters) and `hotspot.band` picks `bg` (2.4 GHz) or `a` (5 GHz). If the card or your country's rules do not allow 5 GHz, the hotspot falls back to 2.4 GHz. The password is passed to NetworkManager without landing in any file or process list.

## Displays

The displays view arranges your screens: drag them into place and pick the mode and scale for each. `displays.layouts` remembers a layout for each set of connected screens.
