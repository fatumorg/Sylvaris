# Installing Sylvaris

Sylvaris runs on almost any Linux distribution. On NixOS or with Home Manager, use the flake as [Nix and Home Manager](nix.md) shows. Everywhere else, find your distribution below, run its commands, then [install Sylvaris](#install-sylvaris) and [check it](#check-it).

You need four things:

- **A Wayland compositor Sylvaris knows:** Hyprland, sway or niri. GNOME, KDE Plasma, Cinnamon, Xfce and COSMIC are not supported. On Linux Mint, Ubuntu, Pop!_OS and similar, install sway (every distribution below packages it) or Hyprland next to your desktop and pick it on the login screen. Your old desktop stays as it was.
- **Quickshell 0.3.1 or newer, built with Qt 6.9 or newer.** Older Qt can start Quickshell but cannot load Sylvaris: `sylvaris doctor` and the log then show `Could not open module qs:@/qs/lib/... for reading`.
- **The fonts Inter and JetBrainsMono Nerd Font.** Without the second, every icon is an empty box.
- **A few small tools**, listed per distribution. [Which part needs which tool](#which-part-needs-which-tool) says what each is for.

## Find your distribution

Every route marked "tested" was installed with exactly the commands on this page in a clean container on 29 September 2026, then Sylvaris was started in a headless sway and checked with `sylvaris doctor`. That catches wrong package names, missing tools and a Quickshell or Qt that is too old. It does not test your graphics card or real hardware.

| Distribution | Quickshell comes from | Status |
|---|---|---|
| [Arch Linux](#arch-linux-and-derivatives), Manjaro, EndeavourOS, CachyOS, Garuda | the official repositories | tested on Arch |
| [Fedora](#fedora) 43, 44 and 45, Nobara | a COPR | tested on Fedora 44 |
| [Debian testing and unstable](#debian-testing-and-unstable) | Debian | tested on testing |
| [Ubuntu 26.04](#ubuntu) and its flavours | a PPA | tested |
| [openSUSE](#opensuse) Tumbleweed, Slowroll, Leap 16 | the Open Build Service | tested on Tumbleweed and Leap 16.0 |
| [Void Linux](#void-linux) | the official repositories | tested |
| [Gentoo](#gentoo) | the GURU overlay | package names checked, not started |
| [Linux Mint 22, Ubuntu 24.04, Debian 13, Pop!_OS, Zorin OS, elementary OS, LMDE](#any-distribution-with-nix) | Nix | tested on Ubuntu 24.04 |
| [Anything else](#any-distribution-with-nix) | Nix, or [from source](#quickshell-from-source) | |

Linux Mint 22, Ubuntu 24.04 and everything built on them ship Qt 6.4, which is too old to build Quickshell at all. Debian 13 and LMDE 7 ship Qt 6.8, where Quickshell builds but cannot load Sylvaris. On those, [Nix](#any-distribution-with-nix) is the way in: it brings its own Qt and never touches the rest of your system.

## Arch Linux and derivatives

```sh
sudo pacman -S --needed quickshell qt6-svg socat inter-font ttf-jetbrains-mono-nerd \
  pipewire pipewire-pulse libpulse python-cryptography libnotify wlsunset curl \
  networkmanager wlr-randr wl-clipboard grim slurp wf-recorder ffmpeg glib2 git make
```

No compositor yet? `sudo pacman -S hyprland`, `sway` or `niri`. Manjaro, EndeavourOS, CachyOS and Garuda use the same packages.

[`dist/aur/PKGBUILD`](../dist/aur/PKGBUILD) builds a `sylvaris-git` package from the latest commit instead of `make install`: copy it into an empty folder and run `makepkg -si`. It installs the shell, the `sylvaris` command and the PAM service; the login screen still needs `sudo make install-greeter` from a clone.

## Fedora

Quickshell comes from a COPR, a community repository on Fedora's own build service:

```sh
sudo dnf copr enable errornointernet/quickshell
sudo dnf install quickshell qt6-qtsvg socat rsms-inter-fonts pipewire pipewire-pulseaudio \
  pipewire-utils pulseaudio-utils python3-cryptography libnotify wlsunset curl NetworkManager \
  wlr-randr wl-clipboard grim slurp wf-recorder ffmpeg glib2 procps-ng git make xz unzip
```

If `dnf copr` is an unknown command, `sudo dnf install dnf5-plugins` first. No compositor yet? `sudo dnf install sway`. JetBrainsMono Nerd Font is not packaged, so [install it by hand](#fonts-by-hand).

## Debian testing and unstable

```sh
sudo apt install quickshell qml6-module-qtquick-effects qml6-module-qtquick-shapes \
  qml6-module-qt-labs-folderlistmodel socat fonts-inter pipewire pipewire-pulse \
  pulseaudio-utils python3-cryptography libnotify-bin wlsunset curl network-manager \
  wlr-randr wl-clipboard grim slurp wf-recorder ffmpeg libglib2.0-bin git make xz-utils unzip
```

No compositor yet? `sudo apt install sway`. JetBrainsMono Nerd Font is not packaged, so [install it by hand](#fonts-by-hand).

Debian 13 (trixie), the current stable release, has Qt 6.8, which is too old. Use [Nix](#any-distribution-with-nix) there, or wait for Debian 14.

## Ubuntu

For Ubuntu 26.04, and Kubuntu, Xubuntu, Ubuntu MATE and the other 26.04 flavours. Quickshell comes from a PPA:

```sh
sudo add-apt-repository ppa:avengemedia/danklinux
sudo apt update
sudo apt install quickshell qml6-module-qtquick-effects qml6-module-qtquick-shapes \
  qml6-module-qt-labs-folderlistmodel socat fonts-inter pipewire pipewire-pulse \
  pulseaudio-utils python3-cryptography libnotify-bin wlsunset curl network-manager \
  wlr-randr wl-clipboard grim slurp wf-recorder ffmpeg libglib2.0-bin git make xz-utils unzip
```

If `add-apt-repository` is missing, `sudo apt install software-properties-common` first. No compositor yet? `sudo apt install sway`. JetBrainsMono Nerd Font is not packaged, so [install it by hand](#fonts-by-hand).

On Ubuntu 24.04 and Linux Mint 22, use [Nix](#any-distribution-with-nix) instead.

## openSUSE

Quickshell is in the `home:AvengeMedia:danklinux` repository on the Open Build Service. Add it for your release (`openSUSE_Tumbleweed`, `openSUSE_Slowroll` or `16.0`):

```sh
sudo zypper addrepo https://download.opensuse.org/repositories/home:AvengeMedia:danklinux/openSUSE_Tumbleweed/home:AvengeMedia:danklinux.repo
sudo zypper --gpg-auto-import-keys refresh
sudo zypper install quickshell socat pipewire pipewire-pulseaudio pulseaudio-utils \
  python3 python3-cryptography libnotify-tools wlsunset curl NetworkManager wlr-randr \
  wl-clipboard grim slurp wf-recorder ffmpeg glib2-tools git make xz unzip
```

No compositor yet? `sudo zypper install sway`. [Install both fonts by hand](#fonts-by-hand).

## Void Linux

```sh
sudo xbps-install -S quickshell socat pipewire python3-cryptography libnotify wlsunset curl \
  NetworkManager wlr-randr wl-clipboard grim slurp wf-recorder ffmpeg glib git make \
  font-inter nerd-fonts-ttf
```

No compositor yet? `sudo xbps-install sway`. `nerd-fonts-ttf` holds every Nerd Font; if you prefer only the one Sylvaris uses, leave it out and [install it by hand](#fonts-by-hand). For the login screen, also install `greetd`, and enable services with `sudo ln -s /etc/sv/<name> /var/service/` instead of `systemctl`.

## Gentoo

Quickshell, wlsunset, wlr-randr and Inter are in the GURU overlay and marked as testing:

```sh
sudo emerge --ask app-eselect/eselect-repository dev-vcs/git
sudo eselect repository enable guru
sudo emaint sync -r guru
printf '%s ~amd64\n' gui-apps/quickshell gui-apps/wlsunset gui-apps/wlr-randr media-fonts/inter \
  | sudo tee /etc/portage/package.accept_keywords/sylvaris
echo 'media-video/pipewire sound-server' | sudo tee /etc/portage/package.use/sylvaris
sudo emerge --ask --autounmask gui-apps/quickshell net-misc/socat media-video/pipewire \
  media-libs/libpulse dev-python/cryptography x11-libs/libnotify gui-apps/wlsunset net-misc/curl \
  net-misc/networkmanager gui-apps/wlr-randr gui-apps/wl-clipboard gui-apps/grim gui-apps/slurp \
  gui-apps/wf-recorder media-video/ffmpeg dev-libs/glib media-fonts/inter app-arch/unzip
```

Use `~arm64` on ARM. If `--autounmask` proposes USE changes (Quickshell needs `dev-qt/qtbase` with `vulkan`), accept them with `dispatch-conf` and run the last command again. No compositor yet? `sudo emerge --ask gui-wm/sway`. [Install JetBrainsMono Nerd Font by hand](#fonts-by-hand).

This route was checked against the Gentoo and GURU package lists but not built and started, because compiling Qt takes hours. If something is off, `sylvaris doctor` names what is missing.

## Any distribution with Nix

This works on every distribution, including those whose own Qt is too old. Nix installs Sylvaris, Quickshell, Qt and every tool in `/nix`, separate from the rest of your system, and removing it removes all of it.

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
sudo make install install-pam
```

This puts `sylvaris` in `/usr/local/bin`, the shell in `/usr/local/share/sylvaris` and a `sylvaris` PAM service for SylLock in `/etc/pam.d` (it is left alone if one is already there). Use `make install PREFIX=~/.local` to install for your user only; SylLock then uses the `login` PAM service.

To try it without installing, run `bin/sylvaris` from the clone. A copy in `~/.config/quickshell/sylvaris` takes priority over the installed one, which is handy for editing.

Then start it with your compositor, as [getting started](start.md#2-start-it-with-your-compositor) shows. For example in Hyprland:

```lua
hl.on("hyprland.start", function() hl.exec_cmd("sylvaris") end)
```

Remove the bar, launcher, notification daemon and other tools Sylvaris replaces from your autostart, or they will show up twice.

To update, `git pull` and run `sudo make install` again. To remove it, `sudo make uninstall`.

## Check it

```sh
sylvaris doctor
```

It works even when the shell is not running. Look at three lines:

- `Quickshell:` should say 0.3.1 or newer.
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

## Quickshell from source

For distributions not listed above. Follow [`BUILD.md`](https://git.outfoxxed.me/quickshell/quickshell/src/branch/master/BUILD.md) in the Quickshell repository. Sylvaris needs Qt 6.9 or newer with the Quick, Shapes, Effects and SVG modules, and the Wayland and Hyprland parts of Quickshell (both on by default). If your Qt is older, [use Nix](#any-distribution-with-nix).

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
| `wl-clipboard` | center, clip, capture |
| `grim`, `slurp`, `wf-recorder`, `ffmpeg` | capture |
| `pgrep` (procps) | sync |
| `gdbus` (glib) | lock, only for "lock when the system asks" |
| `git` | plugins, only to install from Git |

`python3`, `notify-send` and `pw-play` serve Diver, which the bar, center, clock and settings show too; `python3` also talks to AirPods. Wi-Fi in the bar and center reads NetworkManager over D-Bus, so keep the daemon running. `socat` makes the `sylvaris` command fast; without it commands fall back to `qs ipc`, but `sylvaris watch` needs it. `ffmpeg` only tidies finished recordings so they upload everywhere.

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

SylGreet lists the sessions in `/usr/share/wayland-sessions` and `/usr/local/share/wayland-sessions`. It uses the theme you last chose in Sylvaris, which Sylvaris copies to `/var/lib/sylvaris-greet/shared` whenever you change it.

## When something is wrong

| You see | Why | What to do |
|---|---|---|
| Empty boxes instead of icons | JetBrainsMono Nerd Font is missing | [fonts by hand](#fonts-by-hand) |
| `Could not open module qs:@/qs/lib/... for reading` in the log | your Qt is older than 6.9 | [use Nix](#any-distribution-with-nix) |
| sway says `Proprietary Nvidia drivers are NOT supported` | sway's check for the NVIDIA driver | start sway with `--unsupported-gpu` |
| Nothing appears, and the log names the Qt platform plugin `wayland` | Sylvaris was started outside a Wayland session | start it from your compositor's autostart |
| A part is dim or does nothing | a tool it needs is missing | `sylvaris doctor` names it |
