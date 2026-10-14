# Changelog

All notable changes to Sylvaris are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Entries are rebuilt from the commit history, grouped by type.

## [Unreleased]

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

[Unreleased]: https://github.com/fatumorg/Sylvaris/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/fatumorg/Sylvaris/releases/tag/v0.2.0
