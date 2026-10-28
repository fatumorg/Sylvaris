# SylDeck

A dock along the bottom edge. It is off until you turn it on:

```sh
sylvaris set deck.enabled true
```

Pinned apps come first, then running apps after a divider, with a dot for each open window. Click an app to open it or cycle through its windows, middle-click for a new window, and right-click for its windows, Keep in Deck and Close. You can also pin an app by right-clicking it in [SylPad](pad.md).

| Key (`deck.`) | Default | Meaning |
|---|---|---|
| `enabled` | `false` | show the deck |
| `pinned` | `[]` | desktop file ids, such as `["firefox", "kitty"]` |
| `pad` | `start` | where the SylPad button goes: `start`, `end` or `none` |
| `power` | `none` | where the SylPower button goes: `start`, `end` or `none` |
| `glow` | `false` | a soft light in your accent under apps that have a window; the Lumen look turns it on |
| `effect` | `bloom` | `bloom` lifts the icon under the pointer with a glow, `magnify` grows it and its neighbours, `none` does neither |
| `hide` | `never` | `always` slides away until the pointer touches the bottom edge; `windows` shows the deck on an empty desktop and hides it while windows are open on that screen |
| `peek` | `true` | a thin accent line stays while the deck is hidden |
| `peekSize` | `4` | thickness of that line, 2 to 12 px |
| `reserve` | `true` | keep windows clear of the deck; `false` lets them go underneath |
| `size` | `56` | icon size, 36 to 96 |

Everything except `pinned` can differ per screen, so a small laptop panel can have a hidden deck while your main monitor keeps it: `sylvaris set screens.eDP-1.deck.hide always`.
