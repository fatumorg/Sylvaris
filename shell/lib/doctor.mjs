import { parseJson, validateConfig, effectiveSettings, liveParts, PARTS, migrateConfig, migrateSettings } from "./settings.mjs"
import { pamService } from "./lock.mjs"

export const PART_PACKAGES = {
    bar: ["pulseaudio", "pipewire", "python", "libnotify"],
    center: ["wlr-randr", "brightnessctl", "ddcutil", "wayvnc", "openssl", "iproute2", "networkmanager", "wlsunset", "pulseaudio", "pipewire", "python", "libnotify", "wl-clipboard"],
    clock: ["pipewire", "python", "libnotify", "curl"],
    deck: [],
    diver: ["pipewire", "python", "libnotify"],
    fatest: [],
    rgb: ["python"],
    media: ["pulseaudio", "pipewire", "python"],
    notify: [],
    pad: [],
    paper: [],
    power: [],
    lock: ["glib"],
    polkit: [],
    clip: ["wl-clipboard"],
    island: ["wtype", "wl-clipboard", "libnotify"],
    viewer: ["wl-clipboard", "glib"],
    files: ["wl-clipboard", "glib", "python", "udisks"],
    archive: ["libarchive", "python"],
    widgets: ["cava"],
    access: [],
    plugins: ["git"],
    sync: ["python", "procps"],
    capture: ["grim", "slurp", "wf-recorder", "ffmpeg", "wl-clipboard", "libnotify", "pulseaudio"],
    switcher: [],
    settings: ["wlsunset", "pipewire", "python", "libnotify", "curl"],
    theme: []
}

export const PACKAGE_BINS = {
    wtype: ["wtype"],
    cava: ["cava"],
    pulseaudio: ["pactl"],
    pipewire: ["pw-cli", "pw-metadata"],
    python: ["python3"],
    libnotify: ["notify-send"],
    "wlr-randr": ["wlr-randr"],
    brightnessctl: ["brightnessctl"],
    ddcutil: ["ddcutil"],
    wayvnc: ["wayvnc"],
    openssl: ["openssl"],
    iproute2: ["ip"],
    networkmanager: ["nmcli"],
    wlsunset: ["wlsunset"],
    "wl-clipboard": ["wl-copy", "wl-paste"],
    curl: ["curl"],
    glib: ["gdbus"],
    git: ["git"],
    procps: ["pgrep"],
    grim: ["grim"],
    slurp: ["slurp"],
    "wf-recorder": ["wf-recorder"],
    ffmpeg: ["ffmpeg"],
    udisks: ["udisksctl"],
    libarchive: ["bsdtar", "bsdcat"]
}

export const CORE_BINS = ["sylstack"]

const VENDORS = { "0x10de": "NVIDIA", "0x1002": "AMD", "0x8086": "Intel", "0x1af4": "Virtio", "0x15ad": "VMware" }

function unique(list) {
    const out = []
    for (const x of list)
        if (out.indexOf(x) < 0)
            out.push(x)
    return out
}

function binsFor(part) {
    const out = []
    for (const p of PART_PACKAGES[part] || [])
        for (const b of PACKAGE_BINS[p] || [])
            out.push(b)
    return unique(out)
}

export function allBins() {
    let out = CORE_BINS.slice()
    for (const part of Object.keys(PART_PACKAGES))
        out = out.concat(binsFor(part))
    return unique(out)
}

export const FONTS = ["Inter", "JetBrainsMono Nerd Font"]

export function missingFonts(families) {
    const have = new Set(Array.from(families || [], f => String(f).toLowerCase()))
    return FONTS.filter(f => !have.has(f.toLowerCase()))
}

export function missingTools(parts, present) {
    const out = {}
    const core = CORE_BINS.filter(b => present.indexOf(b) < 0)
    if (core.length > 0)
        out.core = core
    for (const part of parts) {
        const missing = binsFor(part).filter(b => present.indexOf(b) < 0)
        if (missing.length > 0)
            out[part] = missing
    }
    return out
}

export function gpuName(vendor, driver) {
    return (VENDORS[vendor] || vendor) + " (" + (driver || "no driver") + ")"
}

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function covered(raw, valid) {
    if (isObject(raw) && isObject(valid))
        return Object.keys(raw).every(k => valid[k] !== undefined && covered(raw[k], valid[k]))
    if (Array.isArray(raw) && Array.isArray(valid))
        return raw.length === valid.length && raw.every((x, i) => covered(x, valid[i]))
    return JSON.stringify(raw) === JSON.stringify(valid)
}

