# Changelog

All notable changes to Sylvaris are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Entries are rebuilt from the commit history, grouped by type.

## [Unreleased]

### Fixed

- SylCenter's bento layout puts small tiles three to a row so labels like Performance fit, and stretches a short last row instead of leaving gaps
- The terminal widget's kitty panel fits its widget exactly; the widget's padding is kept and margins, borders and padding from your kitty.conf no longer make it spill over
- The terminal widget works as a terminal: with no command you can click it and type, clicks reach kitty instead of the widget frame, and changing its options restarts the panel
- The system widget fits its numbers (`5.5/33 GB`, `↓629 B/s`) and draws its graphs from the right edge
- The media widget's record look draws grooves instead of a music note under the centre hole when there is no cover
- Widgets inside a stack get their own options, so a stacked clock keeps its face and date, and a stacked note takes typing and saves it
- SylSettings › Desktop › Widgets can fill a stack: pick it to add widgets to it, change their options or remove them; before, a stack could only be filled by editing settings.json

## [1.5.1] - 2026-10-28

### Added

- Packaging templates for a stable AUR package, Void Linux and nixpkgs in `dist/`, and a CI job that builds the AUR package in an Arch container on every release tag
- A packaging guide for distribution maintainers, `docs/packaging.md`
- Forms for questions, desktops and Looks on GitHub Discussions, and a Community section in the README
- The site points to the community forum from every page, shares a preview image when linked, and has a press kit with descriptions, logos and screenshots

### Fixed

- The AUR git package depends on Qt Multimedia and Image Formats, and lists brightnessctl, ddcutil, wayvnc, udisks2, libarchive, wtype, kitty, cava and syntax-highlighting as optional
- A widget added from the gallery or with `sylvaris widgets add` no longer lands on top of widgets saved without a screen, and Done moves those apart too
- The visualizer widget draws with its own bar count, frame rate and smoothing, and picks up changes to them without a restart; before, any bar count but 32 left it flat

## [1.5.0] - 2026-10-28

### Added

- The bar has two more styles, `float` (one floating pill) and `minimal` (a thin line), and `bar.workspaceStyle` draws workspaces as dots, numbers, pills or app icons
- SylCenter has a bento layout, `center.layout = "bento"`: two wide tiles over small squares that slide into place
- Notifications can stack as a fanned deck of cards that spreads when you point at it (`notifications.stack = "cards"`)
- The lock screen can show the clock widget's faces: flip, analog, word, giant or digital (`lock.face`)
- SylDeck can glow in your accent under apps that have a window (`deck.glow`), and SylTheme draws each theme's card in the Look the theme was made for
- Nine more widgets: now playing (it can spin like a record), system graphs, the sky's sun path and moon, sticky notes you type into, countdowns, a shelf of apps, text in any font, stickers and FaTest
- Look shuffle picks a new Look and theme each day (`look.shuffle = "daily"`) or right now with `sylvaris look shuffle`
- Hot corners run a `sylvaris` command or start a program when the pointer rests in a screen corner, per screen or on all of them (`corners`, SylSettings › General)
- UI sounds play a short sound from a folder you pick for toggles, panels and notifications (`sounds`, SylSettings › Sound)

### Changed

- Lumen, the default Look, now floats the bar with dot workspaces, lays SylCenter out as bento, stacks notifications as cards, shows the giant lock clock, glows under open apps on SylDeck and morphs windows open; Classic keeps the 1.1 layout
- The demo recordings in the README and on the site show 1.5, with new ones for SylWidget and SylTemp

### Fixed

- Photo widgets tinted or turned mono stay visible when Sylvaris draws without a GPU
- The install guide lists the tools for brightness, tablets, drives, archives, replies and the terminal and visualizer widgets

## [1.4.0] - 2026-10-28

### Added

