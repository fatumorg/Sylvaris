export const DIRECTIONS = ["left", "right", "up", "down"]

function target(arg) {
    const s = String(arg === undefined ? "" : arg)
    if (s === "next" || s === "prev")
        return s
    if (/^[0-9]+$/.test(s))
        return Number(s)
    throw new Error("expected a workspace number, next or prev")
}

function direction(arg) {
    if (DIRECTIONS.indexOf(arg) < 0)
        throw new Error("expected left, right, up or down")
    return arg
}

function address(arg) {
    const s = String(arg === undefined ? "" : arg)
    if (!/^(0x)?[0-9a-f]+$/.test(s))
        throw new Error("expected a window address")
    return s.indexOf("0x") === 0 ? s : "0x" + s
}

function lua(verb, arg, rest) {
    switch (verb) {
    case "minimize":
        return "hl.dsp.window.move({ workspace = \"special:minimized\", follow = false })"
    case "restore":
        return "hl.dsp.window.move({ workspace = " + target(rest[0]) + ", window = \"address:" + address(arg) + "\" })"
    case "focus-window":
        return "hl.dsp.focus({ window = \"address:" + address(arg) + "\" })"
    case "workspace": {
        const t = target(arg)
        return "hl.dsp.focus({ workspace = " + (t === "next" ? "\"e+1\"" : t === "prev" ? "\"e-1\"" : t) + " })"
    }
    case "move-to": {
        const t = target(arg)
        return "hl.dsp.window.move({ workspace = " + (t === "next" ? "\"e+1\"" : t === "prev" ? "\"e-1\"" : t) + " })"
    }
    case "focus":
        return "hl.dsp.focus({ direction = \"" + direction(arg) + "\" })"
    case "move":
        return "hl.dsp.window.move({ direction = \"" + direction(arg) + "\" })"
    case "close":
        return "hl.dsp.window.close()"
    case "fullscreen":
        return "hl.dsp.window.fullscreen({ action = \"toggle\", mode = \"fullscreen\" })"
    case "float":
        return "hl.dsp.window.float({ action = \"toggle\" })"
    case "quit":
        return "hl.dsp.exit()"
    }
    return null
}

function hyprClassic(verb, arg, rest) {
    const dir = { left: "l", right: "r", up: "u", down: "d" }
    switch (verb) {
    case "minimize":
        return "movetoworkspacesilent special:minimized"
    case "restore":
        return "movetoworkspace " + target(rest[0]) + ",address:" + address(arg)
    case "focus-window":
        return "focuswindow address:" + address(arg)
    case "workspace": {
        const t = target(arg)
        return "workspace " + (t === "next" ? "e+1" : t === "prev" ? "e-1" : t)
    }
    case "move-to": {
        const t = target(arg)
        return "movetoworkspace " + (t === "next" ? "e+1" : t === "prev" ? "e-1" : t)
    }
    case "focus":
        return "movefocus " + dir[direction(arg)]
    case "move":
        return "movewindow " + dir[direction(arg)]
    case "close":
        return "killactive"
    case "fullscreen":
        return "fullscreen 0"
    case "float":
        return "togglefloating"
    case "quit":
        return "exit"
    }
    return null
}

function sway(verb, arg) {
    switch (verb) {
    case "minimize":
        return "move scratchpad"
    case "restore":
        return "scratchpad show"
    case "workspace": {
        const t = target(arg)
        return t === "next" ? "workspace next_on_output" : t === "prev" ? "workspace prev_on_output" : "workspace number " + t
    }
    case "move-to": {
        const t = target(arg)
        return t === "next" ? "move container to workspace next_on_output" : t === "prev" ? "move container to workspace prev_on_output" : "move container to workspace number " + t
    }
    case "focus":
        return "focus " + direction(arg)
    case "move":
        return "move " + direction(arg)
    case "close":
        return "kill"
    case "fullscreen":
        return "fullscreen toggle"
    case "float":
        return "floating toggle"
    case "reload":
        return "reload"
    case "quit":
        return "exit"
    }
    return null
}

