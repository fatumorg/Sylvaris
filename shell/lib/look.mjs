import { PRESETS, OPEN_STYLES, REVEALS } from "./motion.mjs"
import { STYLES, WORKSPACE_STYLES, DECK_EFFECTS } from "./bar.mjs"
import { LAYOUTS } from "./center.mjs"
import { STACKS } from "./notify.mjs"
import { LOCK_FACES } from "./lock.mjs"
import { IDLE } from "./island.mjs"

export const MATERIALS = {
    lumen: { opacity: 0.5, layerOpacity: 0.32, tint: 0.12, sheen: 0.45, flow: 1.2, rim: 0.65, grain: 0.035, highlight: 0.55, glow: 0.22, shadow: 0.45 },
    resin: { opacity: 0.55, layerOpacity: 0.35, tint: 0.14, sheen: 0.35, flow: 1, rim: 0.5, grain: 0, highlight: 0, glow: 0, shadow: 0 },
    frost: { opacity: 0.72, layerOpacity: 0.55, tint: 0.1, sheen: 0.25, flow: 0.6, rim: 0.45, grain: 0.07, highlight: 0.5, glow: 0, shadow: 0.35 },
    ink: { opacity: 0.9, layerOpacity: 0.75, tint: 0.05, sheen: 0.08, flow: 0.3, rim: 0.25, grain: 0, highlight: 0.15, glow: 0, shadow: 0.6 },
    neon: { opacity: 0.6, layerOpacity: 0.4, tint: 0.2, sheen: 0.3, flow: 2, rim: 0.9, grain: 0, highlight: 0.2, glow: 0.8, shadow: 0.2 },
    paper: { opacity: 0.96, layerOpacity: 0.6, tint: 0.05, sheen: 0, flow: 0, rim: 0.2, grain: 0.14, highlight: 0.2, glow: 0, shadow: 0.3 }
}

export const CORNERS = ["round", "squircle", "bevel", "sharp"]
export const DENSITY = { compact: 0.85, cozy: 1, roomy: 1.15 }
export const WEIGHTS = ["light", "regular", "medium", "heavy"]
export const CASES = ["normal", "upper", "smallcaps"]
export const ACCENTS = ["theme", "wallpaper"]
export const SECTIONS = ["glass", "shape", "type", "controls", "motion", "layout", "atmosphere"]
export const CONTROL_CHOICES = {
    toggle: ["pill", "block", "check", "led"],
    slider: ["fill", "line", "ticks"],
    segmented: ["pill", "underline", "boxed"],
    button: ["glass", "solid", "outline", "text"],
    card: ["glass", "solid", "outline", "lifted"],
    hover: ["lift", "glow", "invert", "underline"],
    icon: ["plain", "plate", "ring", "glow"],
    divider: ["none", "hairline", "dashed"]
}

const GLASS_KEYS = ["opacity", "layerOpacity", "tint", "sheen", "flow", "rim", "grain", "highlight", "glow", "shadow"]
const LAYER_KEYS = ["shadow", "grain", "highlight", "glow"]
const FONT_KEYS = ["ui", "mono", "display"]
const MONO = "JetBrainsMono Nerd Font"

function controls(toggle, slider, segmented, button, card, hover, icon, divider) {
    return { toggle: toggle, slider: slider, segmented: segmented, button: button, card: card, hover: hover, icon: icon, divider: divider }
}

function style(name, glass, shape, type, ctl, motion, layout, atmosphere) {
    return { version: 2, name: name, glass: glass, shape: shape, type: type, controls: ctl, motion: motion, layout: layout, atmosphere: atmosphere }
}

function shape(corners, radius, density, border) {
    return { corners: corners, radius: radius, density: density, border: border }
}

function type(ui, display, mono, weight, labelCase, tracking, scale) {
    return { fonts: { ui: ui, display: display, mono: mono }, weight: weight, labelCase: labelCase, tracking: tracking, scale: scale }
}

function motion(preset, open, reveal, stagger, springiness) {
    return { preset: preset, open: open, reveal: reveal, stagger: stagger, springiness: springiness }
}

