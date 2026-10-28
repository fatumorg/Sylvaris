import { isPluginModule } from "./plugins.mjs"

export const MODULES = ["pad", "workspaces", "window", "clock", "media", "tray", "audio", "network", "bluetooth", "battery", "notifications", "center", "power", "diver", "temp"]
export const POSITIONS = ["top", "bottom", "left", "right"]
export const STYLES = ["islands", "slab", "float", "minimal"]
export const WORKSPACE_STYLES = ["dots", "numbers", "pills", "icons"]

const g = cp => String.fromCodePoint(cp)

export const WORKSPACE_ICONS = {
    paw: g(0xF03E9), bone: g(0xF00B9), heart: g(0xF02D1), star: g(0xF0AE2), leaf: g(0xF032A), flower: g(0xF024A), fire: g(0xF0238),
    diamond: g(0xF0B8A), tree: g(0xF0405), ghost: g(0xF02A0), moon: g(0xF0F65), cat: g(0xF011B), fish: g(0xF023A), music: g(0xF0387)
}
export const WORKSPACE_LOOKS = ["auto", "numbers", "dots"].concat(Object.keys(WORKSPACE_ICONS))

export function workspaceLook(setting, themeIcon) {
    const pick = setting === "auto" ? themeIcon : setting
    if (pick === "dots")
        return { mode: "dots", glyph: "" }
    if (WORKSPACE_ICONS[pick] !== undefined)
        return { mode: "glyph", glyph: WORKSPACE_ICONS[pick] }
    return { mode: "numbers", glyph: "" }
}

export function workspaceApps(apps, limit) {
    const out = []
    for (const a of apps || []) {
        if (a !== "" && out.indexOf(a) < 0)
            out.push(a)
    }
    return { shown: out.slice(0, limit), more: Math.max(0, out.length - limit) }
}

export function workspaceTicks(windows) {
    return windows > 0 ? Math.min(3, windows) : 0
}

export const DEFAULT_BAR = {
    workspaceIcons: "auto",
    workspaceStyle: "pills",
    enabled: true,
    floating: true,
    position: "top",
    style: "islands",
    left: ["pad", "workspaces", "window"],
    center: ["clock"],
    right: ["media", "tray", "audio", "network", "bluetooth", "battery", "notifications", "center", "power"]
}

export const DEFAULT_DECK = { enabled: false, pinned: [], pad: "start", power: "none", effect: "bloom", glow: false, hide: "never", peek: true, peekSize: 4, reserve: true, size: 56 }
export const DECK_HIDE = ["never", "always", "windows"]
export const DECK_EFFECTS = ["bloom", "magnify", "none"]

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function modules(v, fallback, taken) {
    if (!Array.isArray(v))
        return fallback.filter(m => !taken[m] && (taken[m] = true))
    const out = []
    for (const m of v) {
        if ((MODULES.indexOf(m) >= 0 || isPluginModule(m)) && !taken[m]) {
            taken[m] = true
            out.push(m)
        }
    }
    return out
}

export function validateBar(raw) {
    const b = isObject(raw) ? raw : {}
    const taken = {}
    return Object.assign({}, b, {
        enabled: b.enabled !== false,
        floating: b.floating !== false,
        position: POSITIONS.indexOf(b.position) >= 0 ? b.position : DEFAULT_BAR.position,
        style: STYLES.indexOf(b.style) >= 0 ? b.style : DEFAULT_BAR.style,
        workspaceIcons: WORKSPACE_LOOKS.indexOf(b.workspaceIcons) >= 0 ? b.workspaceIcons : DEFAULT_BAR.workspaceIcons,
        workspaceStyle: WORKSPACE_STYLES.indexOf(b.workspaceStyle) >= 0 ? b.workspaceStyle : DEFAULT_BAR.workspaceStyle,
        left: modules(b.left, DEFAULT_BAR.left, taken),
        center: modules(b.center, DEFAULT_BAR.center, taken),
        right: modules(b.right, DEFAULT_BAR.right, taken)
    })
}

