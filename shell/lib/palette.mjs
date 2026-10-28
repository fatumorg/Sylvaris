import { DEFAULT_THEME, parseHex } from "./theme.mjs"

function clamp(v, lo, hi) {
    return Math.min(hi, Math.max(lo, v))
}

function hex2(n) {
    const s = clamp(Math.round(n), 0, 255).toString(16)
    return s.length === 1 ? "0" + s : s
}

function toHex(c) {
    return "#" + hex2(c.r) + hex2(c.g) + hex2(c.b)
}

function toHsl(c) {
    const r = c.r / 255, g = c.g / 255, b = c.b / 255
    const max = Math.max(r, g, b), min = Math.min(r, g, b)
    const l = (max + min) / 2
    const d = max - min
    if (d === 0)
        return { h: 0, s: 0, l: l }
    const s = d / (1 - Math.abs(2 * l - 1))
    const h = max === r ? ((g - b) / d + 6) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4
    return { h: h * 60, s: s, l: l }
}

function hsl(h, s, l) {
    const c = (1 - Math.abs(2 * l - 1)) * s
    const x = c * (1 - Math.abs((h / 60) % 2 - 1))
    const m = l - c / 2
    const k = Math.floor(((h % 360) + 360) % 360 / 60)
    const rgb = [[c, x, 0], [x, c, 0], [0, c, x], [0, x, c], [x, 0, c], [c, 0, x]][k]
    return toHex({ r: (rgb[0] + m) * 255, g: (rgb[1] + m) * 255, b: (rgb[2] + m) * 255 })
}

function luminance(hex) {
    const c = parseHex(hex)
    const ch = v => {
        const x = v / 255
        return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
}

export function contrast(a, b) {
    const la = luminance(a), lb = luminance(b)
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

function readable(h, s, l, bg, ratio) {
    const up = luminance(bg) < 0.18
    let v = l
    for (let i = 0; i < 60 && contrast(hsl(h, s, v), bg) < ratio; i++)
        v = clamp(v + (up ? 0.02 : -0.02), 0, 1)
    return hsl(h, s, v)
}

function average(box) {
    const sum = [0, 0, 0]
    for (const p of box) {
        sum[0] += p[0]
        sum[1] += p[1]
        sum[2] += p[2]
    }
    return { r: Math.round(sum[0] / box.length), g: Math.round(sum[1] / box.length), b: Math.round(sum[2] / box.length), n: box.length }
}

function widest(box) {
    let best = { ch: 0, range: 0 }
    for (let ch = 0; ch < 3; ch++) {
        let lo = 255, hi = 0
        for (const p of box) {
            lo = Math.min(lo, p[ch])
            hi = Math.max(hi, p[ch])
        }
        if (hi - lo > best.range)
            best = { ch: ch, range: hi - lo }
    }
    return best
}

function cut(box, ch) {
    box.sort((a, b) => a[ch] - b[ch])
    const mid = box.length >> 1
    for (let d = 0; d < box.length; d++) {
        for (const i of [mid - d, mid + d]) {
            if (i > 0 && i < box.length && box[i - 1][ch] !== box[i][ch])
                return i
        }
    }
    return mid
}

export function quantize(rgba, count) {
    const px = []
    for (let i = 0; i + 3 < rgba.length; i += 4) {
        if (rgba[i + 3] >= 128)
            px.push([rgba[i], rgba[i + 1], rgba[i + 2]])
    }
    if (px.length === 0)
        return []
    const boxes = [px]
    while (boxes.length < count) {
        let pick = -1, best = null
        for (let i = 0; i < boxes.length; i++) {
            const w = widest(boxes[i])
            if (w.range > 0 && (best === null || w.range > best.range)) {
                pick = i
                best = w
            }
        }
        if (pick < 0)
            break
        const box = boxes[pick]
        const at = cut(box, best.ch)
        boxes.splice(pick, 1, box.slice(0, at), box.slice(at))
    }
    return boxes.map(average).sort((a, b) => b.n - a.n)
}

function accentOf(colors) {
    const total = colors.reduce((s, c) => s + c.n, 0) || 1
    let pick = null, score = -1
    for (const c of colors) {
        const h = toHsl(c)
        const v = h.s * (1 - Math.abs(h.l - 0.55)) * Math.sqrt(c.n / total)
        if (v > score) {
            score = v
            pick = h
        }
    }
    return pick
}

function accentSet(a, dark) {
    const s = clamp(a.s, 0, 0.85)
    const l = dark ? clamp(a.l, 0.55, 0.72) : clamp(a.l, 0.36, 0.5)
    const accent = hsl(a.h, s, l)
    const white = contrast(accent, "#ffffff") >= contrast(accent, "#000000")
    return {
        accent: accent,
        accentHi: hsl(a.h, s, clamp(l + 0.12, 0, 0.88)),
        accentDeep: hsl(a.h, s, clamp(l - 0.14, 0.2, 1)),
        onAccent: readable(a.h, Math.min(s, 0.3), white ? 0.95 : 0.08, accent, 4.5)
    }
}

export function themeFromPalette(colors, dark) {
    const dom = colors.length > 0 ? toHsl(colors[0]) : { h: 165, s: 0.2, l: 0.5 }
    const a = accentOf(colors) || dom
    const h = dom.h, s = Math.min(dom.s, 0.3) * (dark ? 0.6 : 0.4)
    const base = hsl(h, s, dark ? 0.08 : 0.95)
    const t = Math.min(s, 0.15)
    return {
        id: "wall",
        name: "Wallpaper",
        colors: Object.assign({
            base: base,
            surface: hsl(h, s, dark ? 0.13 : 0.985),
            text: readable(h, t, dark ? 0.9 : 0.12, base, 7),
            textDim: readable(h, t, dark ? 0.62 : 0.42, base, 4.5),
            textSoft: readable(h, t, dark ? 0.78 : 0.28, base, 4.5),
            danger: readable(6, 0.7, dark ? 0.62 : 0.45, base, 3)
        }, accentSet(a, dark))
    }
}

export function wallId(path) {
    let h = 0x811c9dc5
    const s = String(path)
    for (let i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i)
        h = Math.imul(h, 0x01000193) >>> 0
    }
    return "wall-" + ("0000000" + h.toString(16)).slice(-8)
}

export function wallTheme(path, rgba, mode) {
    const colors = quantize(rgba, 8)
    const total = colors.reduce((s, c) => s + c.n, 0) || 1
    const light = colors.reduce((s, c) => s + toHsl(c).l * c.n, 0) / total
    const dark = mode === "dark" || mode !== "light" && light < 0.6
    const file = String(path).split("/").pop()
    const name = file.replace(/\.[^.]+$/, "") || "Wallpaper"
    return {
        version: 1,
        id: wallId(path),
        name: name,
        description: "Made from " + file,
        wallpaper: String(path),
        colors: themeFromPalette(colors, dark).colors,
        alpha: Object.assign({}, DEFAULT_THEME.alpha)
    }
}

export function accentFrom(rgba) {
    const a = accentOf(quantize(rgba, 8))
    return a === null ? "" : hsl(a.h, a.s, a.l)
}

export function withAccent(theme, hex) {
    const c = parseHex(hex)
    if (c === null)
        return theme
    const colors = Object.assign({}, theme.colors, accentSet(toHsl(c), luminance(theme.colors.base) < 0.18))
    return Object.assign({}, theme, { colors: colors })
}