function layout(barStyle, workspaceStyle, center, notifications, lockFace, islandIdle, deckEffect, deckGlow, padMode) {
    return { barStyle: barStyle, workspaceStyle: workspaceStyle, center: center, notifications: notifications, lockFace: lockFace, islandIdle: islandIdle, deckEffect: deckEffect, deckGlow: deckGlow, padMode: padMode }
}

function atmosphere(aurora, accentStrength, wallBlur, wallDim, wallTint) {
    return { aurora: aurora, accent: "theme", accentStrength: accentStrength, wallBlur: wallBlur, wallDim: wallDim, wallTint: wallTint }
}

export const LOOKS = {
    lumen: style("Lumen", { material: "lumen" }, shape("squircle", 1.15, "cozy", 0), type("Inter", "Inter Display", MONO, "medium", "normal", 0, 1),
        controls("pill", "fill", "pill", "glass", "glass", "lift", "plain", "none"), motion("smooth", "morph", "edges", 0.35, 0.5),
        layout("float", "dots", "bento", "cards", "giant", "pill", "magnify", true, "launchpad"), atmosphere(true, 0.6, 0, 0, 0)),
    classic: style("Classic", { material: "resin" }, shape("round", 1, "cozy", 0), type("IBM Plex Sans", "IBM Plex Sans", "IBM Plex Mono", "regular", "normal", 0, 1),
        controls("pill", "line", "boxed", "solid", "solid", "glow", "plain", "hairline"), motion("calm", "grow", "fade", 0.25, 0),
        layout("slab", "numbers", "grid", "list", "default", "clock", "bloom", false, "launchpad"), atmosphere(false, 0.5, 0, 0, 0)),
    frost: style("Frost", { material: "frost" }, shape("round", 1.3, "roomy", 1), type("Geist", "Geist", "Geist Mono", "light", "normal", 0.02, 1.05),
        controls("pill", "line", "underline", "text", "outline", "glow", "ring", "hairline"), motion("calm", "blur", "fade", 0.45, 0),
        layout("minimal", "dots", "grid", "list", "analog", "hide", "magnify", false, "launchpad"), atmosphere(true, 0.3, 0.2, 0, 0)),
    ink: style("Ink", { material: "ink" }, shape("sharp", 0.6, "compact", 1.5), type("Geist", "Geist", MONO, "heavy", "upper", 0.08, 0.95),
        controls("block", "ticks", "boxed", "outline", "outline", "invert", "plain", "hairline"), motion("snappy", "drop", "edges", 0.15, 0),
        layout("slab", "numbers", "grid", "list", "digital", "clock", "none", false, "list"), atmosphere(false, 1, 0, 0.15, 0)),
    neon: style("Neon", { material: "neon" }, shape("bevel", 0.8, "cozy", 1), type("Geist Mono", "Orbitron", "Departure Mono", "medium", "upper", 0.1, 1),
        controls("led", "ticks", "boxed", "outline", "outline", "glow", "glow", "dashed"), motion("playful", "swing", "center", 0.5, 0.8),
        layout("islands", "pills", "bento", "cards", "flip", "pill", "bloom", true, "launchpad"), atmosphere(true, 1, 0, 0, 0.2)),
    paper: style("Paper", { material: "paper", grain: 0.2 }, shape("round", 0.5, "roomy", 1), type("Lora", "Fraunces", "IBM Plex Mono", "regular", "smallcaps", 0.03, 1.05),
        controls("check", "line", "underline", "text", "lifted", "underline", "plain", "dashed"), motion("calm", "unfold", "fade", 0.3, 0),
        layout("minimal", "numbers", "grid", "list", "word", "hide", "none", false, "list"), atmosphere(false, 0.4, 0, 0, 0))
}