- SylWidget puts clocks, weather, a calendar, Diver, batteries, photos, a live terminal, an audio visualizer and stacks of them on the desktop; `sylvaris widgets edit` lets you drag, resize, add and remove them in place, and SylSettings › Desktop › Widgets tunes each one
- Right-click the wallpaper for a desktop menu with widgets, wallpapers, your Look and SylSettings, or open it with `sylvaris paper menu`
- SylTemp, a built-in plugin, shows every temperature from TempInfoCLI in a panel with history and peaks, a click-through overlay for games, a bar chip and a desktop widget, and warns when something runs hot (`sylvaris temp`)
- SylFiles opens more than one window: Ctrl+N, right-click a folder › Open in a new window, or `sylvaris files window`; cut in one window and paste in another
- SylNotes, a small text and code editor with tabs: it keeps line endings and the final newline as they were, saves in one step, opens binary and non-UTF-8 files read-only, and brings back unsaved typing after a crash (`sylvaris notes open`, `programs.sylvaris.defaultTextEditor`)
- SylNotes finds and replaces (match case, whole word, regex), jumps to a line with Ctrl+G, zooms with Ctrl+= and Ctrl+-, opens files you drop on it, and colours code in more than 300 languages with the colours of your theme; click the language in the status bar to pick another

## [1.3.0] - 2026-10-28

### Added

- SylSettings opens on seven hubs (Look, Desktop, Panels, Apps, System, Security and Plugins) with a tab per section, and a search pill finds any setting as you type, with switches you can flip right in the results
- Simple and full detail (`settings.detail`): options most people never touch wait behind a more options row until you ask for them
- Changed settings carry a dot that resets them, every change can be undone from a toast or with Ctrl+Z, and `sylvaris settings reset`, `undo`, `search` and `state` do the same from a script
- Wallpaper fit, blur, dim, tint and parallax in SylSettings › Desktop › Wallpaper
- Look › Style shows a live sample of your Look and tries any other Look on it while you point at it

## [1.2.0] - 2026-10-28

### Added

- Looks: `look.preset` picks a whole style (Lumen, the new default, plus Classic for the 1.1 look, Frost, Ink, Neon and Paper), and keys under `look` override its material, corners, radius, density, fonts, weight, shadow, grain, highlight, glow, accent and per-part material
- Corner radii, spacing, fonts and title weight in every part, the lock screen and the login screen follow the active Look
- Glass gains grain, a top highlight, an inner glow and card shadows, squircle and bevelled panel corners, and per-part materials through `look.parts`
- `sylvaris look` lists, switches, saves, exports and imports Looks; saved Looks live in `~/.config/sylvaris/looks`, and with `look.followTheme` a theme's `look` key switches the Look with it
- `sylvaris theme generate` makes a readable theme from the wallpaper's colours, and `look.accent` can follow the wallpaper or take any colour
- Six ways for panels to open (`motion.open`: grow, morph out of the clicked button, drop, unfold, focus and swing), plus `motion.stagger` and `motion.springiness`, all in SylSettings › Motion
- Clock digits roll when they change, tiles and row buttons squash on press and lift on hover, switches ripple from the click and sliders show a grip while dragged
- An aurora of slow accent lights behind full-screen parts (`look.aurora`), and the wallpaper sways a little when you switch workspace (`paper.parallax`)
- SylSettings › Style: Look cards with live glass, material, corners, roundness, spacing, layers, title weight, a font finder and saving your own Look
- Brightness sliders in SylCenter's displays view for laptop backlights (brightnessctl) and external monitors over DDC/CI (ddcutil), plus `sylvaris brightness up`, `down`, `set` and `state`

## [1.1.0] - 2026-10-27

### Added

- SylCenter's sound output view works like pavucontrol: apps that record show under Recording, each row shows the stream's title, clicking the output beside a slider moves that app to the next output or microphone, and apps that stop stay listed with their last volume

### Fixed

