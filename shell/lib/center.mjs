export const LAYOUTS = ["grid", "bento"]

export const EXTRAS = [
    { key: "fatest", label: "Speed Test", glyph: "speed", plugin: "fatest" },
    { key: "airpods", label: "AirPods", glyph: "headphones", plugin: "airpods" },
    { key: "rgb", label: "Lighting", glyph: "rgb", plugin: "rgb" },
    { key: "awake", label: "Keep Awake", glyph: "eye", plugin: "awake" },
    { key: "screenshot", label: "Screenshot", glyph: "camera", plugin: "" },
    { key: "record", label: "Record", glyph: "record", plugin: "" },
    { key: "clip", label: "Clipboard", glyph: "clipboard", plugin: "" },
    { key: "lock", label: "Lock", glyph: "lock", plugin: "" }
]

export function offeredExtras(plugins) {
    const on = plugins !== null && typeof plugins === "object" && plugins.enabled !== null && typeof plugins.enabled === "object" ? plugins.enabled : {}
    return EXTRAS.filter(e => e.plugin === "" || on[e.plugin] === true)
}

const level = side => side !== null && typeof side === "object" && typeof side.level === "number" ? side.level : -1

export function airpodsLine(connected, battery) {
    if (!connected)
        return "Not connected"
    const b = battery || {}
    const parts = [["L", level(b.left)], ["R", level(b.right)]].filter(p => p[1] >= 0).map(p => p[0] + " " + p[1] + "%")
    return parts.length > 0 ? parts.join(" · ") : "Connected"
}

export function speedLine(phase, live, last) {
    if (phase === "download" || phase === "upload")
        return "Testing · " + Math.round(live) + " Mbps"
    if (phase === "server")
        return "Finding a server"
    if (phase === "saving")
        return "Saving"
    if (phase === "error")
        return "Failed"
    if (last === null || typeof last !== "object")
        return "Not run yet"
    return "↓ " + Math.round(last.download) + " · ↑ " + Math.round(last.upload) + " Mbps"
}

export function layoutBento(ids) {
    const out = ids.slice(0, 2).map((id, i) => ({ id: id, col: i * 3, row: 0, w: 3, h: 1, small: false }))
    const rest = ids.slice(2)
    rest.forEach((id, i) => {
        const row = Math.floor(i / 3)
        const w = 6 / Math.min(3, rest.length - row * 3)
        out.push({ id: id, col: (i % 3) * w, row: row + 1, w: w, h: 1, small: true })
    })
    return out
}