const OWNED = {
    "motion.preset": ["motion", "preset"], "motion.open": ["motion", "open"], "motion.reveal": ["motion", "reveal"], "motion.stagger": ["motion", "stagger"], "motion.springiness": ["motion", "springiness"],
    "bar.style": ["layout", "barStyle"], "bar.workspaceStyle": ["layout", "workspaceStyle"], "center.layout": ["layout", "center"], "notifications.stack": ["layout", "notifications"],
    "lock.face": ["layout", "lockFace"], "island.idle": ["layout", "islandIdle"], "deck.effect": ["layout", "deckEffect"], "deck.glow": ["layout", "deckGlow"], "pad.mode": ["layout", "padMode"],
    "paper.blur": ["atmosphere", "wallBlur"], "paper.dim": ["atmosphere", "wallDim"], "paper.tint": ["atmosphere", "wallTint"]
}

export const DEFAULT_LOOK = { preset: "lumen", followTheme: false, shuffle: "off", parts: {} }

function oneOf(list) {
    return v => list.includes(v)
}

function range(lo, hi) {
    return v => typeof v === "number" && isFinite(v) && v >= lo && v <= hi
}

function isBool(v) {
    return typeof v === "boolean"
}

function accentValue(v) {
    return ACCENTS.includes(v) || typeof v === "string" && /^#[0-9a-f]{6}$/i.test(v)
}

const RULES = {
    glass: { material: v => MATERIALS[v] !== undefined },
    shape: { corners: oneOf(CORNERS), radius: range(0, 2), density: v => DENSITY[v] !== undefined, border: range(0, 2) },
    type: { weight: oneOf(WEIGHTS), labelCase: oneOf(CASES), tracking: range(-0.02, 0.12), scale: range(0.9, 1.15) },
    controls: {},
    motion: { preset: oneOf(PRESETS), open: oneOf(OPEN_STYLES), reveal: oneOf(REVEALS), stagger: range(0, 0.9), springiness: v => v === -1 || range(0, 1)(v) },
    layout: {
        barStyle: oneOf(STYLES), workspaceStyle: oneOf(WORKSPACE_STYLES), center: oneOf(LAYOUTS), notifications: oneOf(STACKS), lockFace: oneOf(LOCK_FACES),
        islandIdle: oneOf(IDLE), deckEffect: oneOf(DECK_EFFECTS), deckGlow: isBool, padMode: oneOf(["launchpad", "list"])
    },
    atmosphere: { aurora: isBool, accent: accentValue, accentStrength: range(0, 1), wallBlur: range(0, 1), wallDim: range(0, 0.9), wallTint: range(0, 1) }
}
for (const key of GLASS_KEYS)
    RULES.glass[key] = v => glassValue(key, v)
for (const key of Object.keys(CONTROL_CHOICES))
    RULES.controls[key] = oneOf(CONTROL_CHOICES[key])

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function clone(v) {
    return JSON.parse(JSON.stringify(v))
}

function unit(v) {
    return typeof v === "number" && isFinite(v) && v >= 0 && v <= 1
}

function fontName(v) {
    return typeof v === "string" && v.trim() !== "" && v.length <= 80
}

function glassValue(key, v) {
    return typeof v === "number" && isFinite(v) && v >= 0 && v <= (key === "flow" ? 3 : 1)
}

function catalog(userLooks) {
    return Object.assign({}, LOOKS, isObject(userLooks) ? userLooks : {})
}

function deepMerge(base, over) {
    const out = clone(base)
    for (const key of Object.keys(over))
        out[key] = isObject(out[key]) && isObject(over[key]) ? deepMerge(out[key], over[key]) : clone(over[key])
    return out
}

function fromV1(raw) {
    const out = { glass: {}, shape: {}, type: {} }
    for (const key of ["material"].concat(GLASS_KEYS)) {
        if (raw[key] !== undefined)
            out.glass[key] = raw[key]
    }
    for (const key of ["corners", "radius", "density"]) {
        if (raw[key] !== undefined)
            out.shape[key] = raw[key]
    }
    if (raw.fonts !== undefined)
        out.type.fonts = raw.fonts
    if (raw.weight !== undefined)
        out.type.weight = raw.weight
    if (raw.settings !== undefined)
        out.legacy = raw.settings
    return out
}

