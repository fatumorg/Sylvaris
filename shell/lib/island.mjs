import { elapsed } from "./capture.mjs"

export const DEFAULT_ISLAND = {
    media: true, recording: true, diver: true, volume: true, devices: true, notifications: false, messages: true, calls: true, pinCalls: true, privacy: true, status: true, keepPaused: true, hover: true, seconds: 5,
    position: "top-center", idle: "pill", reveal: "always", shortcuts: ["notify", "center", "media", "screenshot", "record", "dnd"],
    screens: "focused", hideSites: ["youtube.com", "youtu.be"]
}

export const SCREENS = ["focused", "all"]

export const POSITIONS = ["top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right"]
export const IDLE = ["hide", "pill", "clock"]
export const REVEAL = ["always", "hover"]
export const MAX_SHORTCUTS = 8

export const SHORTCUTS = {
    notify: { label: "Notifications", glyph: "bell", run: ["notify", "toggle"], needs: "notify" },
    center: { label: "Control Center", glyph: "toggle", run: ["center", "toggle"], needs: "center" },
    media: { label: "Media", glyph: "music", run: ["media", "open"], needs: "media" },
    clock: { label: "Calendar", glyph: "calendar", run: ["clock", "toggle"], needs: "clock" },
    pad: { label: "Launcher", glyph: "apps", run: ["pad", "toggle"], needs: "pad" },
    clip: { label: "Clipboard", glyph: "clipboard", run: ["clip", "toggle"], needs: "clip" },
    screenshot: { label: "Screenshot", glyph: "screenshot", run: ["capture", "shot", "region"], needs: "capture" },
    record: { label: "Record", glyph: "record", run: ["capture", "record", "region"], needs: "capture" },
    dnd: { label: "Do not disturb", glyph: "dnd", run: ["dnd", "toggle"], needs: "Dnd" },
    wifi: { label: "Wi-Fi", glyph: "wifi", run: ["wifi", "toggle"], needs: "NetworkService" },
    bluetooth: { label: "Bluetooth", glyph: "bluetooth", run: ["bluetooth", "toggle"], needs: "BluetoothService" },
    night: { label: "Night light", glyph: "nightLight", run: ["nightlight", "toggle"], needs: "NightLight" },
    settings: { label: "Settings", glyph: "settings", run: ["settings", "toggle"], needs: "settings" },
    power: { label: "Power", glyph: "power", run: ["power", "toggle"], needs: "power" },
    lock: { label: "Lock", glyph: "lock", run: ["lock", "now"], needs: "lock" },
    privacy: { label: "Privacy", glyph: "micOff", run: ["privacy", "toggle"], needs: "Audio" }
}

const FLASHES = { volume: "volume", notification: "notifications", message: "messages", device: "devices", status: "status", custom: null }

const STATUS = {
    dnd: { text: "Do not disturb", glyph: "dnd" },
    night: { text: "Night light", glyph: "nightLight" },
    performance: { text: "Performance mode", glyph: "performance" },
    wifi: { text: "Wi-Fi", glyph: "wifi", offGlyph: "wifiOff" },
    bluetooth: { text: "Bluetooth", glyph: "bluetooth", offGlyph: "bluetoothOff" },
    network: { text: "Network", glyph: "wifi", offGlyph: "wifiOff", on: "Connected", off: "Disconnected" },
    privacy: { text: "Mic and cameras", glyph: "mic", offGlyph: "micOff", on: "Off", off: "Back on" }
}

const SELF = /^\.?sylstack(-wrapped)?$/i

