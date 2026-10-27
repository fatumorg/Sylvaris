# Getting started

Sylvaris is a desktop shell for Hyprland, niri and sway: a bar, a control center, notifications, a launcher, a lock screen and about twenty other parts, all in one process and all drawn in the same warm glass. It runs on SylStack, its own small runtime that comes with it, and needs Qt 6.9 or newer.

## 1. Install it

With Nix, add the flake and turn it on in Home Manager. Everything is described in [Nix and Home Manager](nix.md).

```nix
inputs.sylvaris.url = "github:fatumorg/Sylvaris";
inputs.sylvaris.inputs.nixpkgs.follows = "nixpkgs";
```

On Arch, Fedora, Debian, Ubuntu, Linux Mint, openSUSE, Void, Gentoo and any other distribution, follow [install.md](install.md). It has the commands for each one, a Nix route for distributions whose Qt is too old, and `sylvaris doctor` to check the result.

## 2. Start it with your compositor

| Compositor | Autostart | A key for the control center |
|---|---|---|
| Hyprland (`hyprland.conf`) | `exec-once = sylvaris` | `bind = SUPER, A, exec, sylvaris center` |
| Hyprland (Lua) | `hl.exec_cmd("sylvaris")` inside `hl.on("hyprland.start", ...)` | `hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("sylvaris center"))` |
| niri | `spawn-at-startup "sylvaris"` | `Mod+A { spawn "sylvaris" "center"; }` |
| sway | `exec sylvaris` | `bindsym $mod+a exec sylvaris center` |

Sylvaris is also your notification daemon, wallpaper and (if you want) polkit agent, so stop mako, dunst, swaync, hyprpaper, swaybg or swww first. Only one program can own each of those.

## 3. Let it draw its own glass

Sylvaris asks the compositor for blur shaped exactly like each panel, rounded corners included, and animates every panel itself. Turn off the compositor's own layer animation for Sylvaris, and for slurp so its fading overlay never ends up in a screenshot:

```lua
hl.layer_rule({ name = "sylvaris", match = { namespace = "^syl" }, no_anim = true })
hl.layer_rule({ name = "slurp", match = { namespace = "^selection$" }, no_anim = true })
```

```ini
layerrule = noanim, ^syl
layerrule = noanim, ^(selection)$
```

Do not add `blur` or `ignore_alpha` layer rules: they blur by transparency instead of by shape, which leaves jagged edges around the corners. On niri, leave out `background-effect { blur true }` for the same reason. sway has no blur, so there the glass is translucent only. More in [compositors](compositors.md).

## 4. Look around

Open **SylSettings** from the gear in the control center, or run `sylvaris settings`. Every switch there is also a command:

```sh
sylvaris center              # the control center
sylvaris set bar.position left
sylvaris theme               # pick a theme with a live preview
sylvaris list                # every command
```

Then pick the parts you want. [Parts](parts/README.md) describes each one, and [configuration](configuration.md) explains where your settings live and how to turn parts off.

## When something is off

`sylvaris doctor` prints what a bug report needs: versions, your GPUs, which parts are on, the PAM service the lock checks your password with (with how to install the `sylvaris` one when it falls back to `login`), the programs a part needs but cannot find, fonts Qt cannot find, and every setting that is not valid, with the value used instead. It only reads, and it works even when the shell is not running.