export function validateDeck(raw) {
    const d = isObject(raw) ? raw : {}
    const pinned = Array.isArray(d.pinned) ? d.pinned.filter((id, i, a) => typeof id === "string" && id !== "" && a.indexOf(id) === i) : []
    return Object.assign({}, d, {
        enabled: d.enabled === true,
        pinned: pinned,
        pad: ["start", "end", "none"].indexOf(d.pad) >= 0 ? d.pad : DEFAULT_DECK.pad,
        power: ["start", "end", "none"].indexOf(d.power) >= 0 ? d.power : DEFAULT_DECK.power,
        effect: DECK_EFFECTS.indexOf(d.effect) >= 0 ? d.effect : d.magnify === true ? "magnify" : DEFAULT_DECK.effect,
        glow: d.glow === true,
        hide: DECK_HIDE.indexOf(d.hide) >= 0 ? d.hide : d.autohide === true ? "always" : DEFAULT_DECK.hide,
        peek: d.peek !== false,
        peekSize: Number.isInteger(d.peekSize) && d.peekSize >= 2 && d.peekSize <= 12 ? d.peekSize : DEFAULT_DECK.peekSize,
        reserve: d.reserve !== false,
        size: Number.isInteger(d.size) && d.size >= 36 && d.size <= 96 ? d.size : DEFAULT_DECK.size
    })
}

export function deckItems(pinned, windows, entryOf) {
    const items = pinned.map(id => ({ id: id, pinned: true, windows: [] }))
    const index = {}
    items.forEach((it, i) => index[it.id] = i)
    windows.forEach((w, wi) => {
        const id = entryOf(w.appId) || w.appId || "unknown"
        if (index[id] === undefined) {
            index[id] = items.length
            items.push({ id: id, pinned: false, windows: [] })
        }
        items[index[id]].windows.push(wi)
    })
    return items
}

export function nextWindow(indices, windows) {
    if (indices.length === 0)
        return -1
    const at = indices.findIndex(i => windows[i].activated)
    return at < 0 ? indices[0] : indices[(at + 1) % indices.length]
}

export function unused(bar) {
    return MODULES.filter(m => bar.left.indexOf(m) < 0 && bar.center.indexOf(m) < 0 && bar.right.indexOf(m) < 0)
}

export function shift(list, index, delta) {
    const to = index + delta
    if (index < 0 || index >= list.length || to < 0 || to >= list.length)
        return list.slice()
    const out = list.slice()
    out.splice(to, 0, out.splice(index, 1)[0])
    return out
}

export function togglePin(pinned, id) {
    return pinned.indexOf(id) >= 0 ? pinned.filter(p => p !== id) : pinned.concat([id])
}

export function magnify(distance, reach) {
    const d = Math.abs(distance)
    if (d >= reach)
        return 1
    return 1 + 0.45 * Math.pow(Math.cos(d / reach * Math.PI / 2), 2)
}

export function vertical(position) {
    return position === "left" || position === "right"
}

export function drawerArrow(position) {
    return { top: "down", bottom: "up", left: "right", right: "left" }[position] || "down"
}

export function placeCorner(corner, position) {
    if (corner === "center")
        return corner
    const side = corner === "top-left" ? "left" : corner === "top-right" ? "right" : "center"
    if (position === "bottom")
        return "bottom-" + side
    if (position === "left" || position === "right")
        return (side === "left" ? "top" : side === "right" ? "bottom" : "center") + "-" + position
    return "top-" + side
}

export function deckHidden(mode, s) {
    if (s.hovering || s.menu || s.holding)
        return false
    return mode === "always" || mode === "windows" && s.busy
}

export function screenBusy(workspaces, windows, output) {
    const shown = workspaces.filter(w => w.output === output && w.active)
    if (shown.length === 0)
        return false
    if (shown.some(w => w.windows > 0))
        return true
    return shown.some(w => w.windows < 0) && windows.some(w => !w.minimized)
}

export function middleSlot(total, startLen, centerLen, endLen, gap) {
    const lo = startLen > 0 ? startLen + gap : 0
    const hi = total - centerLen - (endLen > 0 ? endLen + gap : 0)
    if (hi < lo)
        return -1
    return Math.max(lo, Math.min(hi, (total - centerLen) / 2))
}
