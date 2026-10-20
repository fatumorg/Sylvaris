export const NAME = "virtual"

export const PRESETS = [
    { label: "iPad Pro 11″", width: 2388, height: 1668 },
    { label: "iPad Pro 13″", width: 2752, height: 2064 },
    { label: "iPad Air 11″", width: 2360, height: 1640 },
    { label: "1080p", width: 1920, height: 1080 }
]

export function presetLabel(width, height) {
    for (const p of PRESETS) {
        if (p.width === width && p.height === height)
            return p.label
    }
    return width + "×" + height
}

export function parseVnc(text) {
    const out = { username: "", password: "", port: 5900 }
    for (const line of String(text || "").split("\n")) {
        const i = line.indexOf("=")
        if (i < 0)
            continue
        const key = line.slice(0, i).trim()
        const value = line.slice(i + 1).trim()
        if (key === "username" || key === "password")
            out[key] = value
        else if (key === "port" && /^[0-9]+$/.test(value) && Number(value) > 0 && Number(value) < 65536)
            out.port = Number(value)
    }
    return out
}

export function parseAddresses(text) {
    const out = []
    for (const line of String(text || "").split("\n")) {
        const m = /\binet ([0-9.]+)\//.exec(line)
        if (m !== null)
            out.push(m[1])
    }
    return out
}

export function rightOf(snap, skip) {
    let x = 0
    for (const name of Object.keys(snap || {})) {
        const s = snap[name]
        if (name !== skip && s && s.enabled === true)
            x = Math.max(x, s.x + Math.round(s.width / s.scale))
    }
    return { x: x, y: 0 }
}
