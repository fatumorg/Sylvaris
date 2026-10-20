function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function num(v, fallback) {
    return typeof v === "number" && isFinite(v) ? v : fallback
}

export function parseOutputs(text, sizes) {
    let raw
    try {
        raw = JSON.parse(text)
    } catch (e) {
        return []
    }
    if (!Array.isArray(raw))
        return []
    const out = []
    for (const o of raw) {
        if (!isObject(o) || typeof o.name !== "string")
            continue
        const modes = Array.isArray(o.modes) ? o.modes.filter(isObject) : []
        let current = null
        for (const m of modes) {
            if (m.current === true)
                current = { width: m.width, height: m.height, refresh: m.refresh }
        }
        const size = isObject(sizes) && isObject(sizes[o.name]) ? sizes[o.name] : null
        if (current === null && o.enabled === true && size !== null && size.width > 0 && size.height > 0)
            current = { width: size.width, height: size.height, refresh: 60, custom: true }
        out.push({
            name: o.name,
            description: typeof o.description === "string" ? o.description : "",
            enabled: o.enabled === true,
            x: isObject(o.position) ? num(o.position.x, 0) : 0,
            y: isObject(o.position) ? num(o.position.y, 0) : 0,
            scale: num(o.scale, 1),
            transform: typeof o.transform === "string" ? o.transform : "normal",
            current: current,
            modes: modes.map(m => ({ width: m.width, height: m.height, refresh: m.refresh, preferred: m.preferred === true }))
        })
    }
    return out
}

export function layoutKey(outputs) {
    return outputs.map(o => o.name).sort().join("+")
}

export function snapshot(outputs) {
    const snap = {}
    for (const o of outputs) {
        if (o.enabled && o.current !== null) {
            snap[o.name] = {
                enabled: true, x: o.x, y: o.y, scale: o.scale,
                width: o.current.width, height: o.current.height, refresh: o.current.refresh
            }
            if (o.current.custom === true)
                snap[o.name].custom = true
        } else {
            snap[o.name] = { enabled: false }
        }
    }
    return snap
}

export function sameLayout(a, b) {
    const ka = Object.keys(a).sort()
    const kb = Object.keys(b).sort()
    if (ka.join("+") !== kb.join("+"))
        return false
    for (const key of ka) {
        const x = a[key]
        const y = b[key]
        if (x.enabled !== y.enabled)
            return false
        if (!x.enabled)
            continue
        if (x.x !== y.x || x.y !== y.y || x.width !== y.width || x.height !== y.height)
            return false
        if (Math.abs(x.scale - y.scale) > 0.001 || Math.abs(x.refresh - y.refresh) > 0.01)
            return false
    }
    return true
}

export function formatMode(width, height, refresh) {
    return width + "x" + height + "@" + Number(refresh).toFixed(3) + "Hz"
}

export function applyArgs(snap) {
    const args = []
    for (const name of Object.keys(snap).sort()) {
        const s = snap[name]
        if (s.enabled) {
            args.push("--output", name, "--on", s.custom === true ? "--custom-mode" : "--mode", formatMode(s.width, s.height, s.refresh),
                "--pos", s.x + "," + s.y, "--scale", String(s.scale))
        } else {
            args.push("--output", name, "--off")
        }
    }
    return args
}

export function uniqueModes(modes) {
    const seen = {}
    const out = []
    for (const m of modes) {
        const key = m.width + "x" + m.height + "@" + Number(m.refresh).toFixed(3)
        if (seen[key])
            continue
        seen[key] = true
        out.push(m)
    }
    return out.sort((a, b) => (b.width * b.height - a.width * a.height) || (b.refresh - a.refresh))
}

export function fitScale(snap, boxW, boxH, pad) {
    let minX = Infinity
    let minY = Infinity
    let maxX = -Infinity
    let maxY = -Infinity
    for (const name of Object.keys(snap)) {
        const s = snap[name]
        if (!s.enabled)
            continue
        minX = Math.min(minX, s.x)
        minY = Math.min(minY, s.y)
        maxX = Math.max(maxX, s.x + s.width / s.scale)
        maxY = Math.max(maxY, s.y + s.height / s.scale)
    }
    if (minX === Infinity)
        return { factor: 1, minX: 0, minY: 0 }
    const factor = Math.min((boxW - 2 * pad) / (maxX - minX), (boxH - 2 * pad) / (maxY - minY))
    return { factor: factor, minX: minX, minY: minY }
}

export function modeLabel(mode, modes) {
    const r = Math.round(mode.refresh)
    const clash = (modes || []).some(m => Math.abs(m.refresh - mode.refresh) > 0.001 && m.width === mode.width && m.height === mode.height && Math.round(m.refresh) === r)
    return mode.width + "×" + mode.height + " · " + (clash ? Number(mode.refresh).toFixed(2) : r) + " Hz"
}

export function canApply(snap) {
    if (snap === null || typeof snap !== "object")
        return false
    for (const name of Object.keys(snap)) {
        if (snap[name] && snap[name].enabled === true)
            return true
    }
    return false
}