- The equalizer was silent when WirePlumber had once saved its output stream as muted; its output stream no longer saves or restores volume
- With the equalizer on and no output picked yet, SylCenter marks the output it actually plays to
- SylRGB picks up devices plugged in after OpenRGB started, such as an Aerox 3 on its cable, by asking OpenRGB to rescan
- The Aerox 3's own click colour from SteelSeries GG no longer takes over SylRGB's press flash
- SylRGB keeps watching for new devices when OpenRGB drops its connection during a rescan, so a mouse that reconnects twice while plugging in is still found
- The click flash stopped for good after lights were turned off, a press colour was cleared or OpenRGB went away for a moment
- The virtual display's VNC password is 128 bits; a config Sylvaris made earlier with an 8-character password gets a new one (check the password in SylCenter before reconnecting)
- Weather requests round your coordinates to two decimals (about 1 km) instead of three

### Security

- Each user now shares their login look in their own folder under `/var/lib/sylvaris-greet/shared`, which is now sticky (1775): another member of the share group could plant links there that made your Sylvaris overwrite your files, or change everyone's login screen. SylGreet shows the look of the user it has selected, only from a folder that user owns; after upgrading, log in once to share yours again. Without Nix, run `sudo make install-greeter` again to make the folder sticky: Sylvaris does not share into one that is not
- Theme `links` are no longer made while you only preview a theme in the picker, and switching to a theme without a link removes the one an earlier theme made and restores your backup
- Notifications pushed out of the history by `notifications.history` are now closed, so their apps hear about it and their images no longer stay in memory
- `sylvaris doctor` names the PAM service the lock uses and, when it falls back to `login` (whose failed-attempt lockout can shut you out), how to install the `sylvaris` one
- An island reply to a chat without its own reply box is typed only once that app's window is in front; otherwise it is copied to the clipboard and a notification says so, instead of being typed and sent into whatever window had focus

## [1.0.1] - 2026-10-27

### Fixed

- SylLock no longer crashes when you unlock, which left Hyprland showing "lockscreen app died" and sway a red screen
- SylLock covers every monitor: with more than one, every lock screen opened on the monitor under the pointer and the others stayed uncovered (sway refused the lock outright)

### Changed

- SylPolkit's page explains why `pkexec` can finish without a prompt and how to try a real request

## [1.0.0] - 2026-10-27

The first official release, out of beta.

### Added

- SylStack, the small Qt Quick runtime Sylvaris now runs on, in `stack/`: windows and layer shell, session lock, PAM, polkit, greetd, notifications, tray, MPRIS, PipeWire, UPower, NetworkManager, BlueZ, compositor IPC and window previews in one 2.3 MB binary
- SylFiles: drag a bookmark up or down in the sidebar to reorder it, GTK bookmarks included
- SylFiles: places and devices in the sidebar can be dragged into a new order too, saved in `files.placeOrder` and `files.deviceOrder`
- SylFiles: `files.sections` and a "Sidebar order" setting choose the order of Places, Bookmarks and Devices
- SylFiles answers "Show in folder" from other apps over `org.freedesktop.FileManager1` (Home Manager `defaultFileManager`)
- Virtual display in SylCenter Displays: an extra screen for a tablet over VNC, with size presets and the login shown in the panel (Hyprland)
- Keep Awake, a built-in plugin with a SylCenter tile and `sylvaris awake` that keeps the screen from dimming, locking or sleeping through the idle-inhibit protocol
- A notification when the laptop battery runs down to 15% and again at 5%, while it is discharging

### Changed

- Sylvaris runs on SylStack instead of Quickshell. Quickshell and `socat` are no longer needed: the Nix package brings SylStack along, and `make` builds it everywhere else
- `sylvaris` talks to the shell with `sylstack msg`; when the shell is not running, commands say so instead of falling back to `qs ipc`
- Sylvaris windows report the app id `sylvaris` instead of `org.quickshell`; window rules that match the old id need the new one
- A copy of the shell in `~/.config/quickshell/sylvaris` is no longer picked up; set `SYLVARIS_DIR` to run another copy
- Install routes build SylStack from source, so Fedora and Ubuntu no longer need a COPR or PPA
- The Nix examples add `inputs.sylvaris.inputs.nixpkgs.follows`, which SylLock needs to load your system's PAM modules
- Closed panels and popups free their window at once, and SylStack hands unused memory back to the system after a panel unloads, so Sylvaris now uses less memory and CPU than it did on Quickshell; the README has the new numbers