export function problems(raw, valid, prefix) {
    const out = []
    const at = prefix || ""
    for (const key of Object.keys(raw)) {
        const path = at + key
        if (valid[key] === undefined)
            out.push(path + ": not used")
        else if (isObject(raw[key]) && isObject(valid[key]))
            for (const p of problems(raw[key], valid[key], path + "."))
                out.push(p)
        else if (Array.isArray(raw[key]) && Array.isArray(valid[key]) && raw[key].length > valid[key].length)
            out.push(path + ": " + (raw[key].length - valid[key].length) + " of " + raw[key].length + " entries not valid")
        else if (!covered(raw[key], valid[key]))
            out.push(path + ": " + JSON.stringify(raw[key]) + " is not valid, using " + JSON.stringify(valid[key]))
    }
    return out
}

function fileLines(name, file, migrate, check) {
    const head = name + " (" + file.path + "): "
    if (file.text === null || file.text === undefined)
        return [head + "not found, defaults in use"]
    const r = parseJson(file.text)
    if (!r.ok)
        return [head + "not valid JSON (" + r.error + "), " + (name === "config.json" ? "defaults" : "the last good settings or defaults") + " in use"]
    const m = migrate(r.value)
    if (!m.ok)
        return [head + m.error]
    const list = check(m.value)
    if (list.length === 0)
        return [head + "ok"]
    return [head + list.length + (list.length === 1 ? " problem" : " problems")].concat(list.map(p => "  " + p))
}

export function report(f) {
    const load = (file, migrate) => {
        const r = file.text === null || file.text === undefined ? { ok: false } : parseJson(file.text)
        const m = r.ok ? migrate(r.value) : { ok: false }
        return m.ok ? m.value : {}
    }
    const config = load(f.config, migrateConfig)
    const raw = load(f.settings, migrateSettings)
    const settings = effectiveSettings(validateConfig(config), raw)
    const on = liveParts(settings.parts)
    const off = Object.keys(PARTS).filter(p => on.indexOf(p) < 0)
    const missing = missingTools(on, f.present || [])
    const lines = [
        "Sylvaris " + f.version + " (commit " + (f.commit || "unknown") + ")",
        "SylStack: " + (f.sylstack || "not found"),
        "Compositor: " + (f.compositor || "unknown"),
        "GPU: " + ((f.gpus || []).length === 0 ? "unknown" : f.gpus.map(g => gpuName(g.vendor, g.driver)).join(", ")),
        "Parts on: " + (on.length === 0 ? "none" : on.join(", ")),
        "Parts off: " + (off.length === 0 ? "none" : off.join(", "))
    ]
    const pam = pamService(settings.lock.pam, f.pams || [])
    lines.push("Lock PAM service: " + pam)
    if (pam === "login")
        lines.push("  Install the sylvaris PAM service: programs.sylvaris.lock.enable on NixOS, or sudo make install-pam")
    const keys = Object.keys(missing)
    if (keys.length === 0)
        lines.push("Missing tools: none")
    else
        lines.push("Missing tools:")
    for (const k of keys)
        lines.push("  " + k + ": " + missing[k].join(", "))
    if (f.fonts) {
        const fonts = missingFonts(f.fonts).map(n => n === "JetBrainsMono Nerd Font" ? n + " (icons show as empty boxes)" : n)
        lines.push("Missing fonts: " + (fonts.length === 0 ? "none" : fonts.join(", ")))
    }
    return lines.concat(fileLines("config.json", f.config, migrateConfig, v => problems(v, validateConfig(v))))
        .concat(fileLines("settings.json", f.settings, migrateSettings, v => problems(v, effectiveSettings({}, v))))
        .join("\n")
}

export function parseFacts(text) {
    const out = { sylstack: "", compositor: "", commit: "", gpus: [], present: [], pams: [] }
    for (const line of String(text || "").split("\n")) {
        const eq = line.indexOf("=")
        if (eq < 0)
            continue
        const key = line.slice(0, eq)
        const value = line.slice(eq + 1).trim()
        if (key === "gpu") {
            const sp = value.indexOf(" ")
            out.gpus.push({ vendor: sp < 0 ? value : value.slice(0, sp), driver: sp < 0 ? "" : value.slice(sp + 1).trim() })
        } else if (key === "bin") {
            out.present.push(value)
        } else if (key === "pam") {
            out.pams.push(value)
        } else if (key === "sylstack" || key === "compositor" || key === "commit") {
            out[key] = value
        }
    }
    return out
}
