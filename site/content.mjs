export const REPO = "https://github.com/fatumorg/Sylvaris"

export const NAV = [
    {
        title: "Start here",
        items: [["README.md", "Overview"], ["start.md", "Getting started"], ["install.md", "Installing without Nix"], ["nix.md", "Nix and Home Manager"]]
    },
    {
        title: "Using it",
        items: [["commands.md", "Commands"], ["configuration.md", "Configuration"], ["look.md", "Look and motion"], ["keybinds.md", "Key bindings"], ["compositors.md", "Compositors"]]
    },
    {
        title: "Parts",
        items: [["parts/README.md", "All parts"], ["parts/bar.md", "SylBar"], ["parts/center.md", "SylCenter"], ["parts/clock.md", "SylClock"], ["parts/notify.md", "SylNotify"],
            ["parts/island.md", "SylIsland"], ["parts/deck.md", "SylDeck"], ["parts/pad.md", "SylPad"], ["parts/switcher.md", "SylSwitch"], ["parts/clip.md", "SylClip"], ["parts/viewer.md", "SylViewer"], ["parts/files.md", "SylFiles"], ["parts/archive.md", "SylArchive"],
            ["parts/capture.md", "SylCapture"], ["parts/media.md", "SylMedia"], ["parts/power.md", "SylPower"], ["parts/paper.md", "SylPaper"], ["parts/widgets.md", "SylWidget"], ["parts/settings.md", "SylSettings"],
            ["parts/theme.md", "SylTheme"], ["parts/sync.md", "SylSync"], ["parts/access.md", "SylAccessibility"], ["parts/lock.md", "SylLock"], ["parts/greet.md", "SylGreet"],
            ["parts/polkit.md", "SylPolkit"]]
    },
    {
        title: "Plugins",
        items: [["plugins/README.md", "SylPlugins"], ["plugins/diver.md", "Diver"], ["plugins/airpods.md", "AirPods"], ["plugins/fatest.md", "FaTest"], ["plugins/awake.md", "Keep Awake"], ["plugins/rgb.md", "SylRGB"], ["plugins/temp.md", "SylTemp"]]
    },
    {
        title: "Reference",
        items: [["reference/settings.md", "Every setting"], ["development.md", "Working on Sylvaris"]]
    }
]

export const PARTS = [
    { id: "bar", name: "SylBar", group: "every day", page: "parts/bar.md", text: "The bar, on any edge of any screen, as floating islands or one slab. Everything in it opens right where you clicked." },
    { id: "center", name: "SylCenter", group: "every day", page: "parts/center.md", text: "Wi-Fi and Bluetooth as orbits you can pick devices from, night light, the hotspot, volume, displays and your theme, in one panel." },
    { id: "clock", name: "SylClock", group: "every day", page: "parts/clock.md", text: "Today's sky with the sun and moon where they really are, the weather for the next hours and days, and a calendar." },
    { id: "notify", name: "SylNotify", group: "every day", page: "parts/notify.md", text: "Your notification daemon: quiet toasts, a history grouped by app, and Do Not Disturb that still lets urgent things through." },
    { id: "island", name: "SylIsland", group: "every day", page: "parts/island.md", text: "A pill that shows what is going on and turns into controls: music, recordings, calls, messages, timers, all side by side." },
    { id: "deck", name: "SylDeck", group: "every day", page: "parts/deck.md", text: "A dock that can hide while windows are open, with pinned apps, running apps and a glow under the pointer." },
    { id: "pad", name: "SylPad", group: "every day", page: "parts/pad.md", text: "Your apps across the screen over a blurred wallpaper, or a compact list. Start typing to search." },
    { id: "switcher", name: "SylSwitch", group: "tools", page: "parts/switcher.md", text: "Alt+Tab that works the same on Hyprland, niri and sway, with live previews where the compositor allows." },
    { id: "viewer", name: "SylViewer", group: "tools", page: "parts/viewer.md", text: "Images and videos over the desktop. Step through the folder, play, copy, trash or make one the wallpaper." },
    { id: "files", name: "SylFiles", group: "tools", page: "parts/files.md", text: "A file manager in a real window: tabs, previews, drives that mount on click, drag and drop, rename in place, undo, and every key yours to change." },
    { id: "archive", name: "SylArchive", group: "tools", page: "parts/archive.md", text: "Zip, rar, 7z, tar and the rest, browsed like folders: open, drag out, extract, add and remove, passwords included." },
    { id: "clip", name: "SylClip", group: "tools", page: "parts/clip.md", text: "Clipboard history with search and pins. Anything a password manager marks as secret is never kept." },
    { id: "capture", name: "SylCapture", group: "tools", page: "parts/capture.md", text: "Screenshots, screen recordings that upload anywhere, and an editor with arrows, text, pixelate and crop." },
    { id: "media", name: "SylMedia", group: "tools", page: "parts/media.md", text: "The player for any MPRIS app, a 10-band equalizer for everything you hear, and the battery of every device." },
    { id: "power", name: "SylPower", group: "tools", page: "parts/power.md", text: "Lock, suspend, restart or shut down from a small constellation, with a countdown before anything ends your session." },
    { id: "paper", name: "SylPaper", group: "tools", page: "parts/paper.md", text: "Wallpapers that change with your theme, per screen if you like, with blur, dim and tint." },
    { id: "widgets", name: "SylWidget", group: "tools", page: "parts/widgets.md", text: "Clocks, weather, a calendar, photos, a live terminal and an audio visualizer right on the desktop, dragged and resized in place." },
    { id: "settings", name: "SylSettings", group: "system", page: "parts/settings.md", text: "Every setting in one place: seven hubs around a core, search that finds any option as you type, undo, and a picker for one screen at a time." },
    { id: "theme", name: "SylTheme", group: "system", page: "parts/theme.md", text: "Themes on a turning ring. The whole desktop previews a theme before you keep it." },
    { id: "sync", name: "SylSync", group: "system", page: "parts/sync.md", text: "Your theme's colours in GTK, Qt, kitty, foot, VS Code, Zed, Neovim and Firefox, every time you switch." },
    { id: "access", name: "SylAccessibility", group: "system", page: "parts/access.md", text: "Zoom, colour filters for colour-weak vision, bigger text and pointer, less motion and less transparency." },
    { id: "lock", name: "SylLock", group: "system", page: "parts/lock.md", text: "A lock screen in its own process, so a crash elsewhere can never leave your session open. Experimental." },
    { id: "greet", name: "SylGreet", group: "system", page: "parts/greet.md", text: "A login screen for greetd that always looks like your desktop. Experimental." },
    { id: "plugins", name: "SylPlugins", group: "system", page: "plugins/README.md", text: "Your own widgets, panels and helpers, plus Diver, AirPods, FaTest, Keep Awake, SylRGB and SylTemp built in." }
]

export const LEGAL = [
    { slug: "nota-prawna", lang: "pl", pair: "notice", title: "Nota prawna", short: "Nota prawna" },
    { slug: "polityka-prywatnosci", lang: "pl", pair: "privacy", title: "Polityka prywatności i cookies", short: "Prywatność" },
    { slug: "regulamin", lang: "pl", pair: "terms", title: "Zasady korzystania ze strony", short: "Zasady" },
    { slug: "legal-notice", lang: "en", pair: "notice", title: "Legal notice", short: "legal notice" },
    { slug: "privacy", lang: "en", pair: "privacy", title: "Privacy and cookies", short: "privacy" },
    { slug: "terms", lang: "en", pair: "terms", title: "Terms of use", short: "terms" }
]
