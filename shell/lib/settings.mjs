import { DEFAULT_LOCK, validateLock } from "./lock.mjs"
import { DEFAULT_CLIP, validateClip } from "./clip.mjs"
import { DEFAULT_ISLAND, validateIsland } from "./island.mjs"
import { DEFAULT_VIEWER, validateViewer } from "./viewer.mjs"
import { DEFAULT_FILES, validateFiles } from "./files.mjs"
import { DEFAULT_WIDGETS, validateWidgets, servicesFor } from "./widgets.mjs"
import { DEFAULT_CORNERS, validateCorners } from "./corners.mjs"
import { DEFAULT_ARCHIVE, validateArchive } from "./archive.mjs"
import { DEFAULT_NOTES, validateNotes } from "./notes.mjs"
import { DEFAULT_CAPTURE, validateCapture } from "./capture.mjs"
import { DEFAULT_ACCESS, validateAccess } from "./access.mjs"
import { EXTRAS, LAYOUTS } from "./center.mjs"
import { validateKeybinds } from "./keys.mjs"
import { DEFAULT_PLUGINS, validatePlugins, BUILTIN, builtinOn } from "./plugins.mjs"
import { DEFAULT_SYNC, validateSync } from "./sync.mjs"
import { PRESETS, OPEN_STYLES } from "./motion.mjs"
import { DEFAULT_BAR, DEFAULT_DECK, validateBar, validateDeck } from "./bar.mjs"
import { DEFAULT_EQ, validateEq } from "./eq.mjs"
import { DEFAULT_POWER, validatePower } from "./power.mjs"
import { DEFAULT_PAPER, validatePaper } from "./paper.mjs"
import { DEFAULT_WEATHER, validateWeather } from "./weather.mjs"
import { DEFAULT_RGB, validateRgb } from "./rgb.mjs"
import { DEFAULT_TEMP, validateTemp } from "./temp.mjs"
import { DEFAULT_LOOK, validateLook, lookDefaults } from "./look.mjs"

export const CORNERS = ["top-left", "top-center", "top-right"]
export const REVEALS = ["edges", "center", "fade"]
export const PERFORMANCE = ["off", "auto", "on"]
export const PLACES = CORNERS.concat("center")
export const DEFAULT_PLACEMENT = { media: "auto", clip: "top-center", capture: "top-center", access: "top-center", diver: "center", fatest: "top-right", rgb: "top-right", temp: "top-right" }
export const CENTER_TILES = ["wifi", "bluetooth", "night", "dnd", "hotspot"]

export const PARTS = {
    bar: ["Apps", "Audio", "Battery", "BluetoothService", "NetworkService", "Diver", "Dnd", "Media", "Notifications", "Plugins"],
    center: ["Audio", "Awake", "BluetoothService", "NetworkService", "Hotspot", "Displays", "Brightness", "VirtualDisplay", "NightLight", "Diver", "Dnd", "Toggles", "Media", "Headphones"],
    clock: ["Diver", "Weather", "Sky"],
    deck: ["Apps"],
    diver: ["Diver"],
    fatest: [],
    rgb: [],
    temp: ["Temps"],
    media: ["Headphones", "Equalizer", "Media"],
    notify: ["Apps", "Battery", "Dnd", "Notifications"],
    pad: ["Apps"],
    paper: [],
    power: [],
    lock: [],
    polkit: [],
    clip: [],
    island: ["Media", "Audio", "Notifications", "BluetoothService", "Diver", "NetworkService", "NightLight", "Dnd", "Apps"],
    capture: [],
    viewer: [],
    files: [],
    widgets: [],
    archive: [],
    notes: [],
    access: ["NightLight"],
    plugins: ["Plugins"],
    sync: ["Sync"],
    switcher: ["Apps"],
    settings: ["Audio", "Equalizer", "NightLight", "VirtualDisplay", "Diver", "Weather", "Sky", "Dnd", "Apps", "Notifications", "Plugins", "Sync", "Media"],
    theme: ["ThemePreview"]
}

export const SERVICE_DEPS = {
    Audio: ["Equalizer"],
    Headphones: ["BluetoothService"],
    Hotspot: ["NetworkService"],
    VirtualDisplay: ["Displays"],
    Brightness: ["Displays"],
    Dnd: ["Notifications"],
    Weather: ["Sky"]
}

export const OPT_IN = ["island"]

function partOn(parts, name) {
    return OPT_IN.includes(name) ? parts[name] === true : parts[name] !== false
}

