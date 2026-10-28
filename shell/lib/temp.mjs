export const FALLBACK = { cpu: [75, 90], gpu: [75, 90], mobo: [60, 80], storage: [50, 65], other: [60, 80] }
export const SHOWS = ["off", "toggle", "fullscreen", "apps"]
export const STYLES = ["compact", "card", "bars", "graph"]
export const OVERLAY_CORNERS = ["top-left", "top-right", "bottom-left", "bottom-right"]

export const DEFAULT_TEMP = {
    interval: 1,
    overlay: { show: "off", apps: [], corner: "top-left", x: 16, y: 16, scale: 1, opacity: 0.85, style: "compact" },
    alerts: true,
    cooldown: 300,
    pinned: []
}

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function num(v, lo, hi, fallback) {
    return typeof v === "number" && Number.isFinite(v) ? Math.max(lo, Math.min(hi, v)) : fallback
}

function strings(v) {
    return Array.isArray(v) ? v.filter(x => typeof x === "string") : []
}

export function validateTemp(raw) {
    const r = isObject(raw) ? raw : {}
    const o = isObject(r.overlay) ? r.overlay : {}
    const d = DEFAULT_TEMP
    return {
        interval: num(r.interval, 0.2, 60, d.interval),
        overlay: {
            show: SHOWS.includes(o.show) ? o.show : d.overlay.show,
            apps: strings(o.apps),
            corner: OVERLAY_CORNERS.includes(o.corner) ? o.corner : d.overlay.corner,
            x: num(o.x, 0, 4000, d.overlay.x),
            y: num(o.y, 0, 4000, d.overlay.y),
            scale: num(o.scale, 0.5, 3, d.overlay.scale),
            opacity: num(o.opacity, 0.1, 1, d.overlay.opacity),
            style: STYLES.includes(o.style) ? o.style : d.overlay.style
        },
        alerts: r.alerts !== false,
        cooldown: num(r.cooldown, 10, 86400, d.cooldown),
        pinned: strings(r.pinned)
    }
}

function sensorOk(s) {
    return isObject(s) && typeof s.label === "string" && typeof s.value === "number" && Number.isFinite(s.value)
}

export function parseLine(text) {
    let v
    try {
        v = JSON.parse(String(text))
    } catch (e) {
        return null
    }
    if (!isObject(v) || typeof v.time !== "number" || !Array.isArray(v.sensors))
        return null
    return { time: v.time, sensors: v.sensors.filter(sensorOk).map(normalize) }
}

export function parseLegacy(text) {
    let v
    try {
        v = JSON.parse(String(text))
    } catch (e) {
        return null
    }
    return Array.isArray(v) ? v.filter(sensorOk).map(normalize) : null
}

function normalize(s) {
    return {
        group: typeof s.group === "string" ? s.group : "",
        label: s.label,
        value: s.value,
        unit: typeof s.unit === "string" ? s.unit : "",
        kind: typeof s.kind === "string" ? s.kind : "other",
        device: typeof s.device === "string" ? s.device : "",
        warn: typeof s.warn === "number" ? s.warn : null,
        hot: typeof s.hot === "number" ? s.hot : null
    }
}

export function sensorId(s) {
    return (s.device || s.group) + "/" + s.label
}

function celsius(s) {
    return s.unit === "°C" || s.unit === "C"
}

export function limits(s) {
    const f = FALLBACK[s.kind] || FALLBACK.other
    return [typeof s.warn === "number" ? s.warn : f[0], typeof s.hot === "number" ? s.hot : f[1]]
}

export function level(s) {
    if (!celsius(s))
        return "none"
    const [warn, hot] = limits(s)
    return s.value >= hot ? "hot" : s.value >= warn ? "warm" : "cool"
}

export function headroom(s) {
    if (!celsius(s))
        return 0
    return Math.max(0, Math.min(1, s.value / limits(s)[1]))
}