### Fixed

- Displays no longer treats a screen running a custom mode as off, so Apply keeps it on
- SylLock says the PAM service is broken when its modules cannot load, instead of calling every password wrong
- SylRGB's popup state no longer clashes with its shared colour, so `sylvaris rgb` reports `open` correctly and the device list refreshes after each change while the popup is open
- Extracting chosen items from an archive passes their names to bsdtar after `--`, so an entry named like an option can no longer change what bsdtar does or run a program
- Notifications show icons only from local files and icon names; a web address sent as the icon is ignored instead of fetched
- The polkit agent stops instead of retrying in a loop when PAM fails without asking for a password, for example while the account is locked out
- SylLock shows PAM's own reason, such as a locked account, instead of "Wrong password"
- Theme `links` no longer delete a real file or folder of yours at the target path: it is moved to `<name>.before-sylvaris` first, or left alone and reported if that backup already exists
- `make install` puts the SylFiles, SylViewer and SylArchive desktop entries and icons in place, so "Open with" and default apps work outside Nix too
- The shell ships a hidden `sylvaris.desktop`, so the desktop portal recognises its app id instead of logging a warning at start
- On Hyprland, requests sent while the shell is still loading are no longer dropped, so a Lua config is recognised and early window commands go through
- Helpers the shell starts, such as a running screen recording, stop when the shell is killed or crashes instead of being left behind
- `sylvaris` sends commands to the shell on standard input, so a Diver pairing code or a reply typed into `sylvaris island reply` no longer shows up in the process list

## [0.4.2] - 2026-10-20

### Fixed

- SylCenter and every panel fit short screens and scroll instead of running off the bottom
- The bar's middle group slides aside or hides instead of overlapping the side groups
- SylSettings drops its side columns on narrow screens so pages keep their full width
- SylPad shows as many full rows as fit and pages the rest
- SylSwitch keeps its cards inside the panel when they do not all fit
- Suspend, hibernate, restart and shut down fall back to `loginctl` on systems without systemd, such as Void Linux with elogind

## [0.4.1] - 2026-10-20

### Changed

- Auto performance mode only pauses ambient movement and keeps the look; dropping blur and sheen is left to `on`

### Fixed

- Night light shows as unavailable on Hyprland without wlsunset again
- The bar's glow no longer flickers when a full-screen window on another screen gains or loses focus

## [0.4.0] - 2026-10-20

### Added

- Add motion styles: calm, smooth, snappy and playful, picked in SylSettings › Motion or with `motion.preset`
- Add an auto performance mode, now the default: Sylvaris goes lite while a full-screen window such as a game has focus and comes back when it leaves

### Changed

- `performance` takes `off`, `auto` or `on` instead of `true` or `false`; an old `true` reads as `on` and an old `false` as `auto`, but the Home Manager option `programs.sylvaris.performance` now wants one of the strings
- Only `on` trims the compositor; the SylCenter Performance tile switches between `on` and `auto`
- The recording dot stops pulsing in lite mode
- Every animation, including hovers, pulses and spinners, follows the motion style and speed; loops keep a steady pace with Reduce motion on

### Fixed

- Night light reaches mirrored monitors on Hyprland, such as a TV mirroring a desktop screen

## [0.3.0] - 2026-10-20

### Added