function partFlags(parts) {
    const out = {}
    for (const name of Object.keys(PARTS))
        out[name] = partOn(parts, name)
    return out
}

export const CONFIG_VERSION = 1
export const SETTINGS_VERSION = 1

export const DEFAULT_CONFIG = {
    version: CONFIG_VERSION,
    themesDir: "~/.config/sylvaris/themes",
    themeHook: "",
    themeStateFile: "~/.local/state/sylvaris/theme",
    avatar: "~/.face",
    lockCommand: "loginctl lock-session",
    terminal: "kitty",
    greeterShare: "/var/lib/sylvaris-greet/shared",
    toggles: [],
    commands: [],
    notifications: { server: true, history: 100 }
}

export const DEFAULT_SETTINGS = {
    version: SETTINGS_VERSION,
    center: { corner: "top-right", hidden: [], extra: [], volume: true, media: true, layout: "grid" },
    clock: { corner: "top-center" },
    nightLight: { enabled: false, temperature: 4000 },
    displays: { layouts: {}, virtual: { enabled: false, width: 2388, height: 1668 } },
    toggleState: {},
    hotspot: { ssid: "Sylvaris", band: "bg" },
    notifications: { dnd: false, timeout: 5000, corner: "top-right", stack: "list" },
    pad: { columns: 7, rows: 5, mode: "launchpad" },
    bar: DEFAULT_BAR,
    deck: DEFAULT_DECK,
    media: { eq: DEFAULT_EQ, airpods: "" },
    motion: { scale: 1, reduced: false, reveal: "edges", preset: "smooth", open: "grow", stagger: 0.35, springiness: -1 },
    power: DEFAULT_POWER,
    paper: DEFAULT_PAPER,
    weather: DEFAULT_WEATHER,
    diver: { enabled: true, refresh: 2, notify: true, alarms: true, sound: true, calendar: true },
    constellation: { speed: 1, links: true, ring: true, labels: true, stars: true },
    settings: { detail: "simple" },
    switcher: { previews: true, titles: true },
    lock: DEFAULT_LOCK,
    clip: DEFAULT_CLIP,
    island: DEFAULT_ISLAND,
    viewer: DEFAULT_VIEWER,
    files: DEFAULT_FILES,
    widgets: DEFAULT_WIDGETS,
    archive: DEFAULT_ARCHIVE,
    notes: DEFAULT_NOTES,
    rgb: DEFAULT_RGB,
    temp: DEFAULT_TEMP,
    placement: DEFAULT_PLACEMENT,
    screens: {},
    capture: DEFAULT_CAPTURE,
    access: DEFAULT_ACCESS,
    keybinds: {},
    plugins: DEFAULT_PLUGINS,
    sync: DEFAULT_SYNC,
    corners: DEFAULT_CORNERS,
    sounds: { enabled: false, pack: "", volume: 0.5 },
    performance: "auto",
    iconTint: true,
    look: DEFAULT_LOOK,
    parts: partFlags({})
}

export const DEFAULT_GLASS = { enabled: true, opacity: 0.55, layerOpacity: 0.35, tint: 0.14, sheen: 0.35, flow: 1, rim: 0.5 }

const GLASS_RANGES = { opacity: [0, 1], layerOpacity: [0, 1], tint: [0, 1], sheen: [0, 1], flow: [0, 3], rim: [0, 1] }

const TOGGLE_ID = /^[a-z0-9_-]+$/
const STRING_KEYS = ["themesDir", "themeHook", "themeStateFile", "avatar", "lockCommand", "terminal", "greeterShare"]
const DEFAULT_TOGGLE_ICON = String.fromCodePoint(0xF0521)

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function clone(v) {
    return v === undefined ? undefined : JSON.parse(JSON.stringify(v))
}

function intIn(v, lo, hi, fallback) {
    return Number.isInteger(v) && v >= lo && v <= hi ? v : fallback
}

function str(v, fallback) {
    return typeof v === "string" ? v : fallback
}

export function parseJson(text) {
    if (text === null || text === undefined || String(text).trim() === "")
        return { ok: true, value: {} }
    try {
        const value = JSON.parse(text)
        if (!isObject(value))
            return { ok: false, error: "top level is not an object" }
        return { ok: true, value: value }
    } catch (e) {
        return { ok: false, error: String(e && e.message ? e.message : e) }
    }
}

export function expandHome(path, home) {
    if (typeof path !== "string")
        return path
    if (path === "~")
        return home
    if (path.indexOf("~/") === 0)
        return home + path.slice(1)
    return path
}

