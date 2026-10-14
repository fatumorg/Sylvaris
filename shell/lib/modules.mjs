import { GLYPHS } from "./icons.mjs"

export const MODULES = {
    center: { label: "Control Center", section: "center", glyph: "toggle" },
    theme: { label: "Theme", section: "appearance", glyph: "theme" },
    clock: { label: "Clock", section: "clock", glyph: "night" },
    notify: { label: "Notifications", section: "notifications", glyph: "bell" },
    pad: { label: "Launcher", section: "launcher", glyph: "apps" },
    media: { label: "Media", section: "sound", glyph: "music" },
    settings: { label: "Settings", section: "general", glyph: "tune" },
    power: { label: "Power", section: "power", glyph: "power" },
    paper: { label: "Wallpaper", section: "wallpaper", glyph: "image" },
    diver: { label: "Diver", section: "diver", glyph: "planner" },
    fatest: { label: "FaTest", section: "fatest", glyph: "speed" },
    rgb: { label: "Lighting", section: "rgb", glyph: "rgb" },
    switcher: { label: "Window switcher", section: "switcher", glyph: "switcher" },
    lock: { label: "Lock screen", section: "lock", glyph: "lock" },
    polkit: { label: "Authentication", section: "polkit", glyph: "shield" },
    clip: { label: "Clipboard", section: "clip", glyph: "clipboard" },
    island: { label: "Island", section: "island", glyph: "music" },
    capture: { label: "Screenshots", section: "capture", glyph: "camera" },
    viewer: { label: "Viewer", section: "viewer", glyph: "image" },
    files: { label: "Files", section: "files", glyph: "folder" },
    archive: { label: "Archive", section: "archive", glyph: "archive" },
    access: { label: "Accessibility", section: "access", glyph: "accessibility" },
    plugins: { label: "Plugins", section: "plugins", glyph: "puzzle" },
    sync: { label: "App colours", section: "sync", glyph: "sync" }
}

export const PRODUCT = {
    bar: "SylBar", deck: "SylDeck", center: "SylCenter", theme: "SylTheme", clock: "SylClock", notify: "SylNotify",
    pad: "SylPad", media: "SylMedia", settings: "SylSettings", power: "SylPower", paper: "SylPaper", diver: "SylDiver", fatest: "FaTest", rgb: "SylRGB",
    switcher: "SylSwitch", lock: "SylLock", polkit: "SylPolkit", clip: "SylClip", island: "SylIsland", capture: "SylCapture", viewer: "SylViewer", files: "SylFiles", archive: "SylArchive", access: "SylAccessibility", plugins: "SylPlugins", sync: "SylSync"
}

export function tiles() {
    return Object.keys(MODULES).map(name => ({
        id: "sylvaris." + name,
        name: MODULES[name].label,
        genericName: "Sylvaris settings",
        keywords: ["sylvaris", "settings", name, MODULES[name].section],
        section: MODULES[name].section,
        glyph: GLYPHS[MODULES[name].glyph]
    }))
}
