import { GLYPHS } from "./icons.mjs"

export const GROUPS = [
    { key: "system", label: "System", icon: GLYPHS.settings },
    { key: "look", label: "Look", icon: GLYPHS.palette },
    { key: "panels", label: "Panels", icon: GLYPHS.grid },
    { key: "apps", label: "Apps", icon: GLYPHS.apps },
    { key: "security", label: "Security", icon: GLYPHS.shield },
    { key: "advanced", label: "Advanced", icon: GLYPHS.code }
]

export const SECTIONS = [
    { key: "general", label: "General", glyph: GLYPHS.tune, group: "system" },
    { key: "displays", label: "Displays", glyph: GLYPHS.displays, group: "system" },
    { key: "sound", label: "Sound", glyph: GLYPHS.volume, group: "system" },
    { key: "power", label: "Power", glyph: GLYPHS.power, group: "system" },
    { key: "access", label: "Accessibility", glyph: GLYPHS.accessibility, group: "system" },
    { key: "rgb", label: "Lighting", glyph: GLYPHS.rgb, group: "system", plugin: "rgb" },
    { key: "look", label: "Style", glyph: GLYPHS.palette, group: "look" },
    { key: "appearance", label: "Appearance", glyph: GLYPHS.theme, group: "look" },
    { key: "wallpaper", label: "Wallpaper", glyph: GLYPHS.image, group: "look" },
    { key: "motion", label: "Motion", glyph: GLYPHS.bolt, group: "look" },
    { key: "sync", label: "App colours", glyph: GLYPHS.sync, group: "look" },
    { key: "bar", label: "Bar", glyph: GLYPHS.grid, group: "panels" },
    { key: "deck", label: "Deck", glyph: GLYPHS.pin, group: "panels" },
    { key: "center", label: "Control Center", glyph: GLYPHS.toggle, group: "panels" },
    { key: "island", label: "Island", glyph: GLYPHS.music, group: "panels" },
    { key: "notifications", label: "Notifications", glyph: GLYPHS.bell, group: "panels" },
    { key: "launcher", label: "Launcher", glyph: GLYPHS.apps, group: "panels" },
    { key: "switcher", label: "Switcher", glyph: GLYPHS.switcher, group: "panels" },
    { key: "clock", label: "Sky", glyph: GLYPHS.night, group: "panels" },
    { key: "weather", label: "Weather", glyph: GLYPHS.partlyCloudy, group: "panels" },
    { key: "files", label: "Files", glyph: GLYPHS.folder, group: "apps" },
    { key: "archive", label: "Archive", glyph: GLYPHS.archive, group: "apps" },
    { key: "viewer", label: "Viewer", glyph: GLYPHS.image, group: "apps" },
    { key: "capture", label: "Capture", glyph: GLYPHS.camera, group: "apps" },
    { key: "clip", label: "Clipboard", glyph: GLYPHS.clipboard, group: "apps" },
    { key: "diver", label: "Diver", glyph: GLYPHS.planner, group: "apps", plugin: "diver" },
    { key: "fatest", label: "FaTest", glyph: GLYPHS.speed, group: "apps", plugin: "fatest" },
    { key: "lock", label: "Lock", glyph: GLYPHS.lock, group: "security" },
    { key: "polkit", label: "Authentication", glyph: GLYPHS.shield, group: "security" },
    { key: "keybinds", label: "Key bindings", glyph: GLYPHS.keyboard, group: "advanced" },
    { key: "commands", label: "Commands", glyph: GLYPHS.code, group: "advanced" },
    { key: "plugins", label: "Plugins", glyph: GLYPHS.puzzle, group: "advanced" }
]

export function sectionsIn(group, plugins) {
    const on = plugins || {}
    return SECTIONS.filter(s => s.group === group && (s.plugin === undefined || on[s.plugin] === true))
}

export function groupOf(key) {
    const s = SECTIONS.find(x => x.key === key)
    return s ? s.group : ""
}

export const HUBS = [
    { key: "look", label: "Look", icon: GLYPHS.palette, tabs: ["look", "appearance", "motion", "sync"] },
    { key: "desktop", label: "Desktop", icon: GLYPHS.image, tabs: ["wallpaper", "widgets", "clock", "weather"] },
    { key: "panels", label: "Panels", icon: GLYPHS.grid, tabs: ["bar", "deck", "center", "island", "notifications", "launcher", "switcher"] },
    { key: "apps", label: "Apps", icon: GLYPHS.apps, tabs: ["files", "archive", "viewer", "capture", "clip", "notes"] },
    { key: "system", label: "System", icon: GLYPHS.settings, tabs: ["general", "displays", "sound", "power", "access", "keybinds", "commands"] },
    { key: "security", label: "Security", icon: GLYPHS.shield, tabs: ["lock", "polkit"] },
    { key: "plugins", label: "Plugins", icon: GLYPHS.puzzle, tabs: ["plugins", "diver", "fatest", "rgb", "temp"] }
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
