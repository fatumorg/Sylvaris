# SylLock

> **Experimental.** Test it on your machine before you depend on it, and keep another way to unlock at hand.

`sylvaris lock` locks every screen with the session-lock protocol and mirrors what you type on all of them. Nothing can draw over it, and the compositor keeps the session locked even if Sylvaris stops.

The lock runs as its own SylStack process (`lock.qml`), separate from the bar, every other part and every plugin, so a crash in the main shell leaves the lock screen up and working. It looks like the rest of Sylvaris: your wallpaper, a large clock and a password field that shakes on a wrong password.

Passwords are checked by PAM with the first of the `sylvaris`, `hyprlock`, `swaylock` or `login` services that exists; `lock.pam` picks one yourself. The [NixOS module](../nix.md#nixos-module) adds the `sylvaris` service.

| Key (`lock.`) | Default | Meaning |
|---|---|---|
| `pam` | `""` | PAM service; empty picks the first one that exists |
| `logind` | `false` | lock whenever something runs `loginctl lock-session`, such as hypridle |
| `seconds` | `false` | show seconds on the clock |

Set `lockCommand` in `config.json` to `sylvaris lock` so SylPower's Lock uses it.