export function deepMerge(base, over) {
    if (!isObject(base) || !isObject(over))
        return clone(over === undefined ? base : over)
    const out = clone(base)
    for (const key of Object.keys(over)) {
        if (over[key] === undefined || key === "__proto__" || key === "constructor" || key === "prototype")
            continue
        out[key] = isObject(base[key]) && isObject(over[key]) ? deepMerge(base[key], over[key]) : clone(over[key])
    }
    return out
}

const CONFIG_STEPS = [v => v]

const SETTINGS_STEPS = [v => {
    if (isObject(v.cc) && v.center === undefined) {
        v.center = v.cc
        delete v.cc
    }
    return v
}]

function chain(name, raw, steps, current) {
    const v = isObject(raw) ? clone(raw) : {}
    const from = Object.prototype.hasOwnProperty.call(v, "version") ? v.version : 0
    if (!Number.isInteger(from) || from < 0)
        return { ok: false, from: -1, value: null, error: name + " version must be a whole number, found " + JSON.stringify(from) + "; the file is left untouched and defaults are in use" }
    if (from > current)
        return { ok: false, from: from, value: null, error: name + " is version " + from + " but this Sylvaris understands up to version " + current + "; update Sylvaris. The file is left untouched and defaults are in use" }
    let out = v
    for (let i = from; i < current; i++) {
        out = steps[i](out)
        out.version = i + 1
    }
    return { ok: true, from: from, value: out, error: "" }
}

export function migrateConfig(raw) {
    return chain("config.json", raw, CONFIG_STEPS, CONFIG_VERSION)
}

export function migrateSettings(raw) {
    return chain("settings.json", raw, SETTINGS_STEPS, SETTINGS_VERSION)
}

export function migrate(raw) {
    const v = isObject(raw) ? clone(raw) : {}
    if (typeof v.version !== "number")
        v.version = 1
    return v
}

function normalizeToggle(def) {
    if (!isObject(def) || typeof def.id !== "string" || !TOGGLE_ID.test(def.id) || typeof def.label !== "string")
        return null
    return Object.assign({}, def, {
        icon: str(def.icon, DEFAULT_TOGGLE_ICON),
        on: str(def.on, ""),
        off: str(def.off, ""),
        status: str(def.status, "")
    })
}

export function validateConfig(raw) {
    const v = migrate(raw)
    for (const key of STRING_KEYS)
        v[key] = str(v[key], DEFAULT_CONFIG[key])
    const seen = {}
    const toggles = []
    if (Array.isArray(v.toggles)) {
        for (const def of v.toggles) {
            const t = normalizeToggle(def)
            if (t !== null && !seen[t.id]) {
                seen[t.id] = true
                toggles.push(t)
            }
        }
    }
    v.toggles = toggles
    v.commands = Array.isArray(v.commands) ? v.commands : []
    const nt = isObject(v.notifications) ? v.notifications : {}
    v.notifications = Object.assign({}, nt, {
        server: nt.server !== false,
        history: intIn(nt.history, 1, 1000, DEFAULT_CONFIG.notifications.history)
    })
    return v
}

