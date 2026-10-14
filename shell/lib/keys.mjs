export const ACTIONS = [
    { id: "pad toggle", label: "Launcher" },
    { id: "center toggle", label: "Control center" },
    { id: "switcher next", label: "Next window" },
    { id: "switcher prev", label: "Previous window" },
    { id: "clock toggle", label: "Calendar and weather" },
    { id: "notify toggle", label: "Notifications" },
    { id: "clip toggle", label: "Clipboard history" },
    { id: "files open", label: "Files" },
    { id: "capture toggle", label: "Capture panel" },
    { id: "capture shot area", label: "Screenshot of an area" },
    { id: "capture shot window", label: "Screenshot of a window" },
    { id: "capture shot screen", label: "Screenshot of the screen" },
    { id: "capture record area", label: "Record an area" },
    { id: "capture stop", label: "Stop recording" },
    { id: "lock now", label: "Lock the screen" },
    { id: "power toggle", label: "Power menu" },
    { id: "theme toggle", label: "Theme picker" },
    { id: "theme cycle", label: "Next theme" },
    { id: "paper toggle", label: "Wallpapers" },
    { id: "diver toggle", label: "Diver planner" },
    { id: "media toggle", label: "Media player" },
    { id: "settings toggle", label: "Settings" },
    { id: "access toggle", label: "Accessibility" },
    { id: "access zoom in", label: "Zoom in" },
    { id: "access zoom out", label: "Zoom out" },
    { id: "dnd toggle", label: "Do not disturb" },
    { id: "nightlight toggle", label: "Night light" },
    { id: "privacy toggle", label: "Mute microphones and cameras" }
]

const MODS = ["SUPER", "CTRL", "ALT", "SHIFT"]
const ALIAS = { WIN: "SUPER", META: "SUPER", MOD4: "SUPER", CONTROL: "CTRL", MOD1: "ALT" }

export function normalize(text) {
    const parts = String(text || "").split("+").map(s => s.trim()).filter(s => s !== "")
    if (parts.length === 0)
        return ""
    const key = parts[parts.length - 1]
    const mods = parts.slice(0, -1).map(m => ALIAS[m.toUpperCase()] || m.toUpperCase())
    if (mods.some(m => MODS.indexOf(m) < 0) || MODS.indexOf(key.toUpperCase()) >= 0 || !/^[A-Za-z0-9_]+$/.test(key))
        return ""
    const ordered = MODS.filter(m => mods.indexOf(m) >= 0)
    return ordered.concat([key.length === 1 ? key.toUpperCase() : key]).join("+")
}

export function validateKeybinds(raw) {
    const out = {}
    if (raw === null || typeof raw !== "object" || Array.isArray(raw))
        return out
    const known = ACTIONS.map(a => a.id)
    for (const id of Object.keys(raw)) {
        const combo = normalize(raw[id])
        if (known.indexOf(id) >= 0 && combo !== "")
            out[id] = combo
    }
    return out
}

function split(combo) {
    const parts = combo.split("+")
    return { mods: parts.slice(0, -1), key: parts[parts.length - 1] }
}

const SWAY = { SUPER: "Mod4", CTRL: "Ctrl", ALT: "Mod1", SHIFT: "Shift" }

export function bindArgs(compositor, usingLua, combo, action) {
    const c = split(combo)
    const cmd = "sylvaris " + action
    if (compositor === "hyprland")
        return usingLua ? ["hyprctl", "eval", "pcall(hl.unbind, \"" + c.mods.concat([c.key]).join(" + ") + "\") hl.bind(\"" + c.mods.concat([c.key]).join(" + ") + "\", hl.dsp.exec_cmd(\"" + cmd + "\"))"] : ["hyprctl", "keyword", "bind", c.mods.join(" ") + "," + c.key + ",exec," + cmd]
    if (compositor === "sway")
        return ["swaymsg", "bindsym", c.mods.map(m => SWAY[m]).concat([c.key.length === 1 ? c.key.toLowerCase() : c.key]).join("+"), "exec", cmd]
    return null
}

export function unbindArgs(compositor, usingLua, combo) {
    const c = split(combo)
    if (compositor === "hyprland")
        return usingLua ? ["hyprctl", "eval", "hl.unbind(\"" + c.mods.concat([c.key]).join(" + ") + "\")"] : ["hyprctl", "keyword", "unbind", c.mods.join(" ") + "," + c.key]
    if (compositor === "sway")
        return ["swaymsg", "unbindsym", c.mods.map(m => SWAY[m]).concat([c.key.length === 1 ? c.key.toLowerCase() : c.key]).join("+")]
    return null
}

const SPECIAL = {
    0x20: "space", 0x01000004: "Return", 0x01000005: "Return", 0x01000001: "Tab", 0x01000003: "BackSpace",
    0x01000007: "Delete", 0x01000006: "Insert", 0x01000010: "Home", 0x01000011: "End", 0x01000016: "Prior", 0x01000017: "Next",
    0x01000009: "Print", 0x01000012: "Left", 0x01000013: "Up", 0x01000014: "Right", 0x01000015: "Down"
}

export function keyName(code, text) {
    if (SPECIAL[code])
        return SPECIAL[code]
    if (code >= 0x01000030 && code <= 0x01000047)
        return "F" + (code - 0x01000030 + 1)
    if (code >= 0x30 && code <= 0x39 || code >= 0x41 && code <= 0x5a)
        return String.fromCharCode(code)
    return ""
}

