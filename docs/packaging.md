# Packaging Sylvaris

This page is for anyone who wants to package Sylvaris for a distribution. Templates for the AUR, Void Linux and nixpkgs live in [`dist/`](../dist), and every one of them builds the same way.

## What gets built

Sylvaris is two pieces from one source tree:

- **SylStack**, a small Qt 6 runtime in `stack/`, built with CMake. It installs the `sylstack` binary.
- **The shell**, QML and helper scripts in `shell/`, plus the `bin/sylvaris` launcher. Nothing in it is compiled.

The Makefile drives both:

```sh
make PREFIX=/usr sylstack
make DESTDIR="$pkgdir" PREFIX=/usr install
```

`make install` installs `sylstack` through CMake, `bin/sylvaris` to `$PREFIX/bin`, the shell to `$PREFIX/share/sylvaris`, the desktop files for SylFiles, SylArchive and SylNotes and their icons. It writes the short commit to `$PREFIX/share/sylvaris/COMMIT` when built from a Git checkout and `unknown` from a tarball; `sylvaris doctor` prints it.

Two more pieces are up to the package:

- **The PAM file.** SylLock checks passwords with the first PAM service of `sylvaris`, `hyprlock`, `swaylock` and `login` that exists. Install [`dist/pam/sylvaris`](../dist/pam/sylvaris) to `/etc/pam.d/sylvaris` and mark it as a config file, so it has its own.
- **The login screen.** `make install-greeter` installs SylGreet for greetd, creates `/var/lib/sylvaris-greet` owned by the greeter user and needs that user to exist. Leave it to the user (it is experimental), or ship it as a separate package.

## Dependencies

To build SylStack: CMake, a C++ compiler, pkg-config, `wayland-scanner`, and the development files for Qt 6.9 or newer (Base with its private headers, Declarative, Wayland and SVG), LayerShellQt, polkit-qt6, PipeWire, PAM and Wayland.

To run, always: Qt Declarative, Wayland, SVG, Multimedia and Image Formats, LayerShellQt, polkit-qt6, the fonts Inter and JetBrainsMono Nerd Font, bash, coreutils and procps.

Everything else is optional and only needed by the part that uses it. `sylvaris doctor` names any that are missing:

| Tool | Needed by |
|---|---|
| `pipewire` (`pw-cli`, `pw-metadata`, `pw-play`) | audio, media, the equalizer, UI sounds, Diver alarms |
| `pactl` (libpulse) | volume, output switching, recordings with sound |
| `python3` with `cryptography` | AirPods and Diver |
| `python3` with `gobject` | "Show in folder" from other apps |
| `notify-send` (libnotify) | notifications from capture, Diver and settings |
| NetworkManager (`nmcli`) | Wi-Fi and the hotspot |
| `wlr-randr` | display layouts |
| `brightnessctl` | brightness of built-in screens |
| `ddcutil` | brightness of external monitors over DDC/CI |
| `wayvnc`, `openssl`, `ip` | virtual displays for a tablet (Hyprland) |
| `wlsunset` | night light |
| `curl` | weather |
| `wl-clipboard` | clipboard history, copying screenshots |
| `grim`, `slurp`, `wf-recorder`, `ffmpeg` | SylCapture |
| `udisksctl` (udisks2) | mounting drives in SylFiles |
| `bsdtar` (libarchive) | SylArchive |
| `wtype` | replying from SylIsland |
| `gdbus` (glib) | locking when logind asks |
| `git` | installing plugins from Git |
| `kitty` | the terminal widget |
| `cava` | the visualizer widget |
| KSyntaxHighlighting QML module | colours in SylNotes |

`ddcutil` needs the `i2c-dev` module loaded and the user in the `i2c` group; say so in the package's install notes.

## Templates

| Where | Template | Status |
|---|---|---|
| AUR, stable | [`dist/aur/sylvaris/PKGBUILD`](../dist/aur/sylvaris/PKGBUILD) | run `updpkgsums` before uploading; never ship `SKIP` |
| AUR, latest commit | [`dist/aur/PKGBUILD`](../dist/aur/PKGBUILD) | `sylvaris-git` |
| Void Linux | [`dist/void/template`](../dist/void/template) | the submitter verifies it with `xbps-src` and fills in `maintainer` and `checksum` |
| nixpkgs | [`dist/nixpkgs/sylstack.nix`](../dist/nixpkgs/sylstack.nix), [`dist/nixpkgs/sylvaris.nix`](../dist/nixpkgs/sylvaris.nix) | for `pkgs/by-name/sy/`; replace `lib.fakeHash` with the real hash |

The nixpkgs files differ from the flake's `nix/package.nix` in three ways: `sylstack` comes in as an argument, the source is fetched from the release tag, and every part's tools are on `PATH` because nixpkgs has no flake inputs to pick parts with. The NixOS module in this repository, not nixpkgs, sets up PAM and the login screen.

Void has no optional dependencies, so list the optional tools above in a `README.voidlinux`. Void uses elogind, so `loginctl` suspend and shutdown work without systemd.

## Checking a package

After installing it on a Hyprland, niri or sway session:

```sh
sylvaris doctor
sylvaris
```

`doctor` prints the version, SylStack, Qt, the compositor and every missing tool. Then open SylCenter, lock the screen once and unlock it to check PAM.

Only an Arch Package Maintainer can move a package from the AUR to `[extra]`. Packaging for another distribution? Ask in [Discussions](https://github.com/fatumorg/Sylvaris/discussions) under Packaging.
