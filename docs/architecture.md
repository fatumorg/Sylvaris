# How Sylvaris is built

Sylvaris is a Wayland desktop shell in three layers: your compositor at the bottom, SylStack in the middle, and the shell itself, written in QML and JavaScript, on top. This page is the short tour for people who want to know what runs on their machine. [ARCHITECTURE.md](../ARCHITECTURE.md) goes deeper, for people who want to change it.

## The layers

| Layer | What it is | What it does |
|---|---|---|
| Compositor | Hyprland, niri or sway | draws windows, blurs behind panels where it can, sends workspace and window events |
| SylStack | one C++ program on Qt 6.9 or newer | runs the QML shell and gives it native access to the system |
| Shell | QML parts, services and plain JavaScript logic | everything you see: the bar, panels, notifications, lock screen and the rest |
| You | `config.json`, `settings.json`, the `sylvaris` command, Home Manager | decide which parts run and how they look |

## SylStack, the runtime

SylStack is a small Qt Quick runtime made for Sylvaris and kept in the same repository under `stack/`. It is one binary, `sylstack`, that runs a shell entry file and registers one QML module with native backends for what a desktop shell needs: layer-shell, popup and floating windows with blur, processes, files and sockets, desktop entries, PipeWire audio, MPRIS media players, the notification server, the system tray, UPower, NetworkManager, BlueZ, polkit, PAM, greetd, the session lock, and the IPC of each compositor. The Wayland protocols it speaks are kept in the repository too.

SylStack is a trust boundary. What arrives from D-Bus, Wayland or a socket is size-checked before use, passwords are wiped from memory as soon as PAM has them, and every socket it listens on sits in a folder only you can enter.

## Separate processes

| Process | Started by | What it holds |
|---|---|---|
| the shell | `sylvaris`, from your compositor's autostart | every part and the command socket |
| the lock screen | `sylvaris lock` | the session lock and the password check, nothing else |
| the login screen | greetd, inside its own sway | SylGreet |
| the doctor | `sylvaris doctor` | nothing; it reads your config and prints a report |

The lock screen is separate on purpose: a crash in the bar, a panel or a plugin cannot take it down, and the compositor keeps the screen locked even if the lock process itself stops.

## Parts load only when they are on

Each part, such as SylBar, SylCenter or SylNotify, is its own QML module. The shell loads a part only while it is enabled, so a part that is off runs no process, timer or watcher. Panels are built when you open them, their windows are freed when they close, and the rest is freed 20 seconds later. Services such as audio, network or weather start only when a part that is on needs them. The full list of parts is in [parts](parts/README.md).

## Settings in two files

`~/.config/sylvaris/config.json` is yours, or written by Home Manager. Sylvaris never writes it. `settings.json` holds what you change in SylSettings or with `sylvaris set`, and wins over `config.json`. Both are watched and apply live. Every setting has a default and a validator, so an invalid value is replaced by its default and reported by `sylvaris doctor`, never left to break a part. The Home Manager options are generated from those same defaults. [Configuration](configuration.md) has the details.

## One command language

The shell listens on a socket in `$XDG_RUNTIME_DIR/sylvaris/`, in a folder only you can open. Every part exposes actions there, and the `sylvaris` command sends them, so the same words work from a terminal, a key binding or a script. `sylvaris state` and `sylvaris watch` return the shell's state as JSON. See [commands](commands.md).

## One place knows the compositor

Only one service and one logic file know whether Hyprland, niri or sway is running. They translate verbs such as `workspace`, `move-to` or `minimize` into each compositor's language and turn its events into one shape. Where a compositor cannot do something, a capability flag hides or explains the control, and the [table of what works where](compositors.md#what-each-compositor-supports) is generated from those flags.

## One look

Every surface is drawn through one glass component, with colours from the theme, sizes from shared tokens and motion from one set of curves. A test forbids parts from painting their own backgrounds, which is why a Look or theme change reaches every corner of the shell at once. See [look and motion](look.md).

## How it is tested

The logic lives in plain JavaScript modules with no QML in them, tested with Node's test runner. Python helpers have their own unit tests, every QML file goes through `qmllint`, and a headless harness starts the real shell in a virtual sway session to drive it and record it. `nix flake check` runs all of it, plus a build of a NixOS system that uses the login screen. [Working on Sylvaris](development.md) shows how to run them.
