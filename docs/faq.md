# Questions and answers

## What is Sylvaris?

Sylvaris is a modular desktop shell for Wayland. It gives Hyprland, niri and sway a bar, a control center, notifications, a launcher, a dock, a lock and login screen and about twenty other parts, all in one process and one glass design. It is written in QML and JavaScript and runs on SylStack, its own Qt Quick runtime written in C++. It is free software under the MIT licence.

## Which compositors does Sylvaris run on?

Hyprland (with a Lua or a classic config), niri and sway. Nearly everything works the same on all three; [compositors](compositors.md#what-each-compositor-supports) lists the few things one of them cannot do, such as window previews in Alt+Tab on niri and sway. GNOME, KDE Plasma, COSMIC, Cinnamon and Xfce are not supported.

## Does Sylvaris work on X11?

No. Sylvaris draws its panels with the Wayland layer-shell protocol and locks the screen with `ext-session-lock-v1`, so it needs a Wayland compositor.

## Is Sylvaris built on Quickshell?

No. Versions before 1.0 ran on Quickshell. Since 1.0, Sylvaris runs on SylStack, a runtime in the same repository that provides exactly what the shell needs: layer-shell windows, processes, sockets, PipeWire, MPRIS, notifications, the system tray, NetworkManager, BlueZ, UPower, polkit, PAM, greetd and compositor IPC. [Compared with other shells](compare.md) explains how it differs from Quickshell and AGS.

## Can I use SylStack to write my own shell?

It is not meant for that. SylStack registers only the QML types Sylvaris uses, and they change when Sylvaris needs them to. To add your own pieces to Sylvaris, write a [plugin](plugins/README.md): a bar widget, a panel or a background helper that gets the same theme, glass and commands as the built-in parts.

## What do I need to run Sylvaris?

A Linux system with Hyprland, niri or sway, Qt 6.9 or newer, the fonts Inter and JetBrainsMono Nerd Font, and a few small tools that the parts use. [Installing without Nix](install.md) has the commands for Arch, Fedora, Debian, Ubuntu, openSUSE, Void and Gentoo. Linux Mint 22, Ubuntu 24.04, Debian 13 and others with an older Qt can use Nix, which brings its own.

## How do I install Sylvaris on NixOS?

Add the flake as an input, import `sylvaris.homeManagerModules.sylvaris` and set `programs.sylvaris.enable = true`. Every setting is a typed Home Manager option. Import `sylvaris.nixosModules.sylvaris` too for the lock screen's PAM service and the SylGreet login screen. Keep `inputs.sylvaris.inputs.nixpkgs.follows = "nixpkgs"`, so the lock screen loads PAM modules from the same nixpkgs as your system. [Nix and Home Manager](nix.md) has the whole setup.

## Can I try Sylvaris without installing it?

Yes, with Nix, from a running Hyprland, niri or sway session: `nix run github:fatumorg/Sylvaris`. Stop your notification daemon and wallpaper program first, since Sylvaris takes over both.

## Does Sylvaris replace my notification daemon, wallpaper tool and polkit agent?

Yes, while those parts are on. Sylvaris is a notification daemon, draws the wallpaper and can be your polkit agent, so stop mako, dunst, SwayNC, hyprpaper, swaybg or swww first. Only one program can own each of those roles. If you would rather keep one of them, turn the matching part off.

## Can I turn parts off?

Yes. Every part is optional: `sylvaris set parts.clock false`, the switches in SylSettings, or `programs.sylvaris.parts` in Home Manager. A part that is off is never loaded and runs no process, timer or watcher, and with Nix the tools only it needs stay off your `PATH`. See [turning parts off](configuration.md#turning-parts-off).

## How do themes and Looks work?

A theme sets the colours and the wallpaper. A Look sets everything else: the glass, corners, spacing, fonts, controls, motion and the layout of the bar, the control center and notifications. Pick any theme with any Look, or let the theme name its Look. Themes are JSON files you can write by hand, make in SylSettings, or generate from your wallpaper, and [SylSync](parts/sync.md) carries their colours into GTK, Qt, terminals, editors and Firefox. Read [look and motion](look.md) for the details.

## Why is there no blur on sway?

Sylvaris asks the compositor to blur behind each panel through the `ext-background-effect-v1` protocol. Hyprland 0.56 and newer and niri offer it; sway does not, so the glass there is translucent without blur.

## How much memory and CPU does Sylvaris use?

In the headless test harness, with demo data on one 2560×1440 screen and every part on, the whole process used about 150 MB and 0.5 % of one core at idle with software rendering, and about 270 MB with an NVIDIA GPU, where the driver's mappings count too. With only the bar and notifications it used about 101 MB. Your numbers depend on your setup; `tests/bench/bench.sh` measures your own machine the same way.

## Is the lock screen safe to rely on?

SylLock runs in its own process, apart from the bar, every other part and every plugin, so a crash there leaves the lock screen up. It uses the session-lock protocol, so the compositor keeps the screen locked even if the lock process stops. Passwords are checked by PAM and only ever live in the lock process. As with any lock screen, keep another way to log in, such as a text console, in case something goes wrong. See [SylLock](parts/lock.md).

## Can I control Sylvaris from scripts and key bindings?

Yes. Every switch is a command, such as `sylvaris center`, `sylvaris capture shot area` or `sylvaris set bar.position left`. `sylvaris list` prints every command, `sylvaris state` prints the shell's state as JSON and `sylvaris watch` streams changes. The same commands work over a socket in `$XDG_RUNTIME_DIR/sylvaris/`. See [commands](commands.md) and [key bindings](keybinds.md).

## Does Sylvaris work with more than one monitor?

Yes. The bar, the dock, panel spots, the island and the wallpaper can each be set differently per screen under `screens.<output>`, and SylSettings has a picker for one screen at a time. See [one screen at a time](configuration.md#one-screen-at-a-time).

## Where do I ask for help or report a bug?

Ask questions and share your desktop on [GitHub Discussions](https://github.com/fatumorg/Sylvaris/discussions). For a bug, run `sylvaris doctor`, which prints versions, GPUs, missing tools and invalid settings, and paste it into a [new issue](https://github.com/fatumorg/Sylvaris/issues).
