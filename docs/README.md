# Sylvaris documentation

Sylvaris is a modular Wayland desktop shell for Hyprland, niri and sway. It is written in QML and JavaScript, runs on SylStack, its own Qt Quick runtime, draws every part in one glass design and comes with NixOS and Home Manager modules. These pages cover installing it, every part, every setting and command, plugins, and Nix.

## Start here

- [Getting started](start.md): install, autostart, the first commands
- [Installing without Nix](install.md): Arch, Fedora, Debian, Ubuntu, Linux Mint, openSUSE, Void, Gentoo and any other distribution
- [Nix and Home Manager](nix.md): the flake, every option, the NixOS module
- [Compared with other shells](compare.md): Sylvaris next to Quickshell, AGS, eww and Waybar
- [Questions and answers](faq.md): compositors, X11, Quickshell, requirements, memory, the lock screen

## Using it

- [Parts](parts/README.md): what each part does, one page each
- [Commands](commands.md): every command, and the socket for scripts
- [Configuration](configuration.md): where settings live, turning parts off, panel spots, per-screen settings
- [Look and motion](look.md): Resin Glass, theme bundles, animation and performance
- [Key bindings](keybinds.md)
- [Compositors](compositors.md): what works where, and `sylvaris wm`

## Plugins

- [SylPlugins](plugins/README.md): turning plugins on, installing and writing your own
- [Diver](plugins/diver.md), [AirPods](plugins/airpods.md), [FaTest](plugins/fatest.md), [Keep Awake](plugins/awake.md), [SylRGB](plugins/rgb.md) and [SylTemp](plugins/temp.md), the built-in ones

## Reference

- [Settings reference](reference/settings.md): every key and its default
- [How Sylvaris is built](architecture.md): SylStack, processes, settings, commands and tests
- [Working on Sylvaris](development.md)