export const CHAT_APPS = [
    { id: "discord", label: "Discord", glyph: "speech", app: /discord|vesktop|vencord|webcord|armcord|legcord|equibop|dorion/i, web: /discord\.com/i },
    { id: "ferdium", label: "Ferdium", glyph: "speech", app: /ferdium|franz|rambox|station/i },
    { id: "signal", label: "Signal", glyph: "speech", app: /signal/i },
    { id: "telegram", label: "Telegram", glyph: "speech", app: /telegram|ayugram|kotatogram|64gram|materialgram|paper ?plane/i, web: /web\.telegram\.org/i },
    { id: "whatsapp", label: "WhatsApp", glyph: "speech", app: /whatsapp|zapzap|whatsie|karere|wasistlos/i, web: /web\.whatsapp\.com/i },
    { id: "messenger", label: "Messenger", glyph: "speech", app: /messenger|caprine/i, web: /messenger\.com|facebook\.com/i },
    { id: "instagram", label: "Instagram", glyph: "speech", app: /instagram/i, web: /instagram\.com/i },
    { id: "slack", label: "Slack", glyph: "speech", app: /slack/i, web: /app\.slack\.com/i },
    { id: "teams", label: "Teams", glyph: "speech", app: /teams/i, web: /teams\.(microsoft|live)\.com/i },
    { id: "matrix", label: "Matrix", glyph: "speech", app: /element|schildi|fractal|nheko|cinny|neochat|fluffychat|quaternion/i, web: /app\.element\.io/i },
    { id: "zoom", label: "Zoom", glyph: "voice", app: /zoom/i },
    { id: "mattermost", label: "Mattermost", glyph: "speech", app: /mattermost/i },
    { id: "rocketchat", label: "Rocket.Chat", glyph: "speech", app: /rocket\.?chat/i },
    { id: "zulip", label: "Zulip", glyph: "speech", app: /zulip/i },
    { id: "wire", label: "Wire", glyph: "speech", app: /^wire\b|wire desktop/i },
    { id: "session", label: "Session", glyph: "speech", app: /^session\b/i },
    { id: "simplex", label: "SimpleX", glyph: "speech", app: /simplex/i },
    { id: "threema", label: "Threema", glyph: "speech", app: /threema/i },
    { id: "viber", label: "Viber", glyph: "speech", app: /viber/i },
    { id: "beeper", label: "Beeper", glyph: "speech", app: /beeper/i },
    { id: "xmpp", label: "XMPP", glyph: "speech", app: /dino|gajim|kaidan|psi\+?/i },
    { id: "facetime", label: "FaceTime", glyph: "voice", app: /facetime/i, web: /facetime\.apple\.com/i },
    { id: "phone", label: "Phone", glyph: "voice", app: /kde ?connect|gsconnect|valent|phosh|calls|chatty/i },
    { id: "mail", label: "Mail", glyph: "bell", app: /thunderbird|betterbird|geary|evolution|mailspring|kmail|claws|mutt/i }
]

const BROWSERS = /firefox|chrom|brave|vivaldi|edge|opera|librewolf|zen|floorp|waterfox|epiphany|web$/i

export function validateIsland(raw) {
    const v = raw !== null && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
    const out = Object.assign({}, v)
    for (const key of Object.keys(DEFAULT_ISLAND))
        if (typeof DEFAULT_ISLAND[key] === "boolean")
            out[key] = typeof v[key] === "boolean" ? v[key] : DEFAULT_ISLAND[key]
    out.seconds = Number.isInteger(v.seconds) && v.seconds >= 1 && v.seconds <= 10 ? v.seconds : DEFAULT_ISLAND.seconds
    out.position = POSITIONS.includes(v.position) ? v.position : DEFAULT_ISLAND.position
    out.idle = IDLE.includes(v.idle) ? v.idle : DEFAULT_ISLAND.idle
    out.reveal = REVEAL.includes(v.reveal) ? v.reveal : DEFAULT_ISLAND.reveal
    out.screens = SCREENS.includes(v.screens) ? v.screens : DEFAULT_ISLAND.screens
    out.hideSites = Array.isArray(v.hideSites) ? [...new Set(v.hideSites.map(siteOf).filter(s => s !== ""))].slice(0, 20) : DEFAULT_ISLAND.hideSites.slice()
    out.shortcuts = Array.isArray(v.shortcuts) ? [...new Set(v.shortcuts.filter(id => Object.prototype.hasOwnProperty.call(SHORTCUTS, id)))].slice(0, MAX_SHORTCUTS) : DEFAULT_ISLAND.shortcuts.slice()
    return out
}

