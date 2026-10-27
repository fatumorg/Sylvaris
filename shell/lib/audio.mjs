import { ownerOf } from "./island.mjs"

export function bluezCardName(address) {
    return "bluez_card." + String(address).toUpperCase().replace(/:/g, "_")
}

export function parseCards(text) {
    try {
        const raw = JSON.parse(text)
        return Array.isArray(raw) ? raw : []
    } catch (e) {
        return []
    }
}

export function profileKind(name) {
    if (typeof name !== "string")
        return "off"
    if (name.indexOf("a2dp") === 0)
        return "hifi"
    if (name.indexOf("headset") === 0)
        return "headset"
    return "off"
}

export function profileLabel(kind) {
    if (kind === "hifi")
        return "Hi-Fi (A2DP)"
    if (kind === "headset")
        return "Headset (HFP)"
    return "Off"
}

function pick(profiles, preferred, prefix) {
    const usable = key => profiles[key] && profiles[key].available !== false
    if (usable(preferred))
        return preferred
    for (const key of Object.keys(profiles).sort()) {
        if (key.indexOf(prefix) === 0 && usable(key))
            return key
    }
    return ""
}

export function cardProfile(cards, address) {
    const name = bluezCardName(address)
    let card = null
    for (const c of cards) {
        if (c && c.name === name)
            card = c
    }
    if (card === null)
        return null
    const profiles = card.profiles && typeof card.profiles === "object" ? card.profiles : {}
    const kind = profileKind(card.active_profile)
    const next = kind === "hifi" ? pick(profiles, "headset-head-unit", "headset") : pick(profiles, "a2dp-sink", "a2dp")
    return { card: name, active: card.active_profile, kind: kind, label: profileLabel(kind), next: next }
}

export function streamName(app, fallback) {
    const alsa = /^PipeWire ALSA \[(.*)\]$/.exec(app || "")
    const name = (alsa ? alsa[1] : app || "").replace(/^\.(.*)-wrapped$/, "$1")
    return name || fallback
}

const STREAM_KINDS = { "Stream/Output/Audio": "play", "Stream/Input/Audio": "record" }

export function appStreams(nodes, links) {
    const outOf = {}
    const inOf = {}
    for (const l of links) {
        if (outOf[l.source] === undefined)
            outOf[l.source] = l.target
        if (inOf[l.target] === undefined)
            inOf[l.target] = l.source
    }
    const out = []
    for (const n of nodes) {
        const kind = STREAM_KINDS[n.cls]
        const p = n.props || {}
        if (kind === undefined || !p["application.name"] && !p["application.process.binary"])
            continue
        const app = ownerOf(p).name || streamName(p["application.name"], n.name)
        const title = String(p["media.name"] || "").trim()
        const device = kind === "play" ? outOf[n.id] : inOf[n.id]
        out.push({ key: String(n.id), kind: kind, app: app, title: title.toLowerCase() === app.toLowerCase() ? "" : title, volume: n.volume, muted: n.muted, device: device === undefined ? null : device, live: true })
    }
    return out
}

export function withIdle(live, seen) {
    const next = Object.assign({}, seen)
    const playing = {}
    for (const r of live) {
        const key = r.kind + ":" + r.app
        playing[key] = true
        next[key] = Object.assign({}, r, { key: key, title: "", device: null, live: false })
    }
    const idle = Object.keys(next).filter(k => !playing[k]).sort().map(k => next[k])
    return { rows: live.concat(idle), seen: next }
}
