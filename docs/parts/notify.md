# SylNotify

Sylvaris is your notification daemon, so stop swaync, mako or dunst before starting it. Only one program can own notifications.

Toasts pop up in the corner set by `notifications.corner` (top-right by default), newest on top. Hovering a toast pauses its timer, clicking it runs the app's default action, and action buttons go straight back to the app. Urgent notifications stay until you close them and still pop up during Do Not Disturb.

```sh
sylvaris notify               # the notification center
sylvaris notify clear
sylvaris notify dismiss <id>
sylvaris notify invoke <id> [action]
sylvaris dnd on               # also: off, toggle
```

The notification center groups everything by app, with a Do Not Disturb switch and Clear buttons.

| Key | Default | Meaning |
|---|---|---|
| `notifications.dnd` | `false` | Do Not Disturb |
| `notifications.timeout` | `5000` | how long a toast stays, in ms (1000 to 60000), unless the app asks otherwise |
| `notifications.corner` | `top-right` | `top-left`, `top-center` or `top-right`, per screen if you like |
| `notifications.stack` | `list` | `list` shows toasts one under another; `cards` stacks them as a fanned deck that spreads into the list when you point at it |

In `config.json`, `notifications.server = false` hands notifications back to another daemon (Do Not Disturb then drives swaync or mako), and `notifications.history` caps the center at 100.

With [SylIsland](island.md) on, messages, calls and (if you choose) all notifications show in the island instead of as toasts. Critical ones still pop up.
