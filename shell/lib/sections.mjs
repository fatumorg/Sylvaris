import { GLYPHS } from "./icons.mjs"

export const SECTIONS = [
    { key: "general", label: "General", glyph: GLYPHS.tune },
    { key: "displays", label: "Displays", glyph: GLYPHS.displays },
    { key: "sound", label: "Sound", glyph: GLYPHS.volume },
    { key: "power", label: "Power", glyph: GLYPHS.power },
    { key: "access", label: "Accessibility", glyph: GLYPHS.accessibility },
    { key: "keyboard", label: "Keyboard", glyph: GLYPHS.keyboard },
    { key: "rgb", label: "Lighting", glyph: GLYPHS.rgb, plugin: "rgb" },
    { key: "look", label: "Style", glyph: GLYPHS.palette },
    { key: "appearance", label: "Theme & colours", glyph: GLYPHS.theme },
    { key: "wallpaper", label: "Wallpaper", glyph: GLYPHS.image },
    { key: "widgets", label: "Widgets", glyph: GLYPHS.layers },
    { key: "motion", label: "Motion", glyph: GLYPHS.bolt },
    { key: "sync", label: "App colours", glyph: GLYPHS.sync },
    { key: "bar", label: "Bar", glyph: GLYPHS.grid },
    { key: "deck", label: "Deck", glyph: GLYPHS.pin },
    { key: "center", label: "Control Center", glyph: GLYPHS.toggle },
    { key: "island", label: "Island", glyph: GLYPHS.music },
    { key: "notifications", label: "Notifications", glyph: GLYPHS.bell },
    { key: "launcher", label: "Launcher", glyph: GLYPHS.apps },
    { key: "switcher", label: "Switcher", glyph: GLYPHS.switcher },
    { key: "clock", label: "Clock & sky", glyph: GLYPHS.night },
    { key: "weather", label: "Weather", glyph: GLYPHS.partlyCloudy },
    { key: "files", label: "Files", glyph: GLYPHS.folder },
    { key: "archive", label: "Archive", glyph: GLYPHS.archive },
    { key: "viewer", label: "Viewer", glyph: GLYPHS.image },
    { key: "capture", label: "Capture", glyph: GLYPHS.camera },
    { key: "clip", label: "Clipboard", glyph: GLYPHS.clipboard },
    { key: "notes", label: "Notes", glyph: GLYPHS.pencil },
    { key: "top", label: "Task manager", glyph: GLYPHS.chart },
    { key: "diver", label: "Diver", glyph: GLYPHS.planner, plugin: "diver" },
    { key: "fatest", label: "FaTest", glyph: GLYPHS.speed, plugin: "fatest" },
    { key: "temp", label: "SylTemp", glyph: GLYPHS.thermometer, plugin: "temp" },
    { key: "lock", label: "Lock", glyph: GLYPHS.lock },
    { key: "polkit", label: "Authentication", glyph: GLYPHS.shield },
    { key: "keybinds", label: "Key bindings", glyph: GLYPHS.keyboard },
    { key: "commands", label: "Commands", glyph: GLYPHS.code },
    { key: "plugins", label: "Plugins", glyph: GLYPHS.puzzle },
    { key: "about", label: "About", glyph: GLYPHS.info }
]

export const HUBS = [
    { key: "look", label: "Look", icon: GLYPHS.palette, tabs: ["look", "appearance", "wallpaper", "widgets", "motion", "sync"] },
    { key: "panels", label: "Panels", icon: GLYPHS.grid, tabs: ["bar", "deck", "center", "island", "notifications", "launcher", "switcher"] },
    { key: "apps", label: "Apps", icon: GLYPHS.apps, tabs: ["files", "archive", "viewer", "capture", "clip", "notes", "top"] },
    { key: "time", label: "Clock & weather", icon: GLYPHS.clock, tabs: ["clock", "weather"] },
    { key: "system", label: "System", icon: GLYPHS.settings, tabs: ["general", "displays", "sound", "power", "access", "keyboard"] },
    { key: "shortcuts", label: "Shortcuts", icon: GLYPHS.keyboard, tabs: ["keybinds", "commands"] },
    { key: "security", label: "Security", icon: GLYPHS.shield, tabs: ["lock", "polkit"] },
    { key: "plugins", label: "Plugins", icon: GLYPHS.puzzle, tabs: ["plugins", "diver", "fatest", "rgb", "temp"] },
    { key: "about", label: "About", icon: GLYPHS.info, tabs: ["about"] }
]

export function resolveSection(key) {
    for (const hub of HUBS) {
        if (hub.tabs.includes(key) && SECTIONS.some(s => s.key === key))
            return { hub: hub.key, tab: key }
    }
    return null
}

export function tabsIn(hub, plugins) {
    const h = HUBS.find(x => x.key === hub)
    if (h === undefined)
        return []
    const on = plugins || {}
    return h.tabs.map(k => SECTIONS.find(s => s.key === k)).filter(s => s !== undefined && (s.plugin === undefined || on[s.plugin] === true))
}