function niri(verb, arg) {
    switch (verb) {
    case "workspace": {
        const t = target(arg)
        return t === "next" ? ["focus-workspace-down"] : t === "prev" ? ["focus-workspace-up"] : ["focus-workspace", String(t)]
    }
    case "move-to": {
        const t = target(arg)
        return t === "next" ? ["move-window-to-workspace-down"] : t === "prev" ? ["move-window-to-workspace-up"] : ["move-window-to-workspace", String(t)]
    }
    case "focus":
        return { left: ["focus-column-left"], right: ["focus-column-right"], up: ["focus-window-up"], down: ["focus-window-down"] }[direction(arg)]
    case "move":
        return { left: ["move-column-left"], right: ["move-column-right"], up: ["move-window-up"], down: ["move-window-down"] }[direction(arg)]
    case "close":
        return ["close-window"]
    case "fullscreen":
        return ["fullscreen-window"]
    case "float":
        return ["toggle-window-floating"]
    case "reload":
        return ["load-config-file"]
    case "quit":
        return ["quit", "--skip-confirmation"]
    }
    return null
}

export const VERBS = ["workspace", "move-to", "focus", "move", "close", "fullscreen", "float", "exec", "reload", "quit", "minimize", "restore", "focus-window"]

export function translate(name, usingLua, verb, args) {
    if (VERBS.indexOf(verb) < 0)
        throw new Error("unknown compositor action: " + verb)
    const arg = args[0]
    if (verb === "exec") {
        if (args.length === 0)
            throw new Error("usage: wm exec <command>")
        return { via: "exec", command: ["sh", "-c", args.join(" ")] }
    }
    if (name === "hyprland") {
        if (verb === "reload")
            return { via: "exec", command: ["hyprctl", "reload"] }
        return { via: "hyprland", command: usingLua ? lua(verb, arg, args.slice(1)) : hyprClassic(verb, arg, args.slice(1)) }
    }
    if (name === "sway")
        return { via: "i3", command: sway(verb, arg) }
    if (name === "niri") {
        const a = niri(verb, arg)
        return { via: "exec", command: a === null || a === undefined ? null : ["niri", "msg", "action"].concat(a) }
    }
    throw new Error("no supported compositor is running")
}

function byId(list) {
    const out = {}
    for (const x of list)
        out[x.id] = x
    return out
}

export function niriReduce(state, event) {
    const s = { workspaces: state.workspaces, windows: state.windows }
    const key = Object.keys(event)[0]
    const e = event[key]
    if (key === "WorkspacesChanged")
        s.workspaces = e.workspaces
    else if (key === "WorkspaceActivated") {
        const ws = byId(s.workspaces)[e.id]
        const output = ws ? ws.output : null
        s.workspaces = s.workspaces.map(w => Object.assign({}, w, {
            is_active: w.id === e.id ? true : w.output === output ? false : w.is_active,
            is_focused: e.focused ? w.id === e.id : w.is_focused
        }))
    } else if (key === "WorkspaceUrgencyChanged")
        s.workspaces = s.workspaces.map(w => w.id === e.id ? Object.assign({}, w, { is_urgent: e.urgent }) : w)
    else if (key === "WorkspaceActiveWindowChanged")
        s.workspaces = s.workspaces.map(w => w.id === e.workspace_id ? Object.assign({}, w, { active_window_id: e.active_window_id }) : w)
    else if (key === "WindowsChanged")
        s.windows = e.windows
    else if (key === "WindowOpenedOrChanged") {
        const w = e.window
        const rest = s.windows.filter(x => x.id !== w.id).map(x => w.is_focused ? Object.assign({}, x, { is_focused: false }) : x)
        s.windows = rest.concat([w])
    } else if (key === "WindowClosed")
        s.windows = s.windows.filter(x => x.id !== e.id)
    else if (key === "WindowFocusChanged")
        s.windows = s.windows.map(x => Object.assign({}, x, { is_focused: x.id === e.id }))
    else if (key === "WindowUrgencyChanged")
        s.windows = s.windows.map(x => x.id === e.id ? Object.assign({}, x, { is_urgent: e.urgent }) : x)
    else
        return state
    return s
}

