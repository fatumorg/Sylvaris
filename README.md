<p align="center">
  <img src="docs/assets/logo.svg" width="128" alt="Sylvaris logo">
</p>

<h1 align="center">Sylvaris</h1>

<p align="center">
  <b>A glass desktop shell for Hyprland, niri and sway.</b><br>
  One process, twenty-five parts, and every one of them optional.
</p>

<p align="center">
  <a href="stack"><img src="https://img.shields.io/badge/SylStack-1.0-c9702f?style=for-the-badge" alt="SylStack"></a>
  <a href="https://hyprland.org"><img src="https://img.shields.io/badge/Hyprland-58e1ff?style=for-the-badge&logo=hyprland&logoColor=black" alt="Hyprland"></a>
  <img src="https://img.shields.io/badge/niri-e0955c?style=for-the-badge" alt="niri">
  <img src="https://img.shields.io/badge/sway-68751c?style=for-the-badge&logo=sway&logoColor=white" alt="sway">
  <a href="https://nixos.org"><img src="https://img.shields.io/badge/Nix_flake-5277c3?style=for-the-badge&logo=nixos&logoColor=white" alt="Nix flake"></a>
  <img src="https://img.shields.io/badge/license-MIT-a85c32?style=for-the-badge" alt="MIT">
  <a href="https://github.com/fatumorg/Sylvaris/actions/workflows/check.yml"><img src="https://img.shields.io/github/actions/workflow/status/fatumorg/Sylvaris/check.yml?branch=main&style=for-the-badge&label=checks" alt="Checks"></a>
</p>

<p align="center">
  <img src="docs/demo/center.gif" width="840" alt="SylCenter and SylClock">
</p>

## 🧪 Try it

From a Hyprland, niri or sway session with Nix, start it once without installing anything:

```sh
nix run github:fatumorg/Sylvaris
```

## 🌿 Why Sylvaris

- **One process.** Twenty-five parts run together on SylStack, Sylvaris's own Qt runtime.
- **Only what you enable.** A part you turn off is never loaded, and its tools stay off your `PATH`.
- **Three compositors.** The same shell runs on Hyprland, niri and sway.
- **Scriptable and declarative.** Every switch is a `sylvaris` command, and every setting is a typed Home Manager option.
- **One look everywhere.** Themes preview live, and SylSync makes GTK, Qt, terminals and editors follow them.
- **Looks, not just colours.** Pick Lumen, Classic, Frost, Ink, Neon or Paper to change glass, corners, spacing and type at once, let Sylvaris shuffle them each day, or make a theme from your wallpaper.

## ✨ What's inside

<table>
  <tr>
    <td width="33%" valign="top">
      <h3>🧭 Everyday</h3>
      <b>SylBar</b> glass bar on any edge, or one floating pill<br>
      <b>SylCenter</b> control center with orbits and bento tiles<br>
      <b>SylClock</b> live sky, weather, calendar<br>
      <b>SylNotify</b> notifications as quiet toasts or a fanned stack<br>
      <b>SylIsland</b> live activities you can control<br>
      <b>SylDeck</b> dock that hides when windows open<br>
      <b>SylPad</b> launcher, grid or list<br>
      <b>SylWidget</b> clocks, notes, now playing and more on the desktop
    </td>
    <td width="33%" valign="top">
      <h3>🛠️ Tools</h3>
      <b>SylSwitch</b> Alt+Tab with previews<br>
      <b>SylClip</b> clipboard history<br>
      <b>SylCapture</b> screenshots and recording<br>
      <b>SylMedia</b> player, equalizer, AirPods<br>
      <b>SylDiver</b> <a href="https://diver.fatum.cc">Diver</a> planner and alarms<br>
      <b>SylFiles</b> file manager, as many windows as you like<br>
      <b>SylNotes</b> small editor for notes and code<br>
      <b>SylTemp</b> temperatures, with an overlay for games<br>
      <b>SylPower</b> power menu constellation
    </td>
    <td width="33%" valign="top">
      <h3>🎨 System</h3>
      <b>SylTheme</b> themes with live preview<br>
      <b>SylSync</b> apps follow your theme<br>
      <b>SylLock</b> · <b>SylGreet</b> lock and login <i>(experimental)</i><br>
      <b>SylPolkit</b> password prompts <i>(experimental)</i><br>
      <b>SylAccessibility</b> zoom and filters<br>
      <b>SylPlugins</b> your own widgets
    </td>
  </tr>
</table>

## 🎬 A closer look

