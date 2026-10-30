# Installing Sylvaris

Sylvaris runs on almost any Linux distribution. On NixOS or with Home Manager, use the flake as [Nix and Home Manager](nix.md) shows. Everywhere else, find your distribution below, run its commands, then [install Sylvaris](#install-sylvaris) and [check it](#check-it). Packaging it for a distribution? [Packaging Sylvaris](packaging.md) is for you.

You need four things:

- **A Wayland compositor Sylvaris knows:** Hyprland, sway or niri. GNOME, KDE Plasma, Cinnamon, Xfce and COSMIC are not supported. On Linux Mint, Ubuntu, Pop!_OS and similar, install sway (every distribution below packages it) or Hyprland next to your desktop and pick it on the login screen. Your old desktop stays as it was.
- **Qt 6.9 or newer with its development files.** Sylvaris runs on SylStack, a small runtime that comes in this repository and that `make` builds for you. It needs Qt's Base, Declarative (Qt Quick), Wayland and SVG modules, plus LayerShellQt, polkit-qt6, PipeWire, PAM and Wayland headers. Older Qt cannot build it; [use Nix](#any-distribution-with-nix) there.
- **The fonts Inter and JetBrainsMono Nerd Font.** Without the second, every icon is an empty box.
- **A few small tools**, listed per distribution. [Which part needs which tool](#which-part-needs-which-tool) says what each is for.

## Find your distribution

Version 1.0 replaced Quickshell with SylStack, so every native route now builds SylStack from source. The package names below were checked against each distribution's package index on 27 October 2026; the routes were not yet run in clean containers the way the 0.x routes were. If a name is off, `make` stops and names the missing piece, and `sylvaris doctor` names missing tools. The Nix route was tested on NixOS.

| Distribution | Qt | Status |
|---|---|---|
| [Arch Linux](#arch-linux-and-derivatives), Manjaro, EndeavourOS, CachyOS, Garuda | 6.12 | package names checked |
| [Fedora](#fedora) 43, 44 and 45, Nobara | 6.11 | package names checked on Fedora 44 |
| [Debian testing and unstable](#debian-testing-and-unstable) | 6.11 | package names checked on testing |
| [Ubuntu 26.04](#ubuntu) and its flavours | | same packages as Debian |
| [openSUSE](#opensuse), [Void Linux](#void-linux), [Gentoo](#gentoo) | | [build SylStack](#build-sylstack) with your distribution's Qt 6 development packages |
| [Linux Mint 22, Ubuntu 24.04, Debian 13, Pop!_OS, Zorin OS, elementary OS, LMDE](#any-distribution-with-nix) | too old | Nix, tested |
| [Anything else](#any-distribution-with-nix) | | Nix, or [build SylStack](#build-sylstack) |

Linux Mint 22, Ubuntu 24.04 and everything built on them ship Qt 6.4, and Debian 13 and LMDE 7 ship Qt 6.8; both are too old for SylStack. On those, [Nix](#any-distribution-with-nix) is the way in: it brings its own Qt and never touches the rest of your system.

## Arch Linux and derivatives

```sh
sudo pacman -S --needed base-devel cmake qt6-base qt6-declarative qt6-wayland qt6-svg \
  layer-shell-qt polkit-qt6 libpipewire pam wayland inter-font ttf-jetbrains-mono-nerd \
  pipewire pipewire-pulse libpulse python-cryptography libnotify wlsunset curl \
  networkmanager wlr-randr wl-clipboard grim slurp wf-recorder ffmpeg glib2 git make
```

No compositor yet? `sudo pacman -S hyprland`, `sway` or `niri`. Manjaro, EndeavourOS, CachyOS and Garuda use the same packages.

[`dist/aur/PKGBUILD`](../dist/aur/PKGBUILD) builds a `sylvaris-git` package from the latest commit instead of `make install`: copy it into an empty folder and run `makepkg -si`. It builds SylStack and installs the shell, the `sylvaris` and `sylstack` commands and the PAM service; the login screen still needs `sudo make install-greeter` from a clone.

## Fedora

Everything comes from Fedora itself; no COPR is needed any more:

```sh
sudo dnf install cmake gcc-c++ qt6-qtbase-devel qt6-qtbase-private-devel \
  qt6-qtdeclarative-devel qt6-qtwayland-devel qt6-qtsvg layer-shell-qt-devel \
  polkit-qt6-1-devel pipewire-devel pam-devel wayland-devel rsms-inter-fonts pipewire \
  pipewire-pulseaudio pipewire-utils pulseaudio-utils python3-cryptography libnotify \
  wlsunset curl NetworkManager wlr-randr wl-clipboard grim slurp wf-recorder ffmpeg glib2 \
  procps-ng git make xz unzip
```

No compositor yet? `sudo dnf install sway`. JetBrainsMono Nerd Font is not packaged, so [install it by hand](#fonts-by-hand).

## Debian testing and unstable

```sh
sudo apt install build-essential cmake pkgconf qt6-base-dev qt6-base-private-dev \
  qt6-base-dev-tools qt6-declarative-dev qt6-declarative-private-dev qt6-wayland-dev \
  qt6-wayland-private-dev qt6-wayland qt6-svg-plugins qt6-image-formats-plugins \
  liblayershellqtinterface-dev libpolkit-qt6-1-dev libpipewire-0.3-dev libpam0g-dev \
  libwayland-dev qml6-module-qtquick qml6-module-qtqml qml6-module-qtqml-models \
  qml6-module-qtquick-window qml6-module-qtquick-effects qml6-module-qtquick-shapes \
  qml6-module-qt-labs-folderlistmodel fonts-inter pipewire pipewire-pulse \
  pulseaudio-utils python3-cryptography libnotify-bin wlsunset curl network-manager \
  wlr-randr wl-clipboard grim slurp wf-recorder ffmpeg libglib2.0-bin git make xz-utils unzip
```

No compositor yet? `sudo apt install sway`. JetBrainsMono Nerd Font is not packaged, so [install it by hand](#fonts-by-hand). Add `qml6-module-qtmultimedia` if you want SylViewer to play videos.

Debian 13 (trixie), the current stable release, has Qt 6.8, which is too old. Use [Nix](#any-distribution-with-nix) there, or wait for Debian 14.

## Ubuntu

Ubuntu 26.04, and Kubuntu, Xubuntu, Ubuntu MATE and the other 26.04 flavours, use the [Debian command](#debian-testing-and-unstable) above; no PPA is needed any more. If a package is not found, `sudo add-apt-repository universe` first.

On Ubuntu 24.04 and Linux Mint 22, use [Nix](#any-distribution-with-nix) instead.

## openSUSE

Install your release's Qt 6 development packages for Base (with the private headers), Declarative, Wayland and SVG, plus LayerShellQt, polkit-qt6, PipeWire, PAM and Wayland development packages, then [build SylStack](#build-sylstack). The runtime tools are the same as before:

```sh
sudo zypper install pipewire pipewire-pulseaudio pulseaudio-utils python3 \
  python3-cryptography libnotify-tools wlsunset curl NetworkManager wlr-randr \
  wl-clipboard grim slurp wf-recorder ffmpeg glib2-tools git make cmake gcc-c++ xz unzip
```

No compositor yet? `sudo zypper install sway`. [Install both fonts by hand](#fonts-by-hand).

## Void Linux

Install `qt6-base-devel`, `qt6-declarative-devel`, `qt6-wayland-devel` and `qt6-svg` or their current names, plus the LayerShellQt, polkit-qt6, PipeWire, PAM and Wayland development packages, then [build SylStack](#build-sylstack). The runtime tools:

```sh
sudo xbps-install -S pipewire python3-cryptography libnotify wlsunset curl \
  NetworkManager wlr-randr wl-clipboard grim slurp wf-recorder ffmpeg glib git make cmake \
  font-inter nerd-fonts-ttf
```

No compositor yet? `sudo xbps-install sway`. `nerd-fonts-ttf` holds every Nerd Font; if you prefer only the one Sylvaris uses, leave it out and [install it by hand](#fonts-by-hand). For the login screen, also install `greetd`, and enable services with `sudo ln -s /etc/sv/<name> /var/service/` instead of `systemctl`.

Without systemd, SylPower and the login screen suspend, hibernate, restart and shut down through `loginctl`, so install `elogind` and enable the `dbus` and `elogind` services. Restarting into the firmware setup still needs systemd.

## Gentoo

Emerge `dev-qt/qtbase` (with the `wayland` USE flag), `dev-qt/qtdeclarative`, `dev-qt/qtwayland`, `dev-qt/qtsvg`, `kde-plasma/layer-shell-qt`, `dev-libs/polkit-qt`, `media-video/pipewire` and `sys-libs/pam`, then [build SylStack](#build-sylstack). wlsunset, wlr-randr and Inter are in the GURU overlay:

```sh
sudo emerge --ask app-eselect/eselect-repository dev-vcs/git
sudo eselect repository enable guru
sudo emaint sync -r guru
printf '%s ~amd64\n' gui-apps/wlsunset gui-apps/wlr-randr media-fonts/inter \
  | sudo tee /etc/portage/package.accept_keywords/sylvaris
echo 'media-video/pipewire sound-server' | sudo tee /etc/portage/package.use/sylvaris
sudo emerge --ask --autounmask media-libs/libpulse dev-python/cryptography x11-libs/libnotify \
  gui-apps/wlsunset net-misc/curl net-misc/networkmanager gui-apps/wlr-randr \
  gui-apps/wl-clipboard gui-apps/grim gui-apps/slurp gui-apps/wf-recorder media-video/ffmpeg \
  dev-libs/glib media-fonts/inter app-arch/unzip dev-build/cmake
```

Use `~arm64` on ARM. No compositor yet? `sudo emerge --ask gui-wm/sway`. [Install JetBrainsMono Nerd Font by hand](#fonts-by-hand).

## Any distribution with Nix

This works on every distribution, including those whose own Qt is too old. Nix installs Sylvaris, SylStack, Qt and every tool in `/nix`, separate from the rest of your system, and removing it removes all of it.

Install Nix with the official installer. It asks for your password once:

```sh
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
```

On a distribution without systemd (Void, Alpine, Artix and others), use `--no-daemon` instead of `--daemon`. Open a new terminal, then:

```sh
nix --extra-experimental-features 'nix-command flakes' profile install github:fatumorg/Sylvaris
nix --extra-experimental-features 'nix-command flakes' profile install --impure github:nix-community/nixGL
```

[Install both fonts by hand](#fonts-by-hand), and install sway or Hyprland from your distribution if you have neither.

Three things differ from a native install:

- **Graphics.** Programs from Nix cannot load your distribution's graphics driver by themselves. nixGL, the second command above, finds the right one, so start Sylvaris through it. Your compositor may not have `~/.nix-profile/bin` on its `PATH`, so use full paths, for example in sway: `exec ~/.nix-profile/bin/nixGL ~/.nix-profile/bin/sylvaris`.
- **SylLock and the polkit agent stay off.** Both check your password through PAM, and the PAM that comes with Nix usually cannot read your distribution's passwords. A lock screen that cannot unlock is worse than none, so turn both off and keep your distribution's locker (swaylock or hyprlock) and polkit agent: `sylvaris set parts.lock false` and `sylvaris set parts.polkit false`.
- **Updating** is `nix profile upgrade --all`, and removing is `nix profile remove Sylvaris`.

Skip [install Sylvaris](#install-sylvaris) below; the Nix command already did it. Go on to [check it](#check-it).

## Install Sylvaris

```sh
git clone https://github.com/fatumorg/Sylvaris
cd Sylvaris
make
sudo make install install-pam
```

`make` builds SylStack in `build/sylstack` as your user; `sudo make install` copies it and the shell into place. This puts `sylvaris` and `sylstack` in `/usr/local/bin`, the shell in `/usr/local/share/sylvaris` and a `sylvaris` PAM service for SylLock in `/etc/pam.d` (it is left alone if one is already there). Use `make install PREFIX=~/.local` to install for your user only; SylLock then uses the `login` PAM service.

To try it without installing, run `make`, put `build/sylstack` on your `PATH` and run `bin/sylvaris` from the clone. `SYLVARIS_DIR=/path/to/shell` points the command at any other copy of the shell, which is handy for editing.

Then start it with your compositor, as [getting started](start.md#2-start-it-with-your-compositor) shows. For example in Hyprland:

```lua
hl.on("hyprland.start", function() hl.exec_cmd("sylvaris") end)
```

Remove the bar, launcher, notification daemon and other tools Sylvaris replaces from your autostart, or they will show up twice.

To update, `git pull`, then `make` and `sudo make install` again. To remove it, `sudo make uninstall`.

## Check it

```sh
sylvaris doctor
```

It works even when the shell is not running. Look at three lines:

- `SylStack:` should name the version and a Qt of 6.9 or newer.
- `Missing tools: none`. Otherwise it names each missing program and the part that wants it. Install it, or turn that part off with `sylvaris set parts.<name> false`.
- `Missing fonts: none`. Otherwise see [fonts by hand](#fonts-by-hand).

## Fonts by hand

For distributions that do not package them. This needs `curl`, `tar`, `xz` and `unzip`, which the commands above include:

```sh
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -LO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
tar -xf JetBrainsMono.tar.xz && rm JetBrainsMono.tar.xz
curl -LO https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip
unzip -o Inter-4.1.zip -d Inter && rm Inter-4.1.zip
fc-cache -f
```

Skip the Inter lines if your distribution installed `fonts-inter`, `rsms-inter-fonts` or similar. Restart Sylvaris afterwards so it sees the new fonts.

### Fonts for the styles

Each built-in style uses its own fonts: Lumen Figtree, Classic Public Sans and IBM Plex Mono, Frost Lexend and Geist Mono, Ink Geist, Neon Monaspace Krypton, Orbitron and Departure Mono, and Paper Source Serif 4, Fraunces and IBM Plex Mono. They are optional: a missing font falls back to Inter and JetBrainsMono Nerd Font. With Nix, `programs.sylvaris.fonts.enable` (on by default in both the NixOS and the Home Manager module) installs all of them; set it to `false` to keep them out. On Arch, `ttf-ibm-plex` is in the official repositories. Elsewhere, get the ones you want from their releases ([Figtree](https://github.com/erikdkennedy/figtree), [Public Sans](https://github.com/uswds/public-sans/releases), [Lexend](https://github.com/googlefonts/lexend), [Monaspace](https://github.com/githubnext/monaspace/releases), [Source Serif](https://github.com/adobe-fonts/source-serif/releases), [IBM Plex](https://github.com/IBM/plex/releases), [Geist](https://github.com/vercel/geist-font/releases), [Orbitron](https://github.com/theleagueof/orbitron), [Departure Mono](https://departuremono.com), [Fraunces](https://github.com/undercasetype/Fraunces/releases)) into `~/.local/share/fonts` and run `fc-cache -f`.

## Build SylStack

`make` in a clone builds SylStack with CMake. It needs:

- CMake 3.21 or newer, `pkg-config` and a C++20 compiler
- Qt 6.9 or newer: Base with its private headers and Wayland client, Declarative (Qt Quick, Shapes, Effects, Qt.labs.folderlistmodel), Wayland and SVG; Multimedia only for video in SylViewer
- LayerShellQt, polkit-qt6, PipeWire (`libpipewire-0.3`), PAM and `wayland-client` development files

The Wayland protocols it speaks ship inside `stack/protocols/`, so `wayland-protocols`, `wlr-protocols` and `hyprland-protocols` are not needed. If your Qt is older than 6.9, [use Nix](#any-distribution-with-nix).

## Which part needs which tool

| Tool | Needed by |
|---|---|
| `pipewire` (`pw-cli`, `pw-metadata`, `pw-play`) | bar, center, clock, diver, media, settings |
| `python3` with `cryptography` | bar, center, clock, diver, media, settings, sync |
| `notify-send` (libnotify) | bar, capture, center, clock, diver, settings |
| `pactl` | bar, capture, center, media |
| `wlsunset` | center, settings |
| `curl` | clock, settings |
| NetworkManager (`nmcli`) | center |
| `wlr-randr` | center |
| `brightnessctl` | center, for built-in screens |
| `ddcutil` | center, for external monitors over DDC/CI |
| `wayvnc`, `openssl`, `ip` | center, for a tablet as a second screen on Hyprland |
| `wl-clipboard` | center, clip, capture |
| `grim`, `slurp`, `wf-recorder`, `ffmpeg` | capture |
| `udisksctl` (udisks2) | files, to mount drives |
| `bsdtar` (libarchive) | archive |
| `wtype` | island, to send replies |
| `kitty`, `cava` | widgets, for the terminal and visualizer |
| `pgrep` (procps) | sync |
| `gdbus` (glib) | lock, only for "lock when the system asks" |
| `git` | plugins, only to install from Git |

`python3`, `notify-send` and `pw-play` serve Diver, which the bar, center, clock and settings show too; `python3` also talks to AirPods. Wi-Fi in the bar and center reads NetworkManager over D-Bus, so keep the daemon running. `ffmpeg` only tidies finished recordings so they upload everywhere. `ddcutil` needs the `i2c-dev` kernel module and your user in the `i2c` group.

## SylGreet, the login screen

> **Experimental.** Keep a second way to log in (another greeter or a text console) until you have tested it on your machine.

SylGreet runs under greetd inside sway, so it shows on every screen and looks like SylLock. It needs a native install; it does not work with the Nix route on other distributions.

```sh
sudo make install-greeter SHARE_GROUP=$(id -gn)
```

This adds `/usr/local/bin/sylvaris-greet`, its settings in `/etc/sylvaris-greet` and a state folder in `/var/lib/sylvaris-greet`. The folder is owned by the user in your greetd config (`greeter` if there is none yet; set `GREETER_USER=` to pick one), and its `shared` folder belongs to your group so your session can hand it your theme.

Point greetd at it in `/etc/greetd/config.toml`, keeping the `user` line that is already there:

```toml
[terminal]
vt = 1

[default_session]
command = "/usr/local/bin/sylvaris-greet"
user = "greeter"
```

Put sway lines for your screens and keyboard in `/etc/sylvaris-greet/sway.d/`, for example `/etc/sylvaris-greet/sway.d/outputs`:

```
output DP-1 mode 2560x1440@144Hz position 0 0
input * xkb_layout pl
```

Variables go in `/etc/sylvaris-greet/environment`, one `NAME=value` per line: `SYLVARIS_GREET_USER` and `SYLVARIS_GREET_SESSION` pick the user and session shown first, and NVIDIA cards usually want `WLR_NO_HARDWARE_CURSORS=1`.

Finally, switch display managers. On systemd, disable the one you have now (`gdm`, `sddm`, `lightdm` or another) and enable greetd:

```sh
sudo systemctl disable sddm
sudo systemctl enable greetd
```

Keep a way back before rebooting: `Ctrl+Alt+F2` gives a text console where `sudo systemctl disable greetd` and re-enabling your old display manager undo it.

SylGreet lists the sessions in `/usr/share/wayland-sessions` and `/usr/local/share/wayland-sessions`. It uses the theme you last chose in Sylvaris, which Sylvaris copies to `/var/lib/sylvaris-greet/shared/<user>` whenever you change it.

## When something is wrong

| You see | Why | What to do |
|---|---|---|
| Empty boxes instead of icons | JetBrainsMono Nerd Font is missing | [fonts by hand](#fonts-by-hand) |
| `Could not open module qs:@/qs/lib/... for reading` in the log | your Qt is older than 6.9 | [use Nix](#any-distribution-with-nix) |
| sway says `Proprietary Nvidia drivers are NOT supported` | sway's check for the NVIDIA driver | start sway with `--unsupported-gpu` |
| Nothing appears, and the log names the Qt platform plugin `wayland` | Sylvaris was started outside a Wayland session | start it from your compositor's autostart |
| A part is dim or does nothing | a tool it needs is missing | `sylvaris doctor` names it |