export function validateSettings(raw, userLooks) {
    const v = migrate(raw)
    const d = DEFAULT_SETTINGS

    const center = isObject(v.center) ? v.center : isObject(v.cc) ? v.cc : {}
    delete v.cc
    const hidden = Array.isArray(center.hidden) ? center.hidden.filter(t => typeof t === "string" && (CENTER_TILES.includes(t) || t.startsWith("toggle:") && TOGGLE_ID.test(t.slice(7)))) : []
    v.center = Object.assign({}, center, {
        corner: CORNERS.includes(center.corner) ? center.corner : d.center.corner,
        hidden: hidden.filter((t, i) => hidden.indexOf(t) === i),
        extra: Array.isArray(center.extra) ? center.extra.filter((t, i) => EXTRAS.some(e => e.key === t) && center.extra.indexOf(t) === i) : [],
        volume: typeof center.volume === "boolean" ? center.volume : d.center.volume,
        media: typeof center.media === "boolean" ? center.media : d.center.media,
        layout: LAYOUTS.includes(center.layout) ? center.layout : d.center.layout
    })

    const clock = isObject(v.clock) ? v.clock : {}
    v.clock = Object.assign({}, clock, { corner: CORNERS.includes(clock.corner) ? clock.corner : d.clock.corner })

    const nl = isObject(v.nightLight) ? v.nightLight : {}
    const t = nl.temperature
    v.nightLight = Object.assign({}, nl, {
        enabled: nl.enabled === true,
        temperature: Number.isInteger(t) && t >= 1000 && t <= 10000 ? t : d.nightLight.temperature
    })

    const displays = isObject(v.displays) ? v.displays : {}
    const virt = isObject(displays.virtual) ? displays.virtual : {}
    const side = n => Number.isInteger(n) && n >= 640 && n <= 7680
    v.displays = Object.assign({}, displays, {
        layouts: isObject(displays.layouts) ? displays.layouts : {},
        virtual: {
            enabled: virt.enabled === true,
            width: side(virt.width) ? virt.width : d.displays.virtual.width,
            height: side(virt.height) ? virt.height : d.displays.virtual.height
        }
    })

    const ts = isObject(v.toggleState) ? v.toggleState : {}
    const toggleState = {}
    for (const key of Object.keys(ts)) {
        if (typeof ts[key] === "boolean")
            toggleState[key] = ts[key]
    }
    v.toggleState = toggleState

    const hs = isObject(v.hotspot) ? v.hotspot : {}
    const ssid = hs.ssid
    v.hotspot = Object.assign({}, hs, {
        ssid: typeof ssid === "string" && ssid.length >= 1 && ssid.length <= 32 ? ssid : d.hotspot.ssid,
        band: hs.band === "a" ? "a" : "bg"
    })

    const ns = isObject(v.notifications) ? v.notifications : {}
    v.notifications = Object.assign({}, ns, {
        dnd: ns.dnd === true,
        timeout: intIn(ns.timeout, 1000, 60000, d.notifications.timeout),
        corner: CORNERS.includes(ns.corner) ? ns.corner : d.notifications.corner,
        stack: ns.stack === "cards" ? "cards" : "list"
    })

    const pad = isObject(v.pad) ? v.pad : {}
    v.pad = Object.assign({}, pad, {
        columns: intIn(pad.columns, 3, 10, d.pad.columns),
        rows: intIn(pad.rows, 2, 8, d.pad.rows),
        mode: pad.mode === "list" ? "list" : "launchpad"
    })

    v.bar = validateBar(v.bar)
    v.deck = validateDeck(v.deck)

    const motion = isObject(v.motion) ? v.motion : {}
    v.motion = Object.assign({}, motion, {
        scale: typeof motion.scale === "number" && motion.scale >= 0.25 && motion.scale <= 2 ? motion.scale : d.motion.scale,
        reduced: motion.reduced === true,
        reveal: REVEALS.indexOf(motion.reveal) >= 0 ? motion.reveal : d.motion.reveal,
        preset: PRESETS.indexOf(motion.preset) >= 0 ? motion.preset : d.motion.preset,
        open: OPEN_STYLES.indexOf(motion.open) >= 0 ? motion.open : d.motion.open,
        stagger: typeof motion.stagger === "number" && motion.stagger >= 0 && motion.stagger <= 0.9 ? motion.stagger : d.motion.stagger,
        springiness: motion.springiness === -1 || typeof motion.springiness === "number" && motion.springiness >= 0 && motion.springiness <= 1 ? motion.springiness : d.motion.springiness
    })
    v.performance = v.performance === true ? "on" : PERFORMANCE.indexOf(v.performance) >= 0 ? v.performance : d.performance
    v.iconTint = v.iconTint !== false
    v.power = validatePower(v.power)
    v.paper = validatePaper(v.paper)
    v.weather = validateWeather(v.weather)
    const dv = isObject(v.diver) ? v.diver : {}
    v.diver = Object.assign({}, dv, {
        enabled: dv.enabled !== false,
        refresh: intIn(dv.refresh, 1, 60, d.diver.refresh),
        notify: dv.notify !== false,
        alarms: dv.alarms !== false,
        sound: dv.sound !== false,
        calendar: dv.calendar !== false
    })
    const panel = isObject(v.settings) ? v.settings : {}
    v.settings = Object.assign({}, panel, { detail: panel.detail === "full" ? "full" : "simple" })

    const cons = isObject(v.constellation) ? v.constellation : {}
    v.constellation = Object.assign({}, cons, {
        speed: typeof cons.speed === "number" && cons.speed >= 0 && cons.speed <= 3 ? cons.speed : d.constellation.speed,
        links: cons.links !== false,
        ring: cons.ring !== false,
        labels: cons.labels !== false,
        stars: cons.stars !== false
    })

    v.lock = validateLock(v.lock)
    v.clip = validateClip(v.clip)
    v.island = validateIsland(v.island)
    v.viewer = validateViewer(v.viewer)
    v.files = validateFiles(v.files)
    v.archive = validateArchive(v.archive)
    v.notes = validateNotes(v.notes)
    v.rgb = validateRgb(v.rgb)
    v.temp = validateTemp(v.temp)
    const place = isObject(v.placement) ? v.placement : {}
    v.placement = Object.assign({}, place)
    for (const key of Object.keys(DEFAULT_PLACEMENT))
        v.placement[key] = PLACES.includes(place[key]) || key === "media" && place[key] === "auto" ? place[key] : DEFAULT_PLACEMENT[key]
    v.capture = validateCapture(v.capture)
    v.access = validateAccess(v.access)
    v.keybinds = validateKeybinds(v.keybinds)
    v.plugins = validatePlugins(v.plugins)
    v.widgets = validateWidgets(v.widgets, v.plugins).values
    v.sync = validateSync(v.sync)
    v.corners = validateCorners(v.corners)
    const snd = isObject(v.sounds) ? v.sounds : {}
    v.sounds = Object.assign({}, snd, {
        enabled: snd.enabled === true,
        pack: typeof snd.pack === "string" ? snd.pack : "",
        volume: typeof snd.volume === "number" && snd.volume >= 0 && snd.volume <= 1 ? snd.volume : d.sounds.volume
    })

    const sw = isObject(v.switcher) ? v.switcher : {}
    v.switcher = Object.assign({}, sw, {
        previews: sw.previews !== false,
        titles: sw.titles !== false
    })

    const parts = isObject(v.parts) ? v.parts : {}
    v.parts = partFlags(parts)

    const media = isObject(v.media) ? v.media : {}
    v.media = Object.assign({}, media, {
        eq: validateEq(media.eq),
        airpods: typeof media.airpods === "string" && /^([0-9A-F]{2}:){5}[0-9A-F]{2}$/i.test(media.airpods) ? media.airpods.toUpperCase() : ""
    })
    v.look = validateLook(v.look, userLooks).values
    v.screens = validateScreens(v.screens, v)
    return v
}

