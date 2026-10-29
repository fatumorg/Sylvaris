import { builtinOn } from "./plugins.mjs"
import { isImage } from "./paper.mjs"

export const ANCHORS = ["top-left", "top-right", "bottom-left", "bottom-right", "center"]
export const LAYERS = ["desktop", "above", "overlay"]
export const MATERIALS = ["inherit", "glass", "frosted", "solid", "clear"]
export const LIMIT = 24

const PRESETS = { S: [2, 2], M: [4, 2], L: [4, 4] }

export const DEFAULT_STYLE = { material: "inherit", opacity: 1, radius: 1, shadow: true, clear: false, accent: "" }
export const DEFAULT_WIDGETS = { enabled: true, cell: 80, gap: 12, snap: true, style: DEFAULT_STYLE, items: [] }

function sized(min, max) {
    return { min: min, max: max, presets: PRESETS }
}

export const TYPES = {
    clock: {
        label: "Clock", glyph: "clock", sizes: sized([2, 1], [10, 5]), size: [4, 2], services: ["Sky"],
        defaults: { face: "digital", hours24: true, seconds: false, date: "dddd d MMMM", zones: [], font: "", align: "center" },
        fields: [
            { key: "face", label: "Face", kind: "choice", choices: ["digital", "flip", "analog", "word", "giant", "orbit"] },
            { key: "hours24", label: "24-hour time", kind: "toggle" },
            { key: "seconds", label: "Seconds", kind: "toggle" },
            { key: "date", label: "Date format", kind: "text" },
            { key: "zones", label: "Other time zones, like Tokyo +9", kind: "list" },
            { key: "font", label: "Font", kind: "text" },
            { key: "align", label: "Align", kind: "choice", choices: ["left", "center", "right"] }
        ]
    },
    weather: {
        label: "Weather", glyph: "partlyCloudy", sizes: sized([2, 2], [6, 4]), size: [2, 2], services: ["Weather", "Sky"],
        defaults: { feels: true, wind: false, humidity: false },
        fields: [
            { key: "feels", label: "Feels like", kind: "toggle" },
            { key: "wind", label: "Wind", kind: "toggle" },
            { key: "humidity", label: "Humidity", kind: "toggle" }
        ]
    },
    calendar: {
        label: "Calendar", glyph: "calendar", sizes: sized([2, 2], [6, 5]), size: [4, 4], services: ["Diver"],
        defaults: { monday: true, weeks: false, dots: true },
        fields: [
            { key: "monday", label: "Weeks start on Monday", kind: "toggle" },
            { key: "weeks", label: "Week numbers", kind: "toggle" },
            { key: "dots", label: "Diver plans", kind: "toggle" }
        ]
    },
    batteries: {
        label: "Batteries", glyph: "battery", sizes: sized([2, 2], [6, 2]), size: [4, 2], services: ["Battery", "BluetoothService", "Headphones"],
        defaults: { devices: [], hideEmpty: true, ring: 6 },
        fields: [
            { key: "devices", label: "Devices", kind: "list" },
            { key: "hideEmpty", label: "Hide when there are none", kind: "toggle" },
            { key: "ring", label: "Ring width", kind: "number", min: 2, max: 14 }
        ]
    },
    terminal: {
        label: "Terminal", glyph: "terminal", sizes: sized([3, 2], [16, 10]), size: [6, 4], services: [],
        defaults: { command: "", fontSize: 11, opacity: 0, padding: 10, typing: false, restart: true },
        fields: [
            { key: "command", label: "Command", kind: "text" },
            { key: "fontSize", label: "Font size", kind: "number", min: 6, max: 32 },
            { key: "opacity", label: "Background", kind: "number", min: 0, max: 1 },
            { key: "padding", label: "Padding", kind: "number", min: 0, max: 40 },
            { key: "typing", label: "Type into it", kind: "toggle" },
            { key: "restart", label: "Start again when it ends", kind: "toggle" }
        ]
    },
    visualizer: {
        label: "Visualizer", glyph: "music", sizes: sized([2, 1], [16, 6]), size: [4, 2], services: [],
        defaults: { style: "bars", bars: 32, fps: 60, smoothing: 0.5, colour: "accent", glow: true },
        fields: [
            { key: "style", label: "Style", kind: "choice", choices: ["bars", "mirror", "wave", "radial", "dots"] },
            { key: "bars", label: "Bars", kind: "number", min: 8, max: 128 },
            { key: "fps", label: "Frame rate", kind: "choice", choices: [30, 60] },
            { key: "smoothing", label: "Smoothing", kind: "number", min: 0, max: 1 },
            { key: "colour", label: "Colour", kind: "choice", choices: ["accent", "theme", "rainbow"] },
            { key: "glow", label: "Glow", kind: "toggle" }
        ]
    },
    photos: {
        label: "Photos", glyph: "image", sizes: sized([2, 2], [12, 10]), size: [4, 4], services: [],
        defaults: { source: "~/Pictures", recursive: false, mode: "single", interval: 30, shuffle: true, transition: "fade", frame: "round", recolour: "off", strength: 0.6 },
        fields: [
            { key: "source", label: "Folder or picture", kind: "path" },
            { key: "recursive", label: "Include folders inside", kind: "toggle" },
            { key: "mode", label: "Show", kind: "choice", choices: ["single", "slideshow", "polaroid", "mosaic"] },
            { key: "interval", label: "Seconds per photo", kind: "number", min: 3, max: 3600 },
            { key: "shuffle", label: "Shuffle", kind: "toggle" },
            { key: "transition", label: "Transition", kind: "choice", choices: ["fade", "slide", "kenburns"] },
            { key: "frame", label: "Frame", kind: "choice", choices: ["round", "circle", "polaroid"] },
            { key: "recolour", label: "Recolour", kind: "choice", choices: ["off", "tint", "mono", "duotone"] },
            { key: "strength", label: "Strength", kind: "number", min: 0, max: 1 }
        ]
    },
    diver: {
        label: "Diver", glyph: "planner", sizes: sized([2, 2], [6, 6]), size: [4, 4], services: ["Diver"], plugin: "diver",
        defaults: { count: 5, done: false },
        fields: [
            { key: "count", label: "Tasks", kind: "number", min: 1, max: 20 },
            { key: "done", label: "Show done", kind: "toggle" }
        ]
    },
    temp: {
        label: "SylTemp", glyph: "thermometer", sizes: sized([2, 2], [6, 4]), size: [4, 2], services: ["Temps"], plugin: "temp",
        defaults: { sensors: [], style: "rings" },
        fields: [
            { key: "sensors", label: "Sensors", kind: "list" },
            { key: "style", label: "Style", kind: "choice", choices: ["rings", "list", "graph"] }
        ]
    },
    stack: {
        label: "Stack", glyph: "layers", sizes: sized([2, 2], [8, 6]), size: [4, 2], services: [],
        defaults: { every: 0 },
        fields: [
            { key: "every", label: "Turn every (seconds, 0 = never)", kind: "number", min: 0, max: 3600 }
        ]
    },
    media: {
        label: "Now playing", glyph: "music", sizes: sized([2, 2], [8, 4]), size: [4, 2], services: ["Media"],
        defaults: { vinyl: false, recolour: "off", controls: true },
        fields: [
            { key: "vinyl", label: "Spin the cover like a record", kind: "toggle" },
            { key: "recolour", label: "Recolour the cover", kind: "choice", choices: ["off", "tint", "mono"] },
            { key: "controls", label: "Buttons", kind: "toggle" }
        ]
    },
    system: {
        label: "System", glyph: "chart", sizes: sized([2, 2], [8, 6]), size: [4, 2], services: [],
        defaults: { cpu: true, memory: true, disk: true, network: true, every: 2 },
        fields: [
            { key: "cpu", label: "Processor", kind: "toggle" },
            { key: "memory", label: "Memory", kind: "toggle" },
            { key: "disk", label: "Disk space", kind: "toggle" },
            { key: "network", label: "Network", kind: "toggle" },
            { key: "every", label: "Seconds between readings", kind: "number", min: 1, max: 10 }
        ]
    },
    sky: {
        label: "Sky", glyph: "moon", sizes: sized([2, 2], [8, 4]), size: [4, 2], services: ["Sky"],
        defaults: { moon: true, times: true },
        fields: [
            { key: "moon", label: "Moon", kind: "toggle" },
            { key: "times", label: "Sunrise and sunset", kind: "toggle" }
        ]
    },
    note: {
        label: "Note", glyph: "pencil", sizes: sized([2, 2], [8, 8]), size: [3, 3], services: [],
        defaults: { text: "", size: 14, paper: true },
        fields: [
            { key: "text", label: "Text", kind: "text", max: 20000, hidden: true },
            { key: "size", label: "Text size", kind: "number", min: 9, max: 40 },
            { key: "paper", label: "Sticky note colour", kind: "toggle" }
        ]
    },
    countdown: {
        label: "Countdown", glyph: "timer", sizes: sized([2, 1], [6, 4]), size: [2, 2], services: [],
        defaults: { date: "", title: "" },
        fields: [
            { key: "date", label: "Date, like 2026-12-24", kind: "text" },
            { key: "title", label: "What happens then", kind: "text" }
        ]
    },
    shelf: {
        label: "Shelf", glyph: "apps", sizes: sized([1, 1], [12, 6]), size: [4, 1], services: ["Apps"],
        defaults: { apps: [], labels: false },
        fields: [
            { key: "apps", label: "Apps (desktop ids, empty = SylDeck's)", kind: "list" },
            { key: "labels", label: "Names", kind: "toggle" }
        ]
    },
    text: {
        label: "Text", glyph: "text", sizes: sized([1, 1], [16, 8]), size: [4, 1], services: [],
        defaults: { text: "Sylvaris", font: "", style: "filled", align: "center", colour: "" },
        fields: [
            { key: "text", label: "Text", kind: "text", max: 500 },
            { key: "font", label: "Font", kind: "text" },
            { key: "style", label: "Style", kind: "choice", choices: ["filled", "outlined"] },
            { key: "align", label: "Align", kind: "choice", choices: ["left", "center", "right"] },
            { key: "colour", label: "Colour, like #ff8800 (empty = theme)", kind: "color" }
        ]
    },
    sticker: {
        label: "Sticker", glyph: "starFour", sizes: sized([1, 1], [12, 10]), size: [2, 2], services: [],
        defaults: { source: "", recolour: "off", strength: 0.6 },
        fields: [
            { key: "source", label: "Picture or GIF", kind: "path" },
            { key: "recolour", label: "Recolour", kind: "choice", choices: ["off", "tint", "mono"] },
            { key: "strength", label: "Strength", kind: "number", min: 0, max: 1 }
        ]
    },
    fatest: {
        label: "FaTest", glyph: "speed", sizes: sized([2, 1], [6, 4]), size: [2, 2], services: [], plugin: "fatest",
        defaults: { upload: true, ping: true },
        fields: [
            { key: "upload", label: "Upload", kind: "toggle" },
            { key: "ping", label: "Ping", kind: "toggle" }
        ]
    }
}