- Add SylIsland, an opt-in dynamic island for media, recordings, Diver and alerts, on every screen
- Show messages and calls from Discord, Signal, Telegram, WhatsApp and more in the island, and reply to web chats from it
- Show the voice chat you are in with a mic mute, and keep the island over full-screen apps during calls
- Show privacy mode, apps using the microphone or camera, and status changes in the island
- Add island rows per activity, shortcuts, position and idle modes, an edge tuck that opens on hover, and hidden sites
- Keep paused music in the island so it can be resumed from there
- Grow panels out of the island and dock them under it while it stays visible
- Add a privacy action that mutes every microphone and switches cameras off
- Add SylFiles, a file manager window with tabs, previews, undo, drives, mounting, unlocking and ejecting
- Ask to merge, replace, skip, keep both or rename on every name clash in SylFiles
- Open and save files for every app through the desktop portal with SylFiles
- Add SylArchive, an archive window that lists, extracts, packs and edits anything libarchive reads, with compress and extract in SylFiles
- Add SylViewer for images and videos over the desktop
- Add SylRGB, lighting for every OpenRGB device as a built-in plugin, with vivid theme colours, a theme's own LED colour, a click flash and an OpenRGB restart
- Set volume and mute per app in the sound output view
- Add per-screen settings for the bar, dock, panel spots, island and wallpaper look
- Pick where media, clipboard, capture, accessibility, Diver and FaTest open
- Sort settings into system, look, panels, apps, security and advanced
- Report missing fonts in sylvaris doctor
- Add a static website with the docs, a live model of the shell and a page for every part, plugin, command and Nix option
- Add tested install steps for every major distribution

### Changed

- Bring the Diver planner up to date with the web app
- Remove the grain from every surface
- Keep island alerts up longer
- Point every link at the fatumorg organization

### Fixed

- Make recordings uploadable with standard colour range, a 60 fps cap, faststart and file copy
- Keep panels opened from the island clickable across their whole area, and the island clickable while a panel is docked under it
- Hand out island blur only while the island is on screen
- Name the real app on the microphone and keep one call timer per app in the island
- Never trap the keyboard in an island reply when its message goes away
- Make room in the island and toasts for every placed panel, not only five
- Make app volume sliders follow drags and show clean names for ALSA apps
- Use a device's static mode at full brightness for plain lighting colours
- Keep SylFiles prompts from staying on screen when closed mid-fade, keep Enter in the prompt and hand the keys back to the folder on close
- Keep tab listings and path checks right when several SylFiles tabs show the same folder
- Stop SylFiles and SylArchive from closing inside their own handlers, and ignore unpacked copies dropped back on an archive
- Write the keybinds file atomically so the compositor never reloads half of it
- Write theme sync atomically through symlinks and skip Nix-managed files
- Restart the clipboard, logind and niri watchers when they exit
- Keep constellation labels readable while a settings page is open, and show power action chips in menu order
- Teach doctor and the Home Manager schema about wtype and island seconds
- Point the PKGBUILD and demo text at ifatum/Sylvaris
- Mark every script executable so a fresh clone runs the CLI, helpers and tests

### Security

- Show outside text as plain text so titles and names cannot load remote images
- Ignore prototype keys when merging settings
- Keep clipboard history, images and the weather cache private
- Never send the lock password to PAM without a user name

## [0.2.0] - 2026-09-28

### Added

