# Compositors

Sylvaris runs on Hyprland (Lua or classic config), niri and sway. Nearly everything works the same on all three. Where a compositor cannot do something, Sylvaris hides the control or says why instead of failing.

## What each compositor supports

This table is generated from `CAPABILITIES` in `shell/lib/wm.mjs`, and a test keeps it in step with the code.

| | Hyprland | niri | sway |
|---|:---:|:---:|:---:|
| Key bindings from SylSettings applied live | yes | no | yes |
| Window previews in SylSwitch | yes | no | no |
| Minimize by clicking the title in SylBar | yes | no | yes |
| Screenshot of a single window | yes | no | yes |
| Screen zoom in SylAccessibility | yes | no | no |
| Colour filters in SylAccessibility | yes | no | no |
| Performance mode also trims the compositor | yes | no | yes |

Resin Glass blurs behind panels through the `ext-background-effect-v1` protocol when the compositor offers it. Hyprland 0.56 and newer and niri do; sway does not, so panels there are tinted glass without blur.

## Layer rules

Sylvaris animates its own panels, so turn off the compositor's layer animation for them. Turn it off for slurp too, or its fading overlay ends up in region and window screenshots:

```lua
hl.layer_rule({ name = "sylvaris", match = { namespace = "^syl" }, no_anim = true })
hl.layer_rule({ name = "slurp", match = { namespace = "^selection$" }, no_anim = true })
```

```ini
layerrule = noanim, ^syl
layerrule = noanim, ^(selection)$
```

Do not add `blur` or `ignore_alpha` layer rules, and on niri leave out `background-effect { blur true }`. They blur by transparency instead of by shape, which leaves jagged edges around rounded corners.

## One set of window commands

`sylvaris wm` speaks one language to all three, so key bindings and scripts never care which compositor is running.

| Command | What it does |
|---|---|
| `wm workspace <n\|next\|prev>` | go to a workspace |
| `wm move-to <n\|next\|prev>` | send the focused window to a workspace |
| `wm focus <left\|right\|up\|down>` | move focus |
| `wm move <left\|right\|up\|down>` | move the focused window |
| `wm close`, `wm fullscreen`, `wm float` | act on the focused window |
| `wm minimize`, `wm restore` | park the focused window and bring it back (Hyprland, sway) |
| `wm exec <command>` | run a command |
| `wm reload`, `wm quit` | reload the compositor's config, or leave the session |
| `wm` or `sylvaris state compositor` | workspaces, windows and the focused window as JSON |

The state has the same shape everywhere: each workspace has `index`, `name`, `output`, `active`, `focused`, `urgent` and a window count, read live from Hyprland's and sway's IPC and from niri's event stream. Windows come from the Wayland foreign-toplevel protocol, which all three support.
