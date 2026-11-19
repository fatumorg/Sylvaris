# SylKeyboard

An on-screen keyboard for a computer you use from the couch, on a TV or anywhere a real keyboard is out of reach. It types into any app and works with a mouse, a gamepad or a TV remote. It is off by default:

```sh
sylvaris set parts.keyboard true
sylvaris keyboard toggle
```

## Two ways to type

- **Pointer.** Click or tap keys with a mouse. Each key goes straight to the app you were using, and the keyboard never takes focus away from it. Hold ⌫ to keep deleting.
- **Focus.** Move across the keys with a gamepad's d-pad or left stick, or a remote's arrow keys, and press A or OK. What you type waits in a line above the keys, then Start or Enter sends it to the app and closes the keyboard. While it is open in this mode the gamepad belongs to the keyboard, so a game behind it does not move.

The last thing you used decides the mode. Select and Start together open and close the keyboard from a gamepad.

| Gamepad | Remote | Does |
|---|---|---|
| d-pad, left stick | arrows | move between keys |
| A | OK, Enter | press the key |
| B | Back, Esc | close without sending |
| X | Backspace | delete the last letter |
| Y | | add a space |
| Select | | shift |
| Start | Menu, Play | send and close |

Gamepads are read through `/dev/input`, which systemd lets the person at the seat open without root. A TV remote works when it shows up as a keyboard, over USB or Bluetooth; HDMI-CEC needs an adapter such as Pulse-Eight's.

Keys are sent by what they mean, not by position, so your system keyboard layout never changes what comes out and your real keyboard is left alone. `keyboard.layout` only picks what the keys show.

## Commands

```sh
sylvaris keyboard toggle           # also: open [pointer|focus], close
sylvaris keyboard type "some text" # types it into the focused app
sylvaris keyboard press down       # up, down, left, right, a, b, x, y, select, start, combo
sylvaris keyboard state
```

Bind `keyboard open focus` to a key on your remote in your compositor to open it from the couch.

## Settings

| Key (`keyboard.`) | Default | Meaning |
|---|---|---|
| `layout` | `us` | keys shown: `us` or `pl` (Polish programmer, AltGr for ą ć ę ł ń ó ś ź ż) |
| `size` | `1` | key size, 0.6 to 1.6 |
| `gamepad` | `true` | read gamepads |
| `combo` | `true` | Select and Start open and close it |

It needs a compositor with the virtual keyboard protocol for typing and the virtual pointer protocol for SylConnect: Hyprland, niri and sway all have both.
