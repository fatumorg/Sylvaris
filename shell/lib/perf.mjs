const LUA = "hl.config({ animations = { enabled = false }, decoration = { blur = { enabled = false }, shadow = { enabled = false } }, general = { gaps_in = 0, gaps_out = 0, border_size = 1 } })"
const CLASSIC = ["animations:enabled 0", "decoration:blur:enabled 0", "decoration:shadow:enabled 0", "general:gaps_in 0", "general:gaps_out 0", "general:border_size 1"]

export function perfArgs(compositor, usingLua, on) {
    if (compositor === "hyprland") {
        if (!on)
            return ["hyprctl", "reload"]
        return usingLua ? ["hyprctl", "eval", LUA] : ["hyprctl", "--batch", CLASSIC.map(k => "keyword " + k).join(" ; ")]
    }
    if (compositor === "sway")
        return on ? ["swaymsg", "gaps inner all set 0, gaps outer all set 0"] : ["swaymsg", "reload"]
    return null
}

export function liteFor(mode, toggleOn, windows) {
    if (mode === "on" || toggleOn)
        return true
    if (mode !== "auto")
        return false
    return windows.some(w => w.fullscreen && w.activated && !w.minimized)
}