const OWN_WINDOWS = [[" — SylFiles", "sylvaris-files"], [" — SylArchive", "sylvaris-archive"]]

export function appOf(appId, title) {
    const id = String(appId || "")
    if (!/^(org\.)?quickshell$/i.test(id))
        return id
    const t = String(title || "")
    const own = OWN_WINDOWS.find(o => t.endsWith(o[0]))
    return own ? own[1] : id
}

export function niriWorkspaces(state) {
    const counts = {}
    const apps = {}
    for (const w of state.windows) {
        counts[w.workspace_id] = (counts[w.workspace_id] || 0) + 1
        apps[w.workspace_id] = (apps[w.workspace_id] || []).concat([appOf(w.app_id, w.title)])
    }
    return state.workspaces.map(w => ({
        id: String(w.id),
        index: w.idx,
        name: w.name || String(w.idx),
        output: w.output || "",
        active: w.is_active,
        focused: w.is_focused,
        urgent: w.is_urgent,
        windows: counts[w.id] || 0,
        apps: apps[w.id] || []
    })).sort(order)
}

export function order(a, b) {
    return a.output < b.output ? -1 : a.output > b.output ? 1 : a.index - b.index
}

export function bindSnippet(name, usingLua, key, command) {
    const words = command.split(" ")
    const bare = key.indexOf("XF86") === 0
    if (name === "hyprland") {
        if (usingLua)
            return "hl.bind(" + (bare ? "\"" + key + "\"" : "mainMod .. \" + " + key + "\"") + ", hl.dsp.exec_cmd(\"" + command + "\"))"
        return "bind = " + (bare ? "" : "SUPER") + ", " + key + ", exec, " + command
    }
    if (name === "niri")
        return (bare ? "" : "Mod+") + key + " { spawn " + words.map(w => "\"" + w + "\"").join(" ") + "; }"
    if (name === "sway")
        return "bindsym " + (bare ? key : "$mod+" + key.toLowerCase()) + " exec " + command
    return command
}

export const COMPOSITORS = ["hyprland", "niri", "sway"]

export const CAPABILITY_LABELS = {
    keybinds: "Key bindings from SylSettings applied live",
    previews: "Window previews in SylSwitch",
    minimize: "Minimize by clicking the title in SylBar",
    windowShot: "Screenshot of a single window",
    zoom: "Screen zoom in SylAccessibility",
    filters: "Colour filters in SylAccessibility",
    performance: "Performance mode also trims the compositor"
}

export const CAPABILITIES = {
    hyprland: { keybinds: true, previews: true, minimize: true, windowShot: true, zoom: true, filters: true, performance: true },
    niri: { keybinds: false, previews: false, minimize: false, windowShot: false, zoom: false, filters: false, performance: false },
    sway: { keybinds: true, previews: false, minimize: true, windowShot: true, zoom: false, filters: false, performance: true }
}

export function can(name, capability) {
    const caps = CAPABILITIES[name]
    return caps !== undefined && caps[capability] === true
}

export function capabilityTable() {
    const names = { hyprland: "Hyprland", niri: "niri", sway: "sway" }
    const lines = ["| | " + COMPOSITORS.map(c => names[c]).join(" | ") + " |", "|---|" + COMPOSITORS.map(() => ":---:").join("|") + "|"]
    for (const key of Object.keys(CAPABILITY_LABELS))
        lines.push("| " + CAPABILITY_LABELS[key] + " | " + COMPOSITORS.map(c => can(c, key) ? "yes" : "no").join(" | ") + " |")
    return lines.join("\n")
}