- Add a glass menu with the app's own actions when right-clicking a tray icon
- Show Connecting, Pairing and Disconnecting for Bluetooth and Wi-Fi, and Pairing, Syncing and Saving in Diver and FaTest
- Add sylvaris version, and bluetooth and wifi connect and disconnect actions
- Add optional SylCenter tiles: speed test, AirPods, screenshot, record, clipboard and lock
- Add a Control Center page to SylSettings: tiles, volume slider, now playing card, corner and hotspot
- Add a Show seconds option to the lock screen clock
- Add FaTest, a built-in plugin that runs FaTest speed tests and shares its history
- Ship Diver and AirPods as built-in plugins that stay off until turned on
- Scaffold Sylvaris flake, launcher and headless harness
- Add config and settings validation logic
- Add theme validation and color tokens
- Add orbit geometry and icon mapping
- Add display layout, audio profile and calendar logic
- Add tokens, demo data, config, settings and theme services
- Add compositor adapter with focused screen fallback
- Add audio, media, night light, dnd and toggle services
- Add bluetooth, wifi and hotspot services
- Add displays service with auto-revert and saved layouts
- Add SylvarisCC window with the compact view
- Add the Wi-Fi and Bluetooth orbit view
- Add calendar, sound output and hotspot views
- Add the displays view with auto-revert
- Add Home Manager module and README
- Resolve Resin Glass values from config and settings
- Add the theme catalog, the pane token and a serialized theme hook
- Add the Resin service and the Glass component
- Move every Sylvaris surface onto Resin Glass
- Add the theme preview state machine
- Add the ThemePreview service
- Add SylvarisTP, the theme picker with live preview
- Slide SylvarisTP in and out, cover the bar, smooth corners, auto-hide the cursor and bring it to life
- Slower staggered SylvarisTP reveal over the plain wallpaper and vector-smooth photo corners
- Glue the media art to the card edge with the card's own corners
- Add SylIPC, one command surface for every part over CLI, IPC and a socket
- Add SylClock with a live sky of the real sun and moon paths
- Add SylNotify, the notification daemon with toasts and a notification center
- Add SylPad, a full-screen paged app launcher
- Add SylCompositor, one command set and state model for Hyprland, niri and sway
- Add SylBar and the optional SylDeck
- Add SylMedia with playback, an equalizer, spatial audio and AirPods controls
- Add SylSettings and let config.json declare every setting as a default
- Add SylPower and a search to SylTheme
- Add SylPaper, a wallpaper layer that follows the theme
- Add weather and constellation settings
- Rebuild SylSettings around a constellation with statistics and about
- Show the weather in SylClock
- Add SylDiver and wire Diver plans into the calendars, reminders and alarms
- Let every part be excluded, with only its own tools and services loaded
- Open each part's settings from SylPad through a shared module registry
- Apply theme links without a hook and stop a stuck hook from blocking theme changes
- Understand Diver repeat rules and add repeating plans from sylvaris diver add
- Full Diver planner in SylDiver with today, calendar, lists, a task sheet, focus sessions and IPC
- Open SylDiver from the day plans in SylClock and SylCenter
- Keep Diver phone reminders in step with plans made in Sylvaris
- Understand now and teraz in diver quick capture
- SylDeck hides with windows, shows a peek line and slides without flicker
- SylSwitch, an Alt+Tab window switcher with recent-first order and live previews
- SylLock, a PAM lock screen on the session lock protocol
- SylPolkit, a polkit agent with the Sylvaris password prompt
- SylGreet, a greetd login screen in the lock screen's style, with a NixOS module
- SylClip, a searchable clipboard history with pins and images
- SylCapture for area, window and screen shots and screen recording
- SylAccessibility with zoom, colour filters, text and pointer size
- Home Manager option for every setting, generated from the shell's defaults
- Key bindings for Sylvaris actions, set in SylSettings or config and applied live on Hyprland and sway
- Live previews in SylSettings for placement, glass, bar, deck, launcher, notifications, motion, wallpaper and power
- SylPlugins for bar widgets, panels and background services, with an example
- SylSync matches GTK, Qt, terminals, editors and browsers to the theme
- Workspace icon sets in SylBar, from dots to paws, chosen per theme or everywhere
- Recolour VS Code live through settings.json and find Firefox profiles under XDG config
- Build the compositor side of performance mode into Sylvaris with a SylCenter tile
- Add a session menu to SylGreet and let NixOS hand it the sessions, theme and avatar
- Add sylvaris pick, a dmenu-style chooser in SylPad, and greeter environment variables
- Minimize the focused app by clicking its title on SylBar and bring it back with a second click
- Sync key bindings with the compositor config both ways
- Install on any distribution with make, with guides per distribution
- Add a clear button to key binding pills
- Add sylvaris doctor for bug reports
- Version config and settings files and migrate them step by step
- Keep compositor capabilities in one table and document it
- Add a screenshot editor and many capture and recording options

### Changed

