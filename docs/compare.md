# Sylvaris compared with other Wayland shells

There are several ways to put a bar, a launcher and notifications on a Wayland desktop. They split into two kinds: toolkits you build your own shell with, and finished shells you configure. Sylvaris is the second kind. This page says what that means next to Quickshell, AGS, eww and the usual Waybar setup, so you can pick the one that fits.

The notes on other projects describe what each one is for, as of November 2026. They change quickly, so check their own documentation before you decide.

## At a glance

| | Sylvaris | Quickshell | AGS with Astal | eww | Waybar and friends |
|---|---|---|---|---|---|
| What it is | a finished desktop shell | a toolkit for writing shells | a toolkit for writing shells | a widget system | a bar, plus separate tools |
| You write | settings, or nothing | QML | TypeScript or JavaScript (JSX) | yuck and SCSS | JSON and CSS |
| Drawn with | Qt Quick, on SylStack | Qt Quick | GTK 3 or GTK 4 | GTK 3 | GTK 3 |
| Out of the box | bar, control center, notifications, launcher, lock, login screen and about twenty more parts | building blocks; shells others wrote on top | building blocks; shells others wrote on top | building blocks | a bar; notifications, launcher and lock come from other programs |
| Compositors | Hyprland, niri and sway | Wayland compositors with layer shell, with extra Hyprland and i3 or sway integration | depends on the Astal libraries you use | X11 and Wayland | sway, Hyprland, niri and other Wayland compositors |
| Configured with Nix | typed Home Manager option for every setting, NixOS module for PAM and greetd | your QML files | your own code | your own files | Home Manager has a Waybar module |

## Quickshell

[Quickshell](https://quickshell.org) is a toolkit for building desktop shells in QML. It gives you layer-shell windows and bindings for common desktop services, and you write the shell yourself. Many people do: there are complete shells built on it, such as Caelestia and DankMaterialShell, each with its own look and its own set of features.

Sylvaris also used Quickshell until version 1.0, then moved to its own runtime, SylStack. Both draw with Qt Quick, so the result feels similar, but they aim at different people:

- **Choose Quickshell** if you want to write your own shell, or pick one of the many shells built on it. It is a general toolkit with an active community and many examples.
- **Choose Sylvaris** if you want a finished shell where every part was designed together and keeps working the same on Hyprland, niri and sway. You change it through settings, commands and Home Manager instead of code, and you can still add your own pieces as [plugins](plugins/README.md).

SylStack is not a replacement for Quickshell as a toolkit. It registers only the QML types Sylvaris uses, and its interface follows what Sylvaris needs. If you are looking for a Quickshell alternative to write a shell from scratch with, SylStack is not that; if you are looking for an alternative to the shells built on Quickshell, Sylvaris is one.

## AGS and Astal

[AGS](https://github.com/Aylur/ags) (Aylur's GTK Shell) lets you write widgets in TypeScript or JavaScript with JSX, drawn with GTK and run with GJS. The [Astal](https://github.com/Aylur/astal) libraries underneath provide the services: compositor state, audio, network, Bluetooth, battery, media, notifications and more. Like Quickshell, it is a toolkit, and complete shells such as HyprPanel are built on it.

AGS suits you if you know web-style JavaScript and want GTK widgets. Sylvaris is written in QML and JavaScript too, but you do not have to write any to use it.

## eww

[eww](https://github.com/elkowar/eww) (ElKowar's Wacky Widgets) builds widgets from its own small language, yuck, styled with SCSS. It runs on X11 and Wayland and is a good fit for a handful of hand-made widgets or a bar. It does not try to be a notification daemon, lock screen or launcher; those come from other programs.

## Waybar with mako, fuzzel and swaylock

The classic setup is one small program per job: Waybar for the bar, mako, dunst or SwayNC for notifications, fuzzel, wofi or rofi as the launcher, swaylock or hyprlock for the lock screen, a wallpaper tool and a polkit agent. Each is light, well known and replaceable on its own. The cost is that each has its own config format and its own look, and you keep them in step yourself.

Sylvaris replaces that whole stack in one process with one look and one settings file. Turn off the parts you would rather keep from your old setup: a part that is off is never loaded. It cannot share its notification, wallpaper or polkit role with another program at the same time, so stop the one you replace (see [getting started](start.md#2-start-it-with-your-compositor)).

## What Sylvaris does differently

- **One design across every part.** Bar, panels, notifications, lock and login screens are drawn in the same [Resin Glass](look.md#resin-glass), a glassmorphism look that the compositor blurs by shape. Seven [Looks](look.md#looks) restyle all of it at once, and [SylSync](parts/sync.md) carries your theme's colours into GTK, Qt, terminals, editors and Firefox.
- **Only what you enable.** Every part is optional. A part that is off runs no process, timer or watcher, and with Nix the tools only it needs stay off your `PATH`.
- **The same shell on three compositors.** Hyprland, niri and sway get the same features, and where one cannot do something, a [capability table](compositors.md#what-each-compositor-supports) generated from the code says so and the setting is hidden instead of failing.
- **Declarative on NixOS.** The Home Manager module has one typed option for every setting, generated from the shell's own defaults, and the NixOS module sets up the lock screen's PAM service and the SylGreet login screen under greetd. See [Nix and Home Manager](nix.md).
- **Scriptable.** Every switch is a `sylvaris` command, and `sylvaris state` and `sylvaris watch` give scripts the shell's state as JSON. See [commands](commands.md).
- **A lock screen in its own process.** A crash in the bar, a panel or a plugin cannot take [SylLock](parts/lock.md) with it, and the compositor keeps the session locked if the lock process stops.

## Where Sylvaris is not the right pick

- You use GNOME, KDE Plasma, COSMIC or an X11 window manager. Sylvaris needs Hyprland, niri or sway.
- Your distribution's Qt is older than 6.9 and you do not want Nix. See [installing](install.md#find-your-distribution).
- You want to write the shell yourself, line by line. Quickshell or AGS fit that better.
- You want blur on sway. sway has no blur protocol, so the glass is translucent only there.
- You want a large ecosystem of community configs. Sylvaris is a single project with one maintainer, and its community lives on [GitHub Discussions](https://github.com/fatumorg/Sylvaris/discussions).