export function diff(applied, wanted) {
    const unbind = []
    const bind = []
    for (const id of Object.keys(applied))
        if (wanted[id] !== applied[id])
            unbind.push(applied[id])
    for (const id of Object.keys(wanted))
        if (applied[id] !== wanted[id])
            bind.push([wanted[id], id])
    return { unbind: unbind, bind: bind }
}

const SHORT = { lock: "lock now", switcher: "switcher next", files: "files open" }

export function actionFor(command) {
    const words = String(command || "").trim().split(/\s+/)
    if (words.length === 0 || !/(^|\/)sylvaris$/.test(words[0]))
        return ""
    const rest = words.slice(1)
    const ids = ACTIONS.map(a => a.id)
    const id = rest.join(" ")
    if (ids.indexOf(id) >= 0)
        return id
    if (rest.length === 1) {
        if (SHORT[rest[0]])
            return SHORT[rest[0]]
        if (ids.indexOf(rest[0] + " toggle") >= 0)
            return rest[0] + " toggle"
    }
    return ""
}

function luaValue(expr, vars) {
    let out = ""
    for (const raw of expr.split("..")) {
        const p = raw.trim()
        const lit = /^(["'])(.*)\1$/.exec(p)
        if (lit)
            out += lit[2]
        else if (/^[A-Za-z_]\w*$/.test(p) && vars[p] !== undefined)
            out += vars[p]
        else
            return null
    }
    return out
}

export function parseLuaBinds(text) {
    const src = String(text || "").split("\n").filter(l => !/^\s*--/.test(l)).join("\n")
    const vars = {}
    const assign = /local\s+([A-Za-z_]\w*)\s*=\s*(["'])(.*?)\2/g
    let m
    while ((m = assign.exec(src)) !== null)
        vars[m[1]] = m[3]
    const out = []
    const bind = /hl\.bind\(\s*([^,]+?)\s*,\s*hl\.dsp\.exec_cmd\(\s*([^)]+?)\s*\)/g
    while ((m = bind.exec(src)) !== null) {
        const combo = luaValue(m[1], vars)
        const command = luaValue(m[2], vars)
        if (combo !== null && command !== null && normalize(combo) !== "")
            out.push({ combo: normalize(combo), command: command })
    }
    return out
}

const MASK = [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]

export function parseHyprBinds(list) {
    return (Array.isArray(list) ? list : []).filter(b => b && b.dispatcher === "exec" && typeof b.arg === "string").map(b => ({
        combo: normalize(MASK.filter(x => (b.modmask & x[0]) !== 0).map(x => x[1]).concat([String(b.key || "")]).join("+")),
        command: b.arg
    })).filter(b => b.combo !== "")
}

const SWAY_MODS = { mod4: "SUPER", mod1: "ALT", ctrl: "CTRL", control: "CTRL", shift: "SHIFT" }

export function parseSwayBinds(text) {
    const vars = {}
    const out = []
    for (const line of String(text || "").split("\n")) {
        const set = /^\s*set\s+(\$\w+)\s+(\S+)/.exec(line)
        if (set) {
            vars[set[1]] = set[2]
            continue
        }
        const b = /^\s*bindsym\s+((?:--\S+\s+)*)(\S+)\s+exec\s+(.+)$/.exec(line)
        if (!b)
            continue
        const combo = b[2].replace(/\$\w+/g, v => vars[v] || v).split("+").map(p => SWAY_MODS[p.toLowerCase()] || p).join("+")
        const n = normalize(combo)
        if (n !== "")
            out.push({ combo: n, command: b[3].replace(/^["']|["']$/g, "") })
    }
    return out
}

export function externalBinds(pairs) {
    const out = {}
    for (const p of pairs) {
        const id = actionFor(p.command)
        if (id !== "" && out[id] === undefined)
            out[id] = p.combo
    }
    return out
}

export function bindsFile(compositor, usingLua, wanted) {
    const ids = Object.keys(wanted).sort()
    if (compositor === "hyprland" && usingLua)
        return ids.map(id => {
            const c = split(wanted[id]).mods.concat([split(wanted[id]).key]).join(" + ")
            return "pcall(hl.unbind, \"" + c + "\")\nhl.bind(\"" + c + "\", hl.dsp.exec_cmd(\"sylvaris " + id + "\"))"
        }).join("\n") + "\n"
    if (compositor === "hyprland")
        return ids.map(id => {
            const c = split(wanted[id])
            return "unbind = " + c.mods.join(" ") + ", " + c.key + "\nbind = " + c.mods.join(" ") + ", " + c.key + ", exec, sylvaris " + id
        }).join("\n") + "\n"
    if (compositor === "sway")
        return ids.map(id => {
            const c = split(wanted[id])
            return "bindsym --no-warn " + c.mods.map(m => SWAY[m]).concat([c.key.length === 1 ? c.key.toLowerCase() : c.key]).join("+") + " exec sylvaris " + id
        }).join("\n") + "\n"
    return ""
}

export function bindsPath(compositor, usingLua, configHome) {
    if (compositor === "hyprland")
        return configHome + "/hypr/sylvaris-keybinds." + (usingLua ? "lua" : "conf")
    if (compositor === "sway")
        return configHome + "/sway/sylvaris-keybinds"
    return ""
}

export function includeLine(compositor, usingLua) {
    if (compositor === "hyprland")
        return usingLua ? "pcall(require, \"sylvaris-keybinds\")" : "source = ~/.config/hypr/sylvaris-keybinds.conf"
    if (compositor === "sway")
        return "include ~/.config/sway/sylvaris-keybinds"
    return ""
}