- Rename SylvarisCC to SylCenter and SylvarisTP to SylTheme
- Drop the quick-add boxes in SylDiver and keep Details
- Build panel windows only while open and free them 20 s after closing
- Split SylSettings into Settings, Apps and Features tabs and give key bindings their own page
- Redesign workspace pills: the current one shows its apps, the rest their number and window ticks
- Recolour every VS Code profile and theme far more of Firefox, including its own pages
- Mirror SylLock and SylGreet on every screen, run SylGreet in sway and let it follow the last used theme
- Center icon-only buttons and workspace numbers, tint app icons with the theme and pass GPU variables to headless runs
- Move each SylSettings page into its own file

### Fixed

- Stop an endless Hyprland config reload loop that kept the shell and Hyprland busy on Lua configs
- Stop redrawing glass while the pointer rests on it
- Stop a startup crash when app icons loaded in the background
- Show Deck, bar and notification app icons as soon as desktop entries load
- Start the hotspot with Wi-Fi off, apply its name and band, and fall back to 2.4 GHz when 5 GHz is not allowed
- Start a recording asked for while the previous one is still saving
- Let the shell start again after the FaTest rename
- Draw glass grain over the whole shape of round surfaces instead of a square inside them
- Tint workspace app icons like the rest on a contrasting badge, and centre each number over its window dots
- Center workspace pills and their window dots, and drop closed Hyprland windows from them
- Address final review findings
- Open SylvarisCC on the focused output right after startup
- Pause the orbit under the pointer and tell apart close refresh rates
- Let clicks outside SylvarisCC close it on Hyprland
- Smooth shapes and avatar edges, center icon glyphs, animate state changes
- Move the Resin Glass sheen as an item so it repaints
- Show the back card of the SylvarisTP ring and fill the blurred backdrop to the edges
- Cancel SylvarisTP on backdrop taps and step the carousel per wheel notch
- Shape the niri blur to the panel instead of the whole layer surface
- Keep music playing while the equalizer changes and smooth out the whole shell
- Keep blur edges tucked under the glass rim
- Show SylDiver when a timed plan starts and ring only for alarms
- Show the alarm that is ringing when two reminders fire together
- Spread full-screen backgrounds from the edges or the center instead of fading a zoomed copy
- Open popups next to the bar wherever it sits
- Steady workspace pills and window title in SylBar and a real clock on vertical bars
- Move toasts beside an open panel in the same corner
- Center the chevron icons and icon-only row buttons
- Focus a popup's input once its window exists
- Name every part properly in the Parts card
- Only count the stored performance toggle when a custom one exists
- Give slurp an empty stdin so area capture does not hang
- Keep cryptography in the dev shell python next to vncdotool
- Keep key capture running while the settings window is not focused
- Cancel recordings stopped early, never overwrite captures, keep editor keys working

### Security

- Keep the Diver pairing code off the command line, refuse lookalike localhost addresses and never follow redirects
- Escape stray markup in notification bodies and open only web links from them
- Refuse IPC and settings keys that reach the JavaScript prototype, and unknown setting keys
- Keep the IPC socket folder and clipboard images private to the user
- Clear the typed password on submit and when locking
- Run SylLock in its own process so a shell crash cannot drop the lock
- Empty the password field as soon as it is submitted
- Show the commit and a permissions warning before installing a plugin
- Relock a lock screen that is still closing and report locks that fail
- Never prompt or hang on plugin clones and unfreeze settings once the file is gone

[Unreleased]: https://github.com/fatumorg/Sylvaris/compare/v1.5.1...HEAD
[1.5.1]: https://github.com/fatumorg/Sylvaris/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/fatumorg/Sylvaris/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/fatumorg/Sylvaris/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/fatumorg/Sylvaris/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/fatumorg/Sylvaris/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/fatumorg/Sylvaris/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/fatumorg/Sylvaris/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/fatumorg/Sylvaris/compare/v0.4.2...v1.0.0
[0.4.2]: https://github.com/fatumorg/Sylvaris/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/fatumorg/Sylvaris/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/fatumorg/Sylvaris/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/fatumorg/Sylvaris/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/fatumorg/Sylvaris/releases/tag/v0.2.0
