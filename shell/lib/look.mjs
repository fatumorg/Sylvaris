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
export const WEIGHTS = ["light", "regular", "medium"]
export const ACCENTS = ["theme", "wallpaper"]

const GLASS_KEYS = ["opacity", "layerOpacity", "tint", "sheen", "flow", "rim", "grain", "highlight", "glow", "shadow"]
const LAYER_KEYS = ["shadow", "grain", "highlight", "glow"]
const FONT_KEYS = ["ui", "mono", "display"]
const MONO = "JetBrainsMono Nerd Font"

function look(name, material, corners, radius, density, fonts, weight, settings) {
    return { name: name, material: material, corners: corners, radius: radius, density: density, fonts: fonts, weight: weight, settings: settings }
}

export const LOOKS = {
    lumen: look("Lumen", "lumen", "squircle", 1.15, "cozy", { ui: "Inter", mono: MONO, display: "Inter Display" }, "medium", { motion: { open: "morph" }, bar: { style: "float", workspaceStyle: "dots" }, center: { layout: "bento" }, notifications: { stack: "cards" }, lock: { face: "giant" }, deck: { glow: true } }),
    classic: look("Classic", "resin", "round", 1, "cozy", { ui: "Inter", mono: MONO, display: "Inter" }, "regular", {}),
    frost: look("Frost", "frost", "round", 1.3, "roomy", { ui: "Inter", mono: MONO, display: "Inter Display" }, "light", {}),
    ink: look("Ink", "ink", "round", 0.6, "compact", { ui: "Inter", mono: MONO, display: "Inter Display" }, "medium", {}),
    neon: look("Neon", "neon", "bevel", 0.8, "cozy", { ui: "Inter", mono: MONO, display: MONO }, "medium", {}),
    paper: look("Paper", "paper", "round", 0.7, "roomy", { ui: "Inter", mono: MONO, display: "DejaVu Serif" }, "regular", {})
}

export const DEFAULT_LOOK = { preset: "lumen", followTheme: false, shuffle: "off", parts: {} }

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
    return Object.assign({}, isObject(userLooks) ? userLooks : {}, LOOKS)
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
    const material = l.material !== undefined ? l.material : base.material
    const g = Object.assign({ enabled: true }, MATERIALS[material] !== undefined ? MATERIALS[material] : MATERIALS.lumen)
    for (const key of LAYER_KEYS) {
        if (base[key] !== undefined)
            g[key] = base[key]
        if (l[key] !== undefined)
            g[key] = l[key]
    }
    if (isObject(glass)) {
        for (const key of Object.keys(glass)) {
            if (key === "enabled" && typeof glass.enabled === "boolean" || GLASS_KEYS.includes(key) && glassValue(key, glass[key]))
                g[key] = glass[key]
        }
    }
    const corners = l.corners !== undefined ? l.corners : base.corners
    const radius = l.radius !== undefined ? l.radius : base.radius
    const density = l.density !== undefined ? l.density : base.density
    return {
        preset: looks[l.preset] !== undefined ? l.preset : DEFAULT_LOOK.preset,
        name: base.name,
        material: material,
        glass: g,
        corners: corners,
        radius: corners === "sharp" ? radius * 0.25 : radius,
        density: DENSITY[density],
        densityName: density,
        fonts: Object.assign({}, base.fonts, isObject(l.fonts) ? l.fonts : {}),
        weight: l.weight !== undefined ? l.weight : base.weight,
        accent: l.accent !== undefined ? l.accent : "theme",
        aurora: typeof l.aurora === "boolean" ? l.aurora : material !== "resin",
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
    return isObject(looks[id].settings) ? clone(looks[id].settings) : {}
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
    dropPaths(out, isObject(looks[id].settings) ? looks[id].settings : {})
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
    if (!isObject(raw) || typeof raw.name !== "string" || raw.name.trim() === "")
        return null
    const base = LOOKS.classic
    const out = clone(base)
    out.name = raw.name.slice(0, 40)
    if (MATERIALS[raw.material] !== undefined)
        out.material = raw.material
    if (CORNERS.includes(raw.corners))
        out.corners = raw.corners
    if (typeof raw.radius === "number" && raw.radius >= 0 && raw.radius <= 2)
        out.radius = raw.radius
    if (DENSITY[raw.density] !== undefined)
        out.density = raw.density
    if (WEIGHTS.includes(raw.weight))
        out.weight = raw.weight
    if (isObject(raw.fonts)) {
        for (const f of FONT_KEYS) {
            if (fontName(raw.fonts[f]))
                out.fonts[f] = raw.fonts[f]
        }
    }
    for (const key of LAYER_KEYS) {
        if (unit(raw[key]))
            out[key] = raw[key]
    }
    out.settings = isObject(raw.settings) ? clone(raw.settings) : {}
    return out
}

export function lookFile(name, resolved, settings) {
    const out = {
        name: String(name).slice(0, 40),
        material: resolved.material,
        corners: resolved.corners,
        radius: resolved.corners === "sharp" ? resolved.radius * 4 : resolved.radius,
        density: resolved.densityName,
        fonts: clone(resolved.fonts),
        weight: resolved.weight,
        settings: isObject(settings) ? clone(settings) : {}
    }
    for (const key of LAYER_KEYS)
        out[key] = resolved.glass[key]
    return out
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