export const SCREEN_KEYS = [
    "bar", "deck.enabled", "deck.pad", "deck.power", "deck.effect", "deck.hide", "deck.peek", "deck.peekSize", "deck.reserve", "deck.size",
    "center.corner", "clock.corner", "notifications.corner", "placement", "island.position", "island.idle", "island.reveal", "island.shortcuts",
    "paper.fit", "paper.blur", "paper.dim", "paper.tint", "paper.drift", "paper.transition", "paper.duration"
]

const underScreenKey = path => SCREEN_KEYS.some(k => path === k || path.indexOf(k + ".") === 0)

export function screenKey(key) {
    return SCREEN_KEYS.some(k => key === k || key.indexOf(k + ".") === 0 || k.indexOf(key + ".") === 0)
}

function leaves(obj, prefix) {
    const out = []
    for (const key of Object.keys(obj)) {
        const path = prefix === "" ? key : prefix + "." + key
        if (isObject(obj[key]))
            out.push(...leaves(obj[key], path))
        else
            out.push([path, obj[key]])
    }
    return out
}

function validateScreens(raw, base) {
    const out = {}
    if (!isObject(raw))
        return out
    const shared = Object.assign({}, base, { screens: {} })
    for (const name of Object.keys(raw)) {
        if (!isObject(raw[name]) || ["__proto__", "constructor", "prototype"].includes(name))
            continue
        if (Object.keys(raw[name]).length === 0)
            out[name] = {}
        const pairs = leaves(raw[name], "").filter(([path]) => underScreenKey(path))
        if (pairs.length === 0)
            continue
        const layer = pairs.reduce((acc, [path, value]) => setPath(acc, path, value), {})
        const merged = validateSettings(deepMerge(shared, layer))
        const kept = pairs.filter(([path, value]) => JSON.stringify(getPath(merged, path)) === JSON.stringify(value))
        if (kept.length > 0)
            out[name] = kept.reduce((acc, [path, value]) => setPath(acc, path, value), {})
    }
    return out
}

export function screenSettings(values, name) {
    const layer = isObject(values.screens) ? values.screens[name] : undefined
    if (!isObject(layer))
        return values
    return Object.assign(validateSettings(deepMerge(Object.assign({}, values, { screens: {} }), layer)), { screens: values.screens })
}

