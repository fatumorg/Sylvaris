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

export function layoutBento(ids, columns) {
    const cols = columns || 4
    const taken = []
    const out = []
    const free = (row, col, w) => {
        for (let c = col; c < col + w; c++) {
            if (c >= cols || (taken[row] && taken[row][c]))
                return false
        }
        return true
    }
    ids.forEach((id, i) => {
        const w = Math.min(cols, i < 2 ? 2 : 1)
        let row = 0
        let col = 0
        while (!free(row, col, w)) {
            col++
            if (col + w > cols) {
                col = 0
                row++
            }
        }
        taken[row] = taken[row] || []
        for (let c = col; c < col + w; c++)
            taken[row][c] = true
        out.push({ id: id, col: col, row: row, w: w, h: 1 })
    })
    return out
}
