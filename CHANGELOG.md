# Changelog

All notable changes to Sylvaris are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Entries are rebuilt from the commit history, grouped by type.

## [Unreleased]

### Added

- SylFiles: drag a bookmark up or down in the sidebar to reorder it, GTK bookmarks included
- SylFiles: places and devices in the sidebar can be dragged into a new order too, saved in `files.placeOrder` and `files.deviceOrder`
- SylFiles: `files.sections` and a "Sidebar order" setting choose the order of Places, Bookmarks and Devices
- SylFiles answers "Show in folder" from other apps over `org.freedesktop.FileManager1` (Home Manager `defaultFileManager`)
- Virtual display in SylCenter Displays: an extra screen for a tablet over VNC, with size presets and the login shown in the panel (Hyprland)

### Fixed

- Displays no longer treats a screen running a custom mode as off, so Apply keeps it on

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

[Unreleased]: https://github.com/fatumorg/Sylvaris/compare/v0.4.2...HEAD
[0.4.2]: https://github.com/fatumorg/Sylvaris/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/fatumorg/Sylvaris/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/fatumorg/Sylvaris/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/fatumorg/Sylvaris/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/fatumorg/Sylvaris/releases/tag/v0.2.0