export function chatOf(n) {
    const who = String(n.appName || "") + " " + String(n.desktopEntry || "")
    const text = String(n.summary || "") + " " + String(n.body || "")
    const browser = BROWSERS.test(String(n.appName || "").trim()) || BROWSERS.test(String(n.desktopEntry || "").trim())
    return CHAT_APPS.find(a => browser ? a.web !== undefined && a.web.test(text) : a.app.test(who)) || null
}

const PLUMBING = /^(pipewire|pipewire-pulse|wireplumber|pulseaudio)$/i
const GENERIC = /^(WEBRTC VoiceEngine|Chromium input|RecordStream|ALSA Capture|PipeWire ALSA \[.*\])$/i
const RECORDERS = [
    { test: /^gsr([-_].*)?$|gpu-screen-recorder/i, name: "GPU Screen Recorder" },
    { test: /^obs(-studio)?$|^obs /i, name: "OBS Studio" }
]
export const VOICE_GRACE = 10000

function bare(name) {
    return String(name || "").trim().replace(/^\./, "").replace(/-wrapped$/, "")
}

function pretty(name) {
    const n = bare(name)
    return n === n.toLowerCase() ? n.charAt(0).toUpperCase() + n.slice(1) : n
}

export function ownerOf(props) {
    const p = props || {}
    const app = String(p["application.name"] || "").trim()
    const bin = bare(p["application.process.binary"])
    const node = String(p["node.name"] || "").trim()
    const flat = String(p["application.id"] || "").trim()
    const none = { name: "", chat: null, browser: false }
    if (SELF.test(bin) || SELF.test(app) || SELF.test(String(p["application.process.binary"] || "").trim()))
        return none
    const recorder = RECORDERS.find(r => [app, bin, node].some(x => x !== "" && r.test.test(x)))
    if (recorder)
        return { name: recorder.name, chat: null, browser: false }
    const chat = CHAT_APPS.find(a => a.app.test([app, bin, node, flat].join(" ")))
    if (chat)
        return { name: chat.label, chat: chat, browser: false }
    if (PLUMBING.test(bin))
        return none
    const alsa = /^ALSA plug-in \[(.+)\]$/.exec(app)
    const raw = alsa ? alsa[1] : app === "" || GENERIC.test(app) ? bin : app
    if (raw === "")
        return none
    return { name: pretty(raw), chat: null, browser: BROWSERS.test(raw) || BROWSERS.test(bin) }
}

export function nodeKind(node) {
    const n = node || {}
    const p = n.props || {}
    const cls = String(p["media.class"] || "")
    if (n.stream)
        return "stream"
    if (n.sink)
        return "monitor"
    if (cls.startsWith("Video/"))
        return "camera"
    if (!cls.startsWith("Audio/Source"))
        return "other"
    return p["device.id"] !== undefined || /^(alsa_input|bluez_input)\./.test(String(p["node.name"] || "")) ? "mic" : "virtual"
}

export function streamsOf(captures, links) {
    const feeds = {}
    for (const l of Array.isArray(links) ? links : [])
        (feeds[l.target] = feeds[l.target] || []).push(nodeKind(l.source))
    return (Array.isArray(captures) ? captures : []).map(c => {
        const p = c.props || {}
        const o = ownerOf(p)
        const kinds = feeds[c.id] || []
        const video = c.audio !== true
        const mic = !video && kinds.includes("mic")
        return { id: c.id, owner: o.name, chat: o.chat, browser: o.browser, video: video, mic: mic, monitor: p["stream.capture.sink"] === "true" || !mic && kinds.includes("monitor"), peak: p["stream.monitor"] === "true", muted: c.muted === true }
    })
}