export function validateStyle(raw) {
    if (!isObject(raw) || typeof raw.name !== "string" || raw.name.trim() === "")
        return null
    const src = typeof raw.version === "number" && raw.version >= 2 ? raw : fromV1(raw)
    const out = clone(LOOKS.classic)
    out.name = raw.name.slice(0, 40)
    for (const section of SECTIONS) {
        const sec = isObject(src[section]) ? src[section] : {}
        for (const key of Object.keys(sec)) {
            if (section === "type" && key === "fonts") {
                for (const f of FONT_KEYS) {
                    if (isObject(sec.fonts) && fontName(sec.fonts[f]))
                        out.type.fonts[f] = sec.fonts[f]
                }
            } else if (RULES[section][key] !== undefined && RULES[section][key](sec[key])) {
                out[section][key] = sec[key]
            }
        }
    }
    if (isObject(src.legacy) && Object.keys(src.legacy).length > 0)
        out.legacy = clone(src.legacy)
    return out
}

export function takeSection(style, section, from) {
    const out = clone(style)
    if (SECTIONS.includes(section) && isObject(from) && isObject(from[section]))
        out[section] = clone(from[section])
    return out
}

export function styleSettings(style) {
    const out = {}
    for (const path of Object.keys(OWNED)) {
        const [section, key] = OWNED[path]
        const v = isObject(style) && isObject(style[section]) ? style[section][key] : undefined
        if (v === undefined)
            continue
        const [part, leaf] = path.split(".")
        if (!isObject(out[part]))
            out[part] = {}
        out[part][leaf] = v
    }
    return isObject(style) && isObject(style.legacy) ? deepMerge(out, style.legacy) : out
}

export function originOf(id, userLooks) {
    const mine = isObject(userLooks) && userLooks[id] !== undefined
    if (LOOKS[id] !== undefined)
        return mine ? "edited" : "built-in"
    return mine ? "yours" : ""
}

export function configOwned(config) {
    return Object.keys(OWNED).filter(path => {
        const [part, leaf] = path.split(".")
        return isObject(config) && isObject(config[part]) && config[part][leaf] !== undefined
    })
}

function choice(key, title, options) {
    return { key: key, title: title, kind: "choice", options: options }
}

function number(key, title, min, max, step) {
    return { key: key, title: title, kind: "number", min: min, max: max, step: step }
}

function flag(key, title) {
    return { key: key, title: title, kind: "bool" }
}

const ROWS = {
    glass: [choice("material", "Material", Object.keys(MATERIALS))].concat(GLASS_KEYS.map(k => number(k, k.charAt(0).toUpperCase() + k.slice(1).replace("Opacity", " opacity"), 0, k === "flow" ? 3 : 1, 0.05))),
    shape: [choice("corners", "Corners", CORNERS), number("radius", "Roundness", 0, 2, 0.05), choice("density", "Spacing", Object.keys(DENSITY)), number("border", "Outline", 0, 2, 0.5)],
    type: [choice("weight", "Title weight", WEIGHTS), choice("labelCase", "Label case", CASES), number("tracking", "Letter spacing", -0.02, 0.12, 0.01), number("scale", "Text size", 0.9, 1.15, 0.05)],
    controls: [choice("toggle", "Switches", CONTROL_CHOICES.toggle), choice("slider", "Sliders", CONTROL_CHOICES.slider), choice("segmented", "Tabs", CONTROL_CHOICES.segmented), choice("button", "Buttons", CONTROL_CHOICES.button),
        choice("card", "Cards", CONTROL_CHOICES.card), choice("hover", "Hover", CONTROL_CHOICES.hover), choice("icon", "Icons", CONTROL_CHOICES.icon), choice("divider", "Dividers", CONTROL_CHOICES.divider)],
    motion: [choice("preset", "Feel", PRESETS), choice("open", "Opening", OPEN_STYLES), choice("reveal", "Reveal", REVEALS), number("stagger", "Stagger", 0, 0.9, 0.05), number("springiness", "Springiness", 0, 1, 0.05)],
    layout: [choice("barStyle", "Bar", STYLES), choice("workspaceStyle", "Workspaces", WORKSPACE_STYLES), choice("center", "Control Center", LAYOUTS), choice("notifications", "Notifications", STACKS),
        choice("lockFace", "Lock clock", LOCK_FACES), choice("islandIdle", "Island at rest", IDLE), choice("deckEffect", "Dock effect", DECK_EFFECTS), flag("deckGlow", "Dock glow"), choice("padMode", "Launcher", ["launchpad", "list"])],
    atmosphere: [flag("aurora", "Aurora"), choice("accent", "Accent from", ACCENTS), number("accentStrength", "Accent strength", 0, 1, 0.05), number("wallBlur", "Wallpaper blur", 0, 1, 0.05), number("wallDim", "Wallpaper dim", 0, 0.9, 0.05), number("wallTint", "Wallpaper tint", 0, 1, 0.05)]
}