function pluggedOff(plugins, key, name) {
    return plugins !== undefined && BUILTIN.some(b => (key === "part" ? b.part === name : b.services.includes(name)) && !builtinOn(plugins, b.id))
}

export function liveParts(parts, plugins) {
    return Object.keys(PARTS).filter(name => partOn(isObject(parts) ? parts : {}, name) && !pluggedOff(plugins, "part", name))
}

export function liveServices(parts, plugins, widgets) {
    const out = []
    const add = name => {
        if (out.includes(name) || pluggedOff(plugins, "service", name))
            return
        out.push(name)
        for (const dep of SERVICE_DEPS[name] || [])
            add(dep)
    }
    const live = liveParts(parts, plugins)
    for (const name of live)
        PARTS[name].forEach(add)
    if (live.includes("widgets"))
        servicesFor(widgets, plugins).forEach(add)
    return out
}

export function settingsLayer(config) {
    const out = {}
    if (!isObject(config))
        return out
    for (const key of Object.keys(DEFAULT_SETTINGS)) {
        if (key !== "version" && config[key] !== undefined)
            out[key] = clone(config[key])
    }
    return out
}

export function effectiveSettings(config, raw, userLooks) {
    const layer = settingsLayer(config)
    const mine = isObject(raw) ? raw : {}
    const look = deepMerge(isObject(layer.look) ? layer.look : {}, isObject(mine.look) ? mine.look : {})
    return validateSettings(deepMerge(deepMerge(lookDefaults(look, userLooks), layer), mine), userLooks)
}

export function merge(config, settings) {
    return deepMerge(validateConfig(config), validateSettings(settings))
}

const own = (obj, key) => Object.prototype.hasOwnProperty.call(obj, key)

export function getPath(obj, path) {
    let cur = obj
    for (const part of path.split(".")) {
        if (!isObject(cur) || !own(cur, part))
            return undefined
        cur = cur[part]
    }
    return cur
}

export function setPath(obj, path, value) {
    const parts = path.split(".")
    if (parts.some(p => p === "__proto__" || p === "constructor" || p === "prototype"))
        throw new Error("not a setting: " + path)
    const out = isObject(obj) ? clone(obj) : {}
    let cur = out
    for (let i = 0; i < parts.length - 1; i++) {
        if (!isObject(cur[parts[i]]) || !own(cur, parts[i]))
            cur[parts[i]] = {}
        cur = cur[parts[i]]
    }
    cur[parts[parts.length - 1]] = clone(value)
    return out
}

export function unsetPath(obj, path) {
    const parts = path.split(".")
    const out = isObject(obj) ? clone(obj) : {}
    const trail = [out]
    for (let i = 0; i < parts.length - 1; i++) {
        const next = trail[i][parts[i]]
        if (!isObject(next) || !own(trail[i], parts[i]))
            return out
        trail.push(next)
    }
    delete trail[trail.length - 1][parts[parts.length - 1]]
    for (let i = trail.length - 1; i > 0 && Object.keys(trail[i]).length === 0; i--)
        delete trail[i - 1][parts[i - 1]]
    return out
}

export function isModified(values, base, key) {
    return JSON.stringify(getPath(values, key)) !== JSON.stringify(getPath(base, key))
}

export function serialize(obj) {
    return JSON.stringify(obj, null, 2) + "\n"
}

export function resolveGlass(config, settings, base) {
    const values = clone(base === undefined ? DEFAULT_GLASS : base)
    const errors = []
    for (const [source, raw] of [["config.json", config], ["settings.json", settings]]) {
        if (raw === undefined || raw === null)
            continue
        if (!isObject(raw)) {
            errors.push(source + " glass must be an object")
            continue
        }
        for (const key of Object.keys(raw)) {
            const v = raw[key]
            if (key === "enabled") {
                if (typeof v === "boolean")
                    values.enabled = v
                else
                    errors.push(source + " glass.enabled must be true or false")
                continue
            }
            if (key === "grain")
                continue
            const range = GLASS_RANGES[key]
            if (range === undefined) {
                errors.push(source + " glass." + key + " is not a glass key")
                continue
            }
            if (typeof v === "number" && Number.isFinite(v) && v >= range[0] && v <= range[1])
                values[key] = v
            else
                errors.push(source + " glass." + key + " must be a number from " + range[0] + " to " + range[1])
        }
    }
    return { values: values, errors: errors }
}