export function headline(sensors) {
    const hot = sensors.filter(celsius)
    const out = []
    const cpus = hot.filter(s => s.kind === "cpu")
    const cpu = cpus.find(s => /tctl|package/i.test(s.label)) || cpus[0]
    if (cpu)
        out.push(cpu)
    const gpus = {}
    for (const s of hot.filter(s => s.kind === "gpu")) {
        const key = s.device || s.group
        if (gpus[key] === undefined || /edge|core|gpu/i.test(s.label) && !/edge|core|gpu/i.test(gpus[key].label))
            gpus[key] = s
    }
    for (const key of Object.keys(gpus))
        out.push(gpus[key])
    const drives = hot.filter(s => s.kind === "storage").sort((a, b) => b.value - a.value)
    if (drives.length > 0)
        out.push(drives[0])
    return out
}

export function devices(sensors) {
    const order = ["cpu", "gpu", "mobo", "storage", "other"]
    const groups = {}
    for (const s of sensors) {
        const key = s.device || s.group || s.kind
        if (groups[key] === undefined)
            groups[key] = { name: key, kind: s.kind, sensors: [] }
        groups[key].sensors.push(s)
    }
    return Object.keys(groups).map(k => groups[k]).sort((a, b) => (order.indexOf(a.kind) + 9) % 9 - (order.indexOf(b.kind) + 9) % 9)
}

export function pushHistory(hist, sensors, max) {
    const cap = max === undefined ? 120 : max
    const out = Object.assign({}, hist)
    for (const s of sensors) {
        const id = sensorId(s)
        out[id] = (out[id] || []).concat([s.value]).slice(-cap)
    }
    return out
}

export function peaks(old, sensors) {
    const out = Object.assign({}, old)
    for (const s of sensors) {
        const id = sensorId(s)
        if (out[id] === undefined || s.value > out[id])
            out[id] = s.value
    }
    return out
}

export function alerts(state, sensors, now, cooldown) {
    const next = Object.assign({}, state)
    const fire = []
    for (const s of sensors.filter(celsius)) {
        const id = sensorId(s)
        const [warn, hot] = limits(s)
        const st = next[id] || { armed: true, last: -Infinity }
        if (s.value < warn)
            next[id] = { armed: true, last: st.last }
        else if (s.value >= hot && st.armed && now - st.last >= cooldown * 1000) {
            fire.push(s)
            next[id] = { armed: false, last: now }
        } else
            next[id] = st
    }
    return { state: next, fire: fire }
}

export function overlayShown(cfg, focused, toggled) {
    const f = focused || {}
    if (cfg.show === "toggle")
        return toggled === true
    if (cfg.show === "fullscreen")
        return f.fullscreen === true
    if (cfg.show === "apps") {
        return (cfg.apps || []).some(p => {
            try {
                return new RegExp("^(?:" + p + ")$").test(String(f.class || ""))
            } catch (e) {
                return false
            }
        })
    }
    return false
}

export function streams(versionText) {
    const m = /(\d+)\.(\d+)/.exec(String(versionText || ""))
    return m !== null && (Number(m[1]) > 0 || Number(m[2]) >= 3)
}

export function picked(sensors, pinned) {
    const mine = (pinned || []).map(id => sensors.find(s => sensorId(s) === id)).filter(s => s !== undefined)
    return mine.length > 0 ? mine : headline(sensors)
}

export function hottest(sensors) {
    const order = ["none", "cool", "warm", "hot"]
    return sensors.filter(s => level(s) !== "none").reduce((a, s) => a === null || order.indexOf(level(s)) > order.indexOf(level(a)) || level(s) === level(a) && headroom(s) > headroom(a) ? s : a, null)
}

export function short(s) {
    return (s.kind === "cpu" ? "CPU" : s.kind === "gpu" ? "GPU" : s.kind === "storage" ? "SSD" : s.label) + " " + Math.round(s.value) + (s.unit === "°C" || s.unit === "C" ? "°" : " " + s.unit)
}

export function backoff(n) {
    return Math.min(60000, 1000 * Math.pow(2, Math.max(0, n)))
}

export function compact(sensors) {
    return headline(sensors).map(short).join(" · ")
}
