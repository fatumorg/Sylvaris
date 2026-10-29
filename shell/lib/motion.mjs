export function origin(corner) {
    const c = String(corner || "")
    const v = c.indexOf("top") === 0 ? 0 : c.indexOf("bottom") === 0 ? 1 : 0.5
    const h = c.indexOf("left") >= 0 ? 0 : c.indexOf("right") >= 0 ? 1 : 0.5
    return { h: h, v: v }
}

export function scaledRect(x, y, w, h, corner, s, dy) {
    const o = origin(corner)
    const nw = w * s
    const nh = h * s
    return { x: x + (w - nw) * o.h, y: y + (h - nh) * o.v + dy, w: nw, h: nh }
}

export function grow(phase, emerging) {
    return emerging ? 0.3 + 0.7 * phase : 0.94 + 0.06 * phase
}

export function rise(corner) {
    return origin(corner).v === 1 ? 1 : -1
}

export function stagger(phase, index, count, spread) {
    const n = Math.max(1, count)
    const s = Math.max(0, Math.min(0.9, spread === undefined ? 0.35 : spread))
    const start = s * index / n
    const t = (phase - start) / (1 - s)
    return Math.max(0, Math.min(1, t))
}

export const PRESETS = ["calm", "smooth", "snappy", "playful"]

const SMOOTH = {
    pace: 1,
    enter: [0.05, 0.7, 0.1, 1, 1, 1],
    exit: [0.3, 0, 0.8, 0.15, 1, 1],
    move: [0.2, 0, 0, 1, 1, 1],
    spring: [0.34, 1.4, 0.64, 1, 1, 1]
}

const TUNED = {
    calm: { pace: 1.35, enter: [0.25, 0.1, 0.25, 1, 1, 1], exit: [0.4, 0, 0.6, 1, 1, 1], move: [0.4, 0, 0.2, 1, 1, 1], spring: [0.3, 1.15, 0.6, 1, 1, 1] },
    snappy: { pace: 0.7, enter: [0.2, 0.9, 0.1, 1, 1, 1], exit: [0.4, 0, 1, 1, 1, 1], move: [0.3, 0, 0, 1, 1, 1], spring: [0.3, 1.25, 0.6, 1, 1, 1] },
    playful: { pace: 1.1, enter: [0.34, 1.32, 0.64, 1, 1, 1], exit: [0.36, 0, 0.66, -0.3, 1, 1], move: [0.34, 1.2, 0.64, 1, 1, 1], spring: [0.34, 1.6, 0.64, 1, 1, 1] }
}

export function presetTokens(name) {
    return Object.assign({}, SMOOTH, TUNED[name] || {})
}

export const REVEALS = ["edges", "center", "fade"]
export const OPEN_STYLES = ["grow", "morph", "drop", "unfold", "blur", "swing"]

const IDENTITY = { sx: 1, sy: 1, dx: 0, dy: 0, opacity: 1, blur: 0, angle: 0 }

function frame(o, ox, oy, parts) {
    return Object.assign({}, IDENTITY, { ox: ox, oy: oy }, parts)
}

export function openFrame(style, phase, corner, opts) {
    const p = Math.max(0, Math.min(1, phase))
    const q = 1 - p
    const o = origin(corner)
    const at = opts && opts.origin ? opts.origin : null
    const fade = Math.min(1, p * 1.6)
    if (opts && opts.reduced)
        return frame(o, o.h, o.v, { opacity: fade })
    if (style === "morph" && at !== null) {
        const s = 0.08 + 0.92 * p
        return frame(o, at.x, at.y, { sx: s, sy: s, opacity: Math.min(1, p * 2.2) })
    }
    if (style === "drop")
        return frame(o, o.h, o.v, { dy: q * 48 * rise(corner) || 0, opacity: Math.min(1, p * 1.4) })
    if (style === "unfold")
        return frame(o, o.h, o.v, { sy: 0.04 + 0.96 * p, opacity: Math.min(1, p * 3) })
    if (style === "blur") {
        const s = 0.97 + 0.03 * p
        return frame(o, o.h, o.v, { sx: s, sy: s, opacity: p, blur: q })
    }
    if (style === "swing") {
        const s = 0.96 + 0.04 * p
        return frame(o, o.h, o.v, { sx: s, sy: s, angle: q * 70 * rise(corner) || 0, opacity: fade })
    }
    const g = grow(p, !!(opts && opts.emerging))
    return frame(o, o.h, o.v, { sx: g, sy: g, dy: q * 10 * rise(corner) || 0, opacity: fade })
}

export function frameRect(x, y, w, h, f) {
    const sy = f.sy * Math.abs(Math.cos(f.angle * Math.PI / 180))
    const nw = w * f.sx
    const nh = h * sy
    return { x: x + (w - nw) * f.ox + f.dx, y: y + (h - nh) * f.oy + f.dy, w: nw, h: nh }
}

export function springCurve(k) {
    const t = Math.max(0, Math.min(1, k))
    return [0.34, 1 + 0.6 * t, 0.64, 1, 1, 1]
}

export function tapOrigin(tap, screen, panel, now) {
    if (tap === null || tap === undefined || now - tap.at > 800 || tap.screen !== screen.name || panel.w <= 0 || panel.h <= 0)
        return null
    const clamp = v => Math.max(0, Math.min(1, v))
    if (tap.w > screen.w / 2)
        return { x: clamp((tap.x + (screen.w - tap.w) / 2 - panel.x) / panel.w), y: panel.y + panel.h / 2 < screen.h / 2 ? 0 : 1 }
    return { x: panel.x + panel.w / 2 < screen.w / 2 ? 0 : 1, y: clamp((tap.y + (screen.h - tap.h) / 2 - panel.y) / panel.h) }
}

export function placedRect(corner, sw, sh, w, h, margin) {
    const o = origin(corner)
    return { x: o.h === 0 ? margin : o.h === 1 ? sw - margin - w : (sw - w) / 2, y: o.v === 0 ? margin : o.v === 1 ? sh - margin - h : (sh - h) / 2, w: w, h: h }
}