export const WIDGET_SERVICES = (() => {
    const out = {}
    for (const type of Object.keys(TYPES))
        out[type] = TYPES[type].services
    return out
})()

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function int(v, lo, hi, fallback) {
    return Number.isInteger(v) ? Math.max(lo, Math.min(hi, v)) : fallback
}

function num(v, lo, hi, fallback) {
    return typeof v === "number" && Number.isFinite(v) ? Math.max(lo, Math.min(hi, v)) : fallback
}

export function validateOptions(type, raw) {
    const t = TYPES[type]
    const o = isObject(raw) ? raw : {}
    const out = {}
    for (const f of t.fields) {
        const d = t.defaults[f.key]
        const v = o[f.key]
        if (f.kind === "toggle")
            out[f.key] = typeof v === "boolean" ? v : d
        else if (f.kind === "choice")
            out[f.key] = f.choices.includes(v) ? v : d
        else if (f.kind === "number")
            out[f.key] = num(v, f.min, f.max, d)
        else if (f.kind === "color")
            out[f.key] = typeof v === "string" && /^(#[0-9a-fA-F]{6})?$/.test(v) ? v : d
        else if (f.kind === "list")
            out[f.key] = Array.isArray(v) ? v.filter(x => typeof x === "string") : d
        else
            out[f.key] = typeof v === "string" ? v.slice(0, f.max || v.length) : d
    }
    return out
}

export function validateStyle(raw, partial) {
    const s = isObject(raw) ? raw : {}
    const d = DEFAULT_STYLE
    const out = {}
    const pick = (key, ok, value) => {
        if (ok)
            out[key] = value
        else if (!partial)
            out[key] = d[key]
    }
    pick("material", MATERIALS.includes(s.material), s.material)
    pick("opacity", typeof s.opacity === "number" && Number.isFinite(s.opacity), num(s.opacity, 0, 1, d.opacity))
    pick("radius", typeof s.radius === "number" && Number.isFinite(s.radius), num(s.radius, 0, 3, d.radius))
    pick("shadow", typeof s.shadow === "boolean", s.shadow)
    pick("clear", typeof s.clear === "boolean", s.clear)
    pick("accent", typeof s.accent === "string" && /^(#[0-9a-fA-F]{6})?$/.test(s.accent), s.accent)
    return out
}

export function newId(existing) {
    const taken = new Set(existing)
    const chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    for (;;) {
        let id = ""
        for (let i = 0; i < 4; i++)
            id += chars[Math.floor(Math.random() * chars.length)]
        if (!taken.has(id))
            return id
    }
}

function freshId(taken, reserved) {
    for (let n = 0; ; n++) {
        const id = "w" + n.toString(36).padStart(3, "0")
        if (!taken.includes(id) && !reserved.includes(id))
            return id
    }
}

function explicitIds(list) {
    const out = []
    for (const raw of Array.isArray(list) ? list : []) {
        if (isObject(raw) && typeof raw.id === "string" && /^[a-z0-9]{4}$/.test(raw.id))
            out.push(raw.id)
        if (isObject(raw))
            explicitIds(raw.children).forEach(id => out.push(id))
    }
    return out
}

function validateItem(raw, plugins, taken, errors, nested, reserved) {
    if (!isObject(raw) || TYPES[raw.type] === undefined || nested && raw.type === "stack") {
        errors.push("widgets: dropped an item of unknown type " + JSON.stringify(isObject(raw) ? raw.type : raw))
        return null
    }
    const t = TYPES[raw.type]
    let id = typeof raw.id === "string" && /^[a-z0-9]{4}$/.test(raw.id) ? raw.id : ""
    if (id !== "" && taken.includes(id)) {
        errors.push("widgets: renamed a second item with id " + id)
        id = ""
    }
    if (id === "")
        id = freshId(taken, reserved)
    taken.push(id)
    const item = {
        id: id,
        type: raw.type,
        screen: typeof raw.screen === "string" ? raw.screen : "",
        anchor: ANCHORS.includes(raw.anchor) ? raw.anchor : "top-left",
        col: int(raw.col, -200, 200, 0),
        row: int(raw.row, -200, 200, 0),
        w: int(raw.w, t.sizes.min[0], t.sizes.max[0], t.size[0]),
        h: int(raw.h, t.sizes.min[1], t.sizes.max[1], t.size[1]),
        layer: LAYERS.includes(raw.layer) ? raw.layer : "desktop",
        clickThrough: raw.clickThrough === true,
        hideFullscreen: raw.hideFullscreen !== false,
        workspaces: Array.isArray(raw.workspaces) ? raw.workspaces.filter(w => typeof w === "string" || Number.isInteger(w)) : [],
        style: validateStyle(raw.style, true),
        options: validateOptions(raw.type, raw.options),
        inactive: t.plugin !== undefined && !builtinOn(plugins, t.plugin)
    }
    if (raw.type === "stack")
        item.children = (Array.isArray(raw.children) ? raw.children : []).map(c => validateItem(c, plugins, taken, errors, true, reserved)).filter(c => c !== null)
    return item
}

export function validateWidgets(raw, plugins) {
    const r = isObject(raw) ? raw : {}
    const d = DEFAULT_WIDGETS
    const errors = []
    const taken = []
    const reserved = explicitIds(r.items)
    const items = (Array.isArray(r.items) ? r.items : []).map(i => validateItem(i, plugins, taken, errors, false, reserved)).filter(i => i !== null)
    return {
        values: {
            enabled: r.enabled !== false,
            cell: int(r.cell, 32, 240, d.cell),
            gap: int(r.gap, 0, 64, d.gap),
            snap: r.snap !== false,
            style: validateStyle(r.style, false),
            items: items
        },
        errors: errors
    }
}

export function span(cells, cell, gap) {
    return cells * cell + (cells - 1) * gap
}

export function place(item, screens, cell, gap) {
    const s = (screens || []).find(x => x.name === item.screen) || (item.screen === "" && screens && screens.length > 0 ? screens[0] : null)
    if (!s)
        return null
    const w = Math.min(span(item.w, cell, gap), s.width)
    const h = Math.min(span(item.h, cell, gap), s.height)
    const dx = gap + item.col * (cell + gap)
    const dy = gap + item.row * (cell + gap)
    const right = item.anchor === "top-right" || item.anchor === "bottom-right"
    const bottom = item.anchor === "bottom-left" || item.anchor === "bottom-right"
    let x = right ? s.width - dx - w : dx
    let y = bottom ? s.height - dy - h : dy
    if (item.anchor === "center") {
        x = (s.width - w) / 2 + item.col * (cell + gap)
        y = (s.height - h) / 2 + item.row * (cell + gap)
    }
    return {
        x: Math.round(Math.max(0, Math.min(s.width - w, x))),
        y: Math.round(Math.max(0, Math.min(s.height - h, y))),
        w: w,
        h: h
    }
}

function overlaps(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
}

export function nudge(items, screen, cell, gap, home = "") {
    const placed = []
    const on = name => name === "" ? home : name
    return items.map(item => {
        if (on(item.screen) !== on(screen.name))
            return item
        let next = item
        let rect = place(next, [screen], cell, gap)
        for (let i = 0; i < 200 && rect !== null && placed.some(p => overlaps(p, rect)); i++) {
            next = Object.assign({}, next, { row: next.row + 1 })
            rect = place(next, [screen], cell, gap)
        }
        if (rect !== null)
            placed.push(rect)
        return next
    })
}

export function covered(windows, screen) {
    return (windows || []).some(w => w.screen === screen && w.visible !== false && (w.fullscreen === true || w.maximized === true))
}

export function tooMany(items) {
    return items.length > LIMIT
}

export function servicesFor(widgets, plugins) {
    const out = []
    const items = isObject(widgets) && Array.isArray(widgets.items) ? widgets.items : []
    const walk = list => {
        for (const item of list) {
            const t = isObject(item) ? TYPES[item.type] : undefined
            if (t === undefined || t.plugin !== undefined && !builtinOn(plugins, t.plugin))
                continue
            for (const s of t.services) {
                if (!out.includes(s))
                    out.push(s)
            }
            if (Array.isArray(item.children))
                walk(item.children)
        }
    }
    walk(items)
    return out
}

export function snap(px, cell, gap) {
    return Math.max(0, Math.round(px / (cell + gap)))
}

export function guides(rect, others, tol) {
    const t = tol === undefined ? 6 : tol
    const out = []
    const xs = r => [r.x, r.x + r.w / 2, r.x + r.w]
    const ys = r => [r.y, r.y + r.h / 2, r.y + r.h]
    for (const o of others) {
        for (const a of xs(rect)) {
            for (const b of xs(o)) {
                if (Math.abs(a - b) <= t && !out.some(g => g.axis === "x" && g.at === b))
                    out.push({ axis: "x", at: b })
            }
        }
        for (const a of ys(rect)) {
            for (const b of ys(o)) {
                if (Math.abs(a - b) <= t && !out.some(g => g.axis === "y" && g.at === b))
                    out.push({ axis: "y", at: b })
            }
        }
    }
    return out
}

export function resizeTo(item, w, h) {
    const t = TYPES[item.type]
    const clampTo = (v, i) => Math.max(t.sizes.min[i], Math.min(t.sizes.max[i], Math.round(v)))
    return Object.assign({}, item, { w: clampTo(w, 0), h: clampTo(h, 1) })
}

export function begin(items) {
    return { items: items, past: [] }
}

export function apply(session, op) {
    const items = session.items.map(item => {
        if (item.id !== op.id && op.kind === "set" && Array.isArray(item.children) && item.children.some(c => c.id === op.id))
            return Object.assign({}, item, { children: item.children.map(c => c.id === op.id ? Object.assign({}, c, op.values) : c) })
        if (item.id !== op.id)
            return item
        if (op.kind === "move") {
            const sx = item.anchor === "top-right" || item.anchor === "bottom-right" ? -1 : 1
            const sy = item.anchor === "bottom-left" || item.anchor === "bottom-right" ? -1 : 1
            return Object.assign({}, item, { col: item.col + sx * (op.dc || 0), row: item.row + sy * (op.dr || 0) })
        }
        if (op.kind === "place")
            return Object.assign({}, item, { col: op.col, row: op.row, anchor: op.anchor || item.anchor, screen: op.screen || item.screen })
        if (op.kind === "resize")
            return resizeTo(item, op.w, op.h)
        if (op.kind === "set")
            return Object.assign({}, item, op.values)
        return item
    })
    const next = op.kind === "remove" ? items.filter(i => i.id !== op.id) : op.kind === "add" ? items.concat([op.item]) : items
    return { items: next, past: session.past.concat([session.items]).slice(-50) }
}

export function undo(session) {
    if (session.past.length === 0)
        return session
    return { items: session.past[session.past.length - 1], past: session.past.slice(0, -1) }
}

export function commit(session, screens, cell, gap) {
    let items = session.items
    for (const s of screens || [])
        items = nudge(items, s, cell, gap, screens[0].name)
    return items
}

const WORD_HOURS = ["TWELVE", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN", "ELEVEN"]
const WORD_MINUTES = [[], ["FIVE", "PAST"], ["TEN", "PAST"], ["QUARTER", "PAST"], ["TWENTY", "PAST"], ["TWENTY", "FIVE", "PAST"], ["HALF", "PAST"],
    ["TWENTY", "FIVE", "TO"], ["TWENTY", "TO"], ["QUARTER", "TO"], ["TEN", "TO"], ["FIVE", "TO"]]

export function wordClock(h, m) {
    const step = Math.round(m / 5) % 12
    const carry = Math.round(m / 5) === 12 || step > 6 ? 1 : 0
    const hour = WORD_HOURS[(h + carry) % 12]
    return ["IT", "IS"].concat(WORD_MINUTES[step], [hour], step === 0 ? ["OCLOCK"] : [])
}

export function zoneTime(now, entry, hours24) {
    const m = /^(.*?)\s*(?:UTC)?\s*([+-])(\d{1,2})(?::(\d{2}))?$/.exec(String(entry).trim())
    if (m === null)
        return null
    const offset = (m[2] === "-" ? -1 : 1) * (Number(m[3]) * 60 + Number(m[4] || 0))
    if (Math.abs(offset) > 14 * 60)
        return null
    const t = new Date(now.getTime() + now.getTimezoneOffset() * 60000 + offset * 60000)
    const h = t.getHours()
    const hh = hours24 === false ? String((h + 11) % 12 + 1) : String(h).padStart(2, "0")
    return { label: m[1].trim() === "" ? "UTC" + m[2] + m[3] : m[1].trim(), time: hh + ":" + String(t.getMinutes()).padStart(2, "0") }
}

export function stackIndex(i, n, delta) {
    if (n <= 0)
        return 0
    return ((i + delta) % n + n) % n
}

export function kittyOk(text) {
    const m = String(text || "").match(/kitty (\d+)\.(\d+)/)
    return m !== null && (Number(m[1]) > 0 || Number(m[2]) >= 42)
}

function panelRect(rect, padding) {
    const p = Math.max(0, Number(padding) || 0)
    return { x: rect.x + p, y: rect.y + p, w: rect.w - 2 * p, h: rect.h - 2 * p }
}

export function kittyArgs(item, rect, screenName, socket) {
    const o = item.options
    const r = panelRect(rect, o.padding)
    const command = String(o.command || "").trim()
    const args = ["+kitten", "panel", "--edge=none", "--layer", item.layer === "desktop" ? "bottom" : item.layer === "overlay" ? "overlay" : "top",
        "--output-name", screenName, "--margin-left", String(r.x), "--margin-top", String(r.y),
        "--columns", r.w + "px", "--lines", r.h + "px", "--class", "sylwidget-" + item.id,
        "--focus-policy", o.typing || command === "" ? "on-demand" : "not-allowed", "--listen-on", "unix:" + socket,
        "-o", "allow_remote_control=socket-only", "-o", "background_opacity=" + o.opacity, "-o", "font_size=" + o.fontSize,
        "-o", "window_padding_width=0", "-o", "window_margin_width=0", "-o", "single_window_margin_width=0", "-o", "window_border_width=0"]
    return command === "" ? args : args.concat(splitCommand(command))
}

export function splitCommand(text) {
    const out = []
    let cur = "", quote = "", any = false
    for (const c of String(text)) {
        if (quote !== "") {
            if (c === quote)
                quote = ""
            else
                cur += c
        } else if (c === "'" || c === "\"") {
            quote = c
            any = true
        } else if (/\s/.test(c)) {
            if (cur !== "" || any)
                out.push(cur)
            cur = ""
            any = false
        } else {
            cur += c
        }
    }
    if (cur !== "" || any)
        out.push(cur)
    return out
}

export function moveArgs(rect, socket, padding) {
    const r = panelRect(rect, padding)
    return ["@", "--to", "unix:" + socket, "resize-os-window", "--action=os-panel", "--incremental",
        "margin-left=" + r.x, "margin-top=" + r.y, "columns=" + r.w + "px", "lines=" + r.h + "px"]
}

export function shouldRestart(exits, now) {
    return exits.filter(t => now - t < 10000).length < 3
}

export function cavaConfig(o) {
    return ["[general]", "bars = " + o.bars, "framerate = " + o.fps, "", "[smoothing]", "noise_reduction = " + Math.round(o.smoothing * 100), "",
        "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 1000", "bar_delimiter = 59", "frame_delimiter = 10", ""].join("\n")
}

export function parseBars(line, count) {
    const parts = String(line).split(";")
    if (parts.length > 0 && parts[parts.length - 1].trim() === "")
        parts.pop()
    if (parts.length !== count)
        return null
    const out = []
    for (const p of parts) {
        if (!/^\d+$/.test(p.trim()))
            return null
        out.push(Math.min(1, Number(p) / 1000))
    }
    return out
}

const PART_KIND = { left: "bud-left", right: "bud-right", case: "case" }
const KINDS = ["headphones", "mouse", "keyboard", "laptop", "battery"]

export function batteryRings(devices, opts) {
    const o = opts || {}
    const pick = Array.isArray(o.devices) && o.devices.length > 0 ? o.devices : null
    return (devices || []).filter(d => pick === null || pick.includes(d.name)).map(d => ({
        kind: PART_KIND[d.part] || (d.kind === "battery" ? "laptop" : KINDS.includes(d.kind) ? d.kind : "generic"),
        label: d.part === "left" ? "L" : d.part === "right" ? "R" : d.part === "case" ? "Case" : d.name,
        level: Math.max(0, Math.min(100, Math.round(Number(d.level) || 0))),
        charging: d.charging === true
    }))
}

export function photoList(text, cap) {
    const max = cap === undefined ? 500 : cap
    return String(text || "").split("\n").map(l => l.trim()).filter(l => l !== "" && isImage(l)).sort().slice(0, max)
}

export function nextPhoto(i, n, shuffle, seed) {
    if (n <= 1)
        return 0
    if (!shuffle)
        return (i + 1) % n
    const x = Math.sin((seed + 1) * 12.9898 + i * 78.233) * 43758.5453
    const j = Math.floor((x - Math.floor(x)) * (n - 1))
    return j >= i ? j + 1 : j
}

function cpuTimes(stat) {
    const line = String(stat || "").split("\n").find(l => /^cpu\s/.test(l))
    if (line === undefined)
        return null
    const n = line.trim().split(/\s+/).slice(1, 9).map(Number)
    const total = n.reduce((a, b) => a + b, 0)
    return { idle: n[3] + n[4], total: total }
}

export function cpuDelta(prev, next) {
    const a = cpuTimes(prev)
    const b = cpuTimes(next)
    if (a === null || b === null || b.total <= a.total)
        return 0
    return Math.max(0, Math.min(1, 1 - (b.idle - a.idle) / (b.total - a.total)))
}

export function memUsed(meminfo) {
    const kb = key => {
        const m = String(meminfo || "").match(new RegExp("^" + key + ":\\s+(\\d+)", "m"))
        return m === null ? 0 : Number(m[1]) * 1024
    }
    const total = kb("MemTotal")
    return total === 0 ? { used: 0, total: 0 } : { used: total - kb("MemAvailable"), total: total }
}

function netTotals(dev) {
    let rx = 0
    let tx = 0
    for (const line of String(dev || "").split("\n")) {
        const at = line.indexOf(":")
        if (at < 0 || line.slice(0, at).trim() === "lo")
            continue
        const n = line.slice(at + 1).trim().split(/\s+/).map(Number)
        rx += n[0] || 0
        tx += n[8] || 0
    }
    return { rx: rx, tx: tx }
}

const UNITS = ["B", "kB", "MB", "GB", "TB"]

function unitFor(bytes) {
    let i = 0
    while (bytes >= 999.5 * 1000 ** i && i < UNITS.length - 1)
        i++
    return i
}

function short(v) {
    return v < 9.95 ? v.toFixed(1) : String(Math.round(v))
}

export function rateText(bytesPerSecond) {
    const i = unitFor(bytesPerSecond)
    return (i === 0 ? String(Math.round(bytesPerSecond)) : short(bytesPerSecond / 1000 ** i)) + " " + UNITS[i] + "/s"
}

export function usedOf(used, total) {
    const i = unitFor(total)
    return short(used / 1000 ** i) + "/" + short(total / 1000 ** i) + " " + UNITS[i]
}

export function netRate(prev, next, ms) {
    if (!(ms > 0))
        return { rx: 0, tx: 0 }
    const a = netTotals(prev)
    const b = netTotals(next)
    return { rx: Math.max(0, (b.rx - a.rx) * 1000 / ms), tx: Math.max(0, (b.tx - a.tx) * 1000 / ms) }
}

export function daysUntil(dateIso, nowMs) {
    const m = String(dateIso || "").match(/^(\d{4})-(\d{2})-(\d{2})$/)
    if (m === null)
        return null
    const now = new Date(nowMs)
    const from = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
    const day = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]))
    if (day.getMonth() !== Number(m[2]) - 1 || day.getDate() !== Number(m[3]))
        return null
    return Math.round((day.getTime() - from) / 86400000)
}