<table>
  <tr>
    <td width="50%"><img src="docs/demo/theme.gif" alt="SylTheme"><br><sub><b>SylTheme</b> previews the whole desktop before you pick</sub></td>
    <td width="50%"><img src="docs/demo/settings.gif" alt="SylSettings"><br><sub><b>SylSettings</b> with a live preview for every look</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/demo/pad.gif" alt="SylPad and SylSwitch"><br><sub><b>SylPad</b> and <b>SylSwitch</b></sub></td>
    <td width="50%"><img src="docs/demo/tools.gif" alt="SylDiver, SylClip, SylCapture, SylPower"><br><sub><b>SylDiver</b>, <b>SylClip</b>, <b>SylCapture</b> and <b>SylPower</b></sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/demo/widgets.gif" alt="SylWidget"><br><sub><b>SylWidget</b> places clocks, notes and now playing on the desktop</sub></td>
    <td width="50%"><img src="docs/demo/temp.gif" alt="SylTemp"><br><sub><b>SylTemp</b> shows temperatures in a panel or over a game</sub></td>
  </tr>
</table>

<p align="center"><img src="docs/demo/lock.gif" width="560" alt="SylLock"><br><sub><b>SylLock</b>, and SylGreet looks the same at login (both experimental)</sub></p>

## 📦 Install

```nix
{
  inputs.sylvaris.url = "github:fatumorg/Sylvaris";
  inputs.sylvaris.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { sylvaris, ... }: {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      modules = [
        sylvaris.homeManagerModules.sylvaris
        {
          programs.sylvaris = {
            enable = true;
            bar.position = "top";
            deck = { enabled = true; hide = "windows"; };
            keybinds = { "switcher next" = "ALT+Tab"; "clip toggle" = "SUPER+V"; };
            parts.media = false;
          };
        }
      ];
    };
  };
}
```

Every setting is a typed Home Manager option. For the lock screen's PAM service and the SylGreet login screen, also import `sylvaris.nixosModules.sylvaris`. Every option is in [docs/nix.md](docs/nix.md). Not on Nix? [docs/install.md](docs/install.md) has steps for Arch, Fedora, Debian, Ubuntu, Linux Mint, openSUSE, Void, Gentoo and every other distribution: `make` builds SylStack, `sudo make install` puts everything in place.

## 🚀 Start

| Compositor | Add to its config |
|---|---|
| Hyprland (Lua) | `hl.exec_cmd("sylvaris")` in `hl.on("hyprland.start", …)` |
| Hyprland | `exec-once = sylvaris` |
| niri | `spawn-at-startup "sylvaris"` |
| sway | `exec sylvaris` |

Then open **SylSettings** from SylCenter's gear, or run `sylvaris settings`, and type to search any setting. Every switch is also a command:

```sh
sylvaris center           # control center
sylvaris switcher next    # Alt+Tab
sylvaris capture shot area
sylvaris lock
sylvaris set bar.position left
sylvaris list             # everything else
```

## 🪶 Only what you enable

Parts you turn off in `parts` are never loaded, and their tools stay off your `PATH`. Panels are built when you open them; their windows are freed the moment they close and the rest 20 seconds later.

| Measured in the headless harness | Software rendering | GPU (NVIDIA) |
|---|---:|---:|
| Idle, every part on | 150 MB · 0.5 % CPU | 270 MB · 0.5 % CPU |
| After opening every panel once, 25 s later | 168 MB | 348 MB |
| Idle, only the bar and notifications | 101 MB · 0.4 % CPU | 243 MB · 1.6 % CPU |

Resident memory of the Sylvaris process, including SylStack, Qt and, with a GPU, the driver's mappings; CPU is a share of one core over 20 idle seconds. Demo data on one 2560×1440 output with SylStack 1.0.0 and Qt 6.11. Run `tests/bench/bench.sh` to measure on your machine (`BENCH_SETTINGS` takes a `settings.json` to compare setups; set `HL_RENDERER=gles2 HL_QT_BACKEND=rhi` for GPU rendering).

## 📖 Learn more

The [documentation](docs/README.md) covers every part, command and setting, theme bundles, plugins, Nix and development, one page each. [ARCHITECTURE.md](ARCHITECTURE.md) explains how the shell is built, [CONTRIBUTING.md](CONTRIBUTING.md) how to work on it, and [CHANGELOG.md](CHANGELOG.md) what changed.

## 💛 Credits

The constellation idea is inspired by [ilyamiro/serpantinum](https://github.com/ilyamiro/serpantinum). Weather by [Open-Meteo](https://open-meteo.com). AirPods support follows the protocol documented by LibrePods. Made with AI assistance, all changes tested, reviewed and used daily by a real group of people.

## 📄 License

MIT