export function voiceOf(streams) {
    const list = (Array.isArray(streams) ? streams : []).filter(s => !s.video && !s.monitor && !s.peak)
    const pack = (app, glyph, mine) => ({ app: app, glyph: glyph, ids: mine.map(s => s.id), muted: mine.every(s => s.muted === true) })
    for (const app of CHAT_APPS) {
        const mine = list.filter(s => s.chat && s.chat.id === app.id)
        if (mine.length > 0)
            return pack(app.label, app.glyph, mine)
    }
    const web = list.filter(s => s.browser)
    return web.length === 0 ? null : pack(web[0].owner, "voice", web.filter(s => s.owner === web[0].owner))
}

export function voiceWindow(windows, app) {
    const list = Array.isArray(windows) ? windows : []
    const chat = CHAT_APPS.find(c => c.label === app)
    const test = chat ? chat.app : new RegExp(String(app || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i")
    return list.find(w => app !== "" && test.test(String(w.appId || "") + " " + String(w.title || ""))) || null
}

export function nextSession(prev, voice, now) {
    if (voice !== null && voice !== undefined)
        return { app: voice.app, glyph: voice.glyph, ids: voice.ids, muted: voice.muted, since: prev && prev.app === voice.app ? prev.since : now, gone: 0 }
    if (!prev)
        return null
    if (prev.gone === 0)
        return Object.assign({}, prev, { ids: [], gone: now })
    return now - prev.gone < VOICE_GRACE ? prev : null
}

export function status(id, on, name) {
    const s = STATUS[id]
    if (s === undefined)
        return null
    return { kind: "status", id: id, on: on === true, text: name || s.text, glyph: on || s.offGlyph === undefined ? s.glyph : s.offGlyph, state: on ? s.on || "On" : s.off || "Off" }
}

export function inUse(streams, cameraUsers, skipIds) {
    const apps = []
    const skip = Array.isArray(skipIds) ? skipIds : []
    let mic = false
    let camera = false
    for (const s of Array.isArray(streams) ? streams : []) {
        if (s.owner === "" || s.peak || skip.includes(s.id) || !s.video && !s.mic)
            continue
        if (s.video)
            camera = true
        else
            mic = true
        if (!apps.includes(s.owner))
            apps.push(s.owner)
    }
    for (const name of Array.isArray(cameraUsers) ? cameraUsers : []) {
        camera = true
        if (!apps.some(a => a.toLowerCase() === String(name).toLowerCase()))
            apps.push(name)
    }
    return apps.length === 0 ? null : { apps: apps, mic: mic, camera: camera }
}

export function isCall(n) {
    const category = String(n.category || "")
    if (category !== "")
        return /^call(\.incoming)?$/.test(category)
    const text = String(n.summary || "") + " " + String(n.body || "")
    return !/missed|ended/i.test(text) && /incoming (voice |video |audio )?call|is calling|calling you|\bringing\b/i.test(text)
}

export function pickActions(actions) {
    const find = re => {
        const a = actions.find(x => x.identifier !== "default" && (re.test(x.text) || re.test(x.identifier)))
        return a ? a.identifier : ""
    }
    return { accept: find(/accept|answer|pick ?up|^join/i), decline: find(/decline|reject|hang ?up|ignore|busy/i), read: find(/mark.*read|^read$/i) }
}

export function activities(s, cfg) {
    const out = []
    if (cfg.calls && s.call)
        out.push(Object.assign({ kind: "call" }, s.call))
    if (cfg.calls && s.voice)
        out.push(Object.assign({ kind: "voice" }, s.voice))
    const f = s.flash
    if (f && f.kind in FLASHES && (FLASHES[f.kind] === null || cfg[FLASHES[f.kind]]) && !(f.kind === "status" && f.id === "privacy" && f.on && cfg.privacy))
        out.push(f)
    if (cfg.recording && s.recording && s.recording.on)
        out.push(Object.assign({ kind: "recording" }, s.recording))
    if (cfg.privacy && s.privacy)
        out.push(Object.assign({ kind: "privacy" }, s.privacy))
    else if (cfg.privacy && s.inuse)
        out.push(Object.assign({ kind: "inuse" }, s.inuse))
    if (cfg.diver && s.alarm)
        out.push(Object.assign({ kind: "alarm" }, s.alarm))
    if (cfg.diver && s.focus)
        out.push(Object.assign({ kind: "focus" }, s.focus))
    if (cfg.diver && s.next && s.next.mins <= 15)
        out.push(Object.assign({ kind: "next" }, s.next))
    if (cfg.media && s.media && (s.media.playing || cfg.keepPaused) && (s.media.title || s.media.artist) && !hiddenSite(s.media.url || "", cfg.hideSites || []))
        out.push(Object.assign({ kind: "media" }, s.media))
    return out
}

export function label(a) {
    switch (a.kind) {
    case "volume":
        return a.muted ? "Muted" : Math.round(a.value * 100) + "%"
    case "notification":
        return a.summary || a.app
    case "message":
        return a.sender || a.app
    case "call":
        return (a.sender || a.app) + " calling"
    case "voice":
        return a.app + " · " + (a.muted ? "muted" : elapsed(a.elapsed))
    case "device":
        return a.battery >= 0 ? a.name + " · " + a.battery + "%" : a.name
    case "recording":
        return a.started ? elapsed(a.elapsed) : "Starts in " + Math.max(1, Math.ceil(a.wait / 1000))
    case "alarm":
        return a.title
    case "focus":
        return elapsed(a.left)
    case "next":
        return a.mins <= 0 ? "now" : "in " + a.mins + "m"
    case "media":
        return a.title || a.artist
    case "privacy":
        return "Mic and cameras off"
    case "inuse":
        return a.apps.join(", ") + " · " + (a.mic && a.camera ? "mic and camera" : a.camera ? "camera" : "mic")
    case "status":
        return a.text + " " + a.state.toLowerCase()
    default:
        return a.text || ""
    }
}

export function joined(before, after) {
    const was = new Set(before.filter(d => d.connected).map(d => d.key))
    return after.find(d => d.connected && !was.has(d.key)) || null
}

export function custom(text) {
    const t = String(text === undefined || text === null ? "" : text).replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim().slice(0, 120)
    return t === "" ? null : { kind: "custom", text: t }
}

export function shortcutsFor(ids, live) {
    return ids.filter(id => live.includes(SHORTCUTS[id].needs)).map(id => Object.assign({ id: id }, SHORTCUTS[id]))
}

export function placeOf(position) {
    const [edge, side] = position.split("-")
    return { top: edge === "top", side: side }
}

export function rowHeight(kind) {
    return kind === "media" ? 108 : kind === "volume" ? 84 : 64
}

export function cardHeight(kinds, shortcuts) {
    const parts = kinds.map(rowHeight).concat(shortcuts ? [52] : [])
    return parts.length === 0 ? 0 : 24 + parts.reduce((a, b) => a + b, 0) + 6 * (parts.length - 1)
}

export function inCall(cfg, s) {
    return cfg.pinCalls === true && cfg.calls === true && !!(s.call || s.voice)
}

export function tucked(reveal, s) {
    return reveal === "hover" && !s.hot && !s.pinned && !s.alert
}

export function takes(n, cfg, critical) {
    if (isCall(n))
        return cfg.calls
    if (critical)
        return false
    return cfg.notifications || cfg.messages && chatOf(n) !== null
}

function siteOf(raw) {
    if (typeof raw !== "string")
        return ""
    const host = raw.trim().toLowerCase().replace(/^[a-z]+:\/\//, "").split("/")[0]
    return /^[a-z0-9-]+(\.[a-z0-9-]+)+$/.test(host) ? host : ""
}

export function hiddenSite(url, sites) {
    const m = /^https?:\/\/([^/:?#]+)/i.exec(String(url || ""))
    if (m === null)
        return false
    const host = m[1].toLowerCase()
    return sites.some(site => host === site || host === "www." + site || host === "m." + site)
}

export function ownsFocus(appId, desktopEntry, appName) {
    const id = String(appId || "").toLowerCase()
    if (id === "")
        return false
    const last = id.slice(id.lastIndexOf(".") + 1)
    return [desktopEntry, appName].some(n => {
        const name = String(n || "").toLowerCase()
        return name !== "" && (name === id || name === last)
    })
}
