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