export function styleRows(section) {
    return (ROWS[section] || []).map(r => {
        const path = Object.keys(OWNED).find(p => OWNED[p][0] === section && OWNED[p][1] === r.key)
        return Object.assign({}, r, { path: path || "" })
    })
}

export function styleFile(style) {
    const out = { version: 2, name: String(style.name).slice(0, 40) }
    for (const section of SECTIONS)
        out[section] = clone(style[section])
    if (isObject(style.legacy) && Object.keys(style.legacy).length > 0)
        out.legacy = clone(style.legacy)
    return out
}

function validPart(raw, errors, role) {
    const out = {}
    for (const key of Object.keys(raw)) {
        const v = raw[key]
        if (key === "material" && MATERIALS[v] !== undefined)
            out.material = v
        else if (key === "radius" && typeof v === "number" && v >= 0 && v <= 2)
            out.radius = v
        else if (GLASS_KEYS.includes(key) && glassValue(key, v))
            out[key] = v
        else
            errors.push("look.parts." + role + "." + key + " is not valid")
    }
    return out
}

export function validateLook(raw, userLooks) {
    const errors = []
    const values = clone(DEFAULT_LOOK)
    if (raw === undefined || raw === null)
        return { values: values, errors: errors }
    if (!isObject(raw)) {
        errors.push("look must be an object")
        return { values: values, errors: errors }
    }
    const looks = catalog(userLooks)
    for (const key of Object.keys(raw)) {
        const v = raw[key]
        let ok = true
        if (key === "preset") {
            ok = typeof v === "string" && looks[v] !== undefined
            if (ok)
                values.preset = v
        } else if (key === "followTheme") {
            ok = typeof v === "boolean"
            if (ok)
                values.followTheme = v
        } else if (key === "material") {
            ok = MATERIALS[v] !== undefined
        } else if (key === "corners") {
            ok = CORNERS.includes(v)
        } else if (key === "radius") {
            ok = typeof v === "number" && isFinite(v) && v >= 0 && v <= 2
        } else if (key === "density") {
            ok = DENSITY[v] !== undefined
        } else if (key === "weight") {
            ok = WEIGHTS.includes(v)
        } else if (LAYER_KEYS.includes(key)) {
            ok = unit(v)
        } else if (key === "accent") {
            ok = ACCENTS.includes(v) || typeof v === "string" && /^#[0-9a-f]{6}$/i.test(v)
        } else if (key === "aurora") {
            ok = typeof v === "boolean"
        } else if (key === "shuffle") {
            ok = v === "off" || v === "daily"
        } else if (key === "fonts") {
            ok = isObject(v)
            if (ok) {
                const fonts = {}
                for (const f of Object.keys(v)) {
                    if (FONT_KEYS.includes(f) && fontName(v[f]))
                        fonts[f] = v[f]
                    else
                        errors.push("look.fonts." + f + " must be a font name")
                }
                values.fonts = fonts
                continue
            }
        } else if (key === "parts") {
            ok = isObject(v)
            if (ok) {
                const parts = {}
                for (const role of Object.keys(v)) {
                    if (/^[a-z]+$/.test(role) && isObject(v[role]))
                        parts[role] = validPart(v[role], errors, role)
                    else
                        errors.push("look.parts." + role + " is not a part")
                }
                values.parts = parts
                continue
            }
        } else {
            errors.push("look." + key + " is not a look key")
            continue
        }
        if (!ok) {
            errors.push("look." + key + " is not valid")
            continue
        }
        if (key !== "preset" && key !== "followTheme")
            values[key] = v
    }
    return { values: values, errors: errors }
}

