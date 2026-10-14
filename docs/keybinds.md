# Key bindings

SylSettings › Advanced › Key bindings lists every action worth a key. Click one and press the keys: Sylvaris adds the binding to Hyprland or sway right away, and again after the compositor reloads its config. The same map lives in `keybinds`:

```nix
programs.sylvaris.keybinds = {
  "switcher next" = "ALT+Tab";
  "clip toggle" = "SUPER+V";
  "files open" = "SUPER+E";
  "capture shot area" = "SUPER+SHIFT+S";
  "lock now" = "SUPER+L";
};
```

It works both ways. Binds you write yourself that run a Sylvaris action show up on the page, marked "from your compositor config". The ones you pick on the page are written to a file your config can include, so they stay even when Sylvaris is not running:

| Compositor | File | Line to add |
|---|---|---|
| Hyprland (Lua) | `~/.config/hypr/sylvaris-keybinds.lua` | `pcall(require, "sylvaris-keybinds")` |
| Hyprland (classic) | `~/.config/hypr/sylvaris-keybinds.conf` | `source = ~/.config/hypr/sylvaris-keybinds.conf` |
| sway | `~/.config/sway/sylvaris-keybinds` | `include ~/.config/sway/sylvaris-keybinds` |

Add the line after your own binds, so the page wins when both set the same keys. A bind picked on the page replaces the one in your config for that action.

niri cannot take bindings at runtime, so there the page shows lines to copy into its config.
