export const KINDS = ["bar", "panel", "service"]
export const DEFAULT_PLUGINS = { enabled: {}, config: {} }
const ID = /^[a-z0-9][a-z0-9-]{0,39}$/

export function isPluginModule(name) {
    return typeof name === "string" && name.indexOf("plugin:") === 0 && ID.test(name.slice(7))
}

export function checkManifest(m, folder) {
    const fail = error => ({ ok: false, error: error, manifest: null })
    if (m === null || typeof m !== "object" || Array.isArray(m))
        return fail("plugin.json must be an object")
    if (typeof m.id !== "string" || !ID.test(m.id))
        return fail("id must be lowercase letters, digits and dashes")
    if (m.id !== folder)
        return fail("id " + m.id + " does not match its folder " + folder)
    if (typeof m.name !== "string" || m.name.trim() === "")
        return fail("name is required")
    if (KINDS.indexOf(m.kind) < 0)
        return fail("kind must be one of " + KINDS.join(", "))
    if (typeof m.entry !== "string" || !/^[A-Za-z0-9_-]+(\/[A-Za-z0-9_-]+)*\.qml$/.test(m.entry))
        return fail("entry must be a .qml file inside the plugin folder")
    return { ok: true, error: "", manifest: m }
}

export function parseScan(blob) {
    const out = []
    for (const chunk of String(blob || "").split(/^@@/m).filter(c => c.trim() !== "")) {
        const nl = chunk.indexOf("\n")
        const dir = (nl < 0 ? chunk : chunk.slice(0, nl)).trim().replace(/\/$/, "")
        const folder = dir.split("/").pop()
        const body = nl < 0 ? "" : chunk.slice(nl + 1).trim()
        if (body === "") {
            out.push({ dir: dir, id: folder, ok: false, error: "plugin.json is missing", manifest: null })
            continue
        }
        let parsed
        try {
            parsed = JSON.parse(body)
        } catch (e) {
            out.push({ dir: dir, id: folder, ok: false, error: "plugin.json is not valid JSON", manifest: null })
            continue
        }
        out.push(Object.assign({ dir: dir, id: folder }, checkManifest(parsed, folder)))
    }
    return out
}

export function skeleton(id, kind) {
    const manifest = { id: id, name: id.split("-").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" "), version: "0.1.0", kind: kind, entry: "Plugin.qml", description: "", author: "" }
    const qml = [
        "import QtQuick",
        "import qs",
        "import qs.services",
        "import qs.components",
        "",
        "Item {",
        "    id: root",
        "",
        "    property var api: null",
        "",
        "    implicitWidth: label.implicitWidth + 20",
        "    implicitHeight: Tokens.barItemHeight",
        "",
        "    Text {",
        "        id: label",
        "        anchors.centerIn: parent",
        "        textFormat: Text.PlainText",
        "        text: \"Hello from " + id + "\"",
        "        color: Theme.text",
        "        font.family: Tokens.fontUi",
        "        font.pixelSize: Tokens.barText",
        "    }",
        "}",
        ""
    ].join("\n")
    return { "plugin.json": JSON.stringify(manifest, null, 2) + "\n", "Plugin.qml": qml }
}

export function validatePlugins(raw) {
    const v = raw !== null && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
    const enabled = {}
    const src = v.enabled !== null && typeof v.enabled === "object" ? v.enabled : {}
    for (const id of Object.keys(src))
        if (ID.test(id) && typeof src[id] === "boolean")
            enabled[id] = src[id]
    const config = v.config !== null && typeof v.config === "object" && !Array.isArray(v.config) ? v.config : {}
    return Object.assign({}, v, { enabled: enabled, config: config })
}

export const INSTALL_WARNING = "Plugins run with your full user permissions: they can read and change your files and run any program. Only install code you trust."

export function parseGitSource(source) {
    const m = /^https:\/\/[A-Za-z0-9.-]+\/[A-Za-z0-9._\/-]+?\/([a-z0-9][a-z0-9-]{0,39})(\.git)?\/?$/.exec(typeof source === "string" ? source : "")
    return m === null ? null : { id: m[1], url: source }
}

export function readCommit(text) {
    const t = String(text || "").trim()
    return /^[0-9a-f]{40}$/.test(t) ? t : ""
}

export function pendingSummary(p) {
    if (p === null || typeof p !== "object")
        return ""
    return p.id + " from " + p.url + " at commit " + p.commit + "\n" + INSTALL_WARNING + "\nRun “sylvaris plugins confirm” to install it or “sylvaris plugins discard” to drop it."
}

export const BUILTIN = [
    { id: "diver", name: "Diver", kind: "builtin", part: "diver", services: ["Diver"], description: "Plans, reminders and alarms from diver.fatum.cc in SylClock, SylCenter, the bar and the SylDiver panel. Pair it in SylSettings › Diver." },
    { id: "airpods", name: "AirPods", kind: "builtin", part: "", services: [], description: "Battery, listening modes and conversation awareness for AirPods in SylMedia › Devices." },
    { id: "fatest", name: "FaTest", kind: "builtin", part: "fatest", services: [], description: "Internet speed tests with FaTest in the FaTest panel, sharing its history and default server. Needs the fatest command." },
    { id: "awake", name: "Keep Awake", kind: "builtin", part: "", services: [], description: "A SylCenter tile and the sylvaris awake command that keep the screen from dimming, locking or going to sleep while it is on, for films, slides and long downloads." },
    { id: "rgb", name: "SylRGB", kind: "builtin", part: "rgb", services: [], description: "One place for the lights on your mouse, keyboard, memory, graphics card, motherboard and LED strips, through OpenRGB. Colours can follow your theme and come back when a device reconnects. Needs OpenRGB with its SDK server on." }
]

export function builtinOn(plugins, id) {
    return plugins !== null && typeof plugins === "object" && plugins.enabled !== null && typeof plugins.enabled === "object" && plugins.enabled[id] === true
}

export function withBuiltins(scanned) {
    const own = BUILTIN.map(b => ({ dir: "", id: b.id, ok: true, error: "", builtin: true, manifest: b }))
    return own.concat(scanned.filter(p => !BUILTIN.some(b => b.id === p.id)))
}