export function resolveLook(lk, glass, userLooks) {
    const l = isObject(lk) ? lk : {}
    const looks = catalog(userLooks)
    const base = looks[l.preset] !== undefined ? looks[l.preset] : LOOKS[DEFAULT_LOOK.preset]
    const material = l.material !== undefined ? l.material : base.glass.material
    const g = Object.assign({ enabled: true }, MATERIALS[material] !== undefined ? MATERIALS[material] : MATERIALS.lumen)
    for (const key of GLASS_KEYS) {
        if (base.glass[key] !== undefined)
            g[key] = base.glass[key]
        if (LAYER_KEYS.includes(key) && l[key] !== undefined)
            g[key] = l[key]
    }
    if (isObject(glass)) {
        for (const key of Object.keys(glass)) {
            if (key === "enabled" && typeof glass.enabled === "boolean" || GLASS_KEYS.includes(key) && glassValue(key, glass[key]))
                g[key] = glass[key]
        }
    }
    const corners = l.corners !== undefined ? l.corners : base.shape.corners
    const radius = l.radius !== undefined ? l.radius : base.shape.radius
    const density = l.density !== undefined ? l.density : base.shape.density
    return {
        preset: looks[l.preset] !== undefined ? l.preset : DEFAULT_LOOK.preset,
        name: base.name,
        material: material,
        glass: g,
        corners: corners,
        radius: corners === "sharp" ? radius * 0.25 : radius,
        density: DENSITY[density],
        densityName: density,
        border: base.shape.border,
        fonts: Object.assign({}, base.type.fonts, isObject(l.fonts) ? l.fonts : {}),
        weight: l.weight !== undefined ? l.weight : base.type.weight,
        labelCase: base.type.labelCase,
        tracking: base.type.tracking,
        textScale: base.type.scale,
        controls: clone(base.controls),
        accent: l.accent !== undefined ? l.accent : base.atmosphere.accent,
        accentStrength: base.atmosphere.accentStrength,
        aurora: typeof l.aurora === "boolean" ? l.aurora : base.atmosphere.aurora,
        parts: isObject(l.parts) ? l.parts : {}
    }
}

export function glassFor(resolved, role) {
    const p = isObject(resolved.parts) && isObject(resolved.parts[role]) ? resolved.parts[role] : null
    if (p === null)
        return Object.assign({}, resolved.glass, { radius: resolved.radius })
    const out = p.material !== undefined ? Object.assign({ enabled: resolved.glass.enabled }, MATERIALS[p.material]) : Object.assign({}, resolved.glass)
    for (const key of GLASS_KEYS) {
        if (p[key] !== undefined)
            out[key] = p[key]
    }
    out.radius = p.radius !== undefined ? p.radius : resolved.radius
    return out
}

export function lookDefaults(lk, userLooks) {
    const looks = catalog(userLooks)
    const id = isObject(lk) && looks[lk.preset] !== undefined ? lk.preset : DEFAULT_LOOK.preset
    return styleSettings(looks[id])
}

function dropPaths(raw, partial) {
    for (const key of Object.keys(partial)) {
        if (!isObject(raw) || raw[key] === undefined)
            continue
        if (isObject(partial[key]) && isObject(raw[key])) {
            dropPaths(raw[key], partial[key])
            if (Object.keys(raw[key]).length === 0)
                delete raw[key]
        } else {
            delete raw[key]
        }
    }
}

export function applyLook(raw, id, userLooks) {
    const out = isObject(raw) ? clone(raw) : {}
    const looks = catalog(userLooks)
    if (looks[id] === undefined)
        return out
    dropPaths(out, styleSettings(looks[id]))
    const prev = isObject(out.look) ? out.look : {}
    const next = { preset: id }
    if (typeof prev.followTheme === "boolean")
        next.followTheme = prev.followTheme
    if (prev.shuffle !== undefined)
        next.shuffle = prev.shuffle
    out.look = next
    if (isObject(out.glass)) {
        out.glass = typeof out.glass.enabled === "boolean" ? { enabled: out.glass.enabled } : {}
        if (Object.keys(out.glass).length === 0)
            delete out.glass
    }
    return out
}

export function pickFont(name, families, fallback) {
    const want = String(name).toLowerCase()
    for (const f of families) {
        if (String(f).toLowerCase() === want)
            return f
    }
    return fallback
}

export function scaled(base, scale) {
    return Math.max(0, Math.round(base * scale))
}

export function slugLook(name) {
    const s = String(name).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40).replace(/-+$/, "")
    return s === "" || LOOKS[s] !== undefined ? "" : s
}

export function validateUserLook(raw) {
    return validateStyle(raw)
}

export function lookFile(name, resolved, settings) {
    const s = {
        version: 2,
        name: String(name).slice(0, 40),
        glass: { material: resolved.material },
        shape: { corners: resolved.corners, radius: resolved.corners === "sharp" ? resolved.radius * 4 : resolved.radius, density: resolved.densityName, border: resolved.border },
        type: { fonts: clone(resolved.fonts), weight: resolved.weight, labelCase: resolved.labelCase, tracking: resolved.tracking, scale: resolved.textScale },
        controls: clone(resolved.controls),
        motion: {},
        layout: {},
        atmosphere: { aurora: resolved.aurora, accent: resolved.accent, accentStrength: resolved.accentStrength }
    }
    for (const key of LAYER_KEYS)
        s.glass[key] = resolved.glass[key]
    const rest = isObject(settings) ? clone(settings) : {}
    for (const path of Object.keys(OWNED)) {
        const [part, leaf] = path.split(".")
        const [section, key] = OWNED[path]
        if (isObject(rest[part]) && rest[part][leaf] !== undefined) {
            s[section][key] = rest[part][leaf]
            delete rest[part][leaf]
            if (Object.keys(rest[part]).length === 0)
                delete rest[part]
        }
    }
    s.legacy = rest
    return styleFile(validateStyle(s))
}

function n(v) {
    return String(Math.round(v * 100) / 100)
}

function toward(a, b, t) {
    return a + (b - a) * t
}

export function cornerPath(w, h, r, style) {
    if (!(w > 0 && h > 0))
        return ""
    const smooth = style === "squircle"
    const e = Math.max(0, Math.min(r * (smooth ? 1.4 : 0.6), w / 2, h / 2))
    const corner = (x1, y1, cx, cy, x2, y2) => {
        const start = " L " + n(x1) + " " + n(y1)
        if (!smooth)
            return start + " L " + n(x2) + " " + n(y2)
        return start + " C " + n(toward(x1, cx, 0.88)) + " " + n(toward(y1, cy, 0.88)) + " " + n(toward(x2, cx, 0.88)) + " " + n(toward(y2, cy, 0.88)) + " " + n(x2) + " " + n(y2)
    }
    return "M " + n(e) + " 0" + corner(w - e, 0, w, 0, w, e) + corner(w, h - e, w, h, w - e, h) + corner(e, h, 0, h, 0, h - e) + corner(0, e, 0, 0, e, 0) + " Z"
}

export function blurRadius(r, style) {
    return style === "squircle" ? r * 1.1 : style === "bevel" ? r * 1.05 : r
}

export function shufflePick(looks, themes, seed, avoid) {
    const skip = avoid || {}
    const pick = (list, salt, not) => {
        const from = list.length > 1 ? list.filter(x => x !== not) : list
        if (from.length === 0)
            return ""
        const x = Math.sin((seed + salt) * 12.9898) * 43758.5453
        return from[Math.floor((x - Math.floor(x)) * from.length)]
    }
    return { look: pick(looks, 1, skip.look), theme: pick(themes, 7, skip.theme) }
}

export function daySeed(day) {
    const m = String(day).match(/^(\d{4})-(\d{2})-(\d{2})$/)
    return m === null ? 0 : Number(m[1]) * 372 + Number(m[2]) * 31 + Number(m[3])
}
