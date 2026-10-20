export const ACTIONS = {
    lock: { label: "Lock", verb: "Locking", about: "Lock the session and keep everything open", glyph: "lock", key: "l", confirm: false, command: "" },
    suspend: { label: "Suspend", verb: "Suspending", about: "Sleep in memory and wake up in a second", glyph: "sleep", key: "s", confirm: false, command: "systemctl suspend 2>/dev/null || loginctl suspend" },
    hibernate: { label: "Hibernate", verb: "Hibernating", about: "Save everything to disk and power off", glyph: "hibernate", key: "h", confirm: true, command: "systemctl hibernate 2>/dev/null || loginctl hibernate" },
    logout: { label: "Log out", verb: "Logging out", about: "Close every window and end the session", glyph: "logout", key: "o", confirm: true, command: "" },
    reboot: { label: "Restart", verb: "Restarting", about: "Close everything and start again", glyph: "restart", key: "r", confirm: true, command: "systemctl reboot 2>/dev/null || loginctl reboot" },
    firmware: { label: "Firmware", verb: "Restarting into firmware", about: "Restart into the UEFI setup", glyph: "firmware", key: "f", confirm: true, command: "systemctl reboot --firmware-setup" },
    shutdown: { label: "Shut down", verb: "Shutting down", about: "Close everything and power off", glyph: "power", key: "p", confirm: true, command: "systemctl poweroff 2>/dev/null || loginctl poweroff" }
}

export const DEFAULT_POWER = { actions: ["lock", "suspend", "logout", "reboot", "shutdown"], confirm: true, countdown: 3, commands: {} }

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

export function validatePower(raw) {
    const p = isObject(raw) ? raw : {}
    const actions = Array.isArray(p.actions) ? p.actions.filter((a, i, all) => ACTIONS[a] !== undefined && all.indexOf(a) === i) : DEFAULT_POWER.actions.slice()
    const commands = {}
    if (isObject(p.commands)) {
        for (const k of Object.keys(p.commands)) {
            if (ACTIONS[k] !== undefined && typeof p.commands[k] === "string")
                commands[k] = p.commands[k]
        }
    }
    return Object.assign({}, p, {
        actions: actions.length > 0 ? actions : DEFAULT_POWER.actions.slice(),
        confirm: p.confirm !== false,
        countdown: Number.isInteger(p.countdown) && p.countdown >= 1 && p.countdown <= 10 ? p.countdown : DEFAULT_POWER.countdown,
        commands: commands
    })
}

export function commandFor(id, power, lockCommand) {
    if (power.commands[id] !== undefined && power.commands[id] !== "")
        return power.commands[id]
    if (id === "lock")
        return lockCommand
    return ACTIONS[id] === undefined ? "" : ACTIONS[id].command
}

export function needsConfirm(id, power) {
    return power.confirm && ACTIONS[id] !== undefined && ACTIONS[id].confirm
}

export function byKey(ids, key) {
    const k = String(key || "").toLowerCase()
    return ids.find(id => ACTIONS[id].key === k) || ""
}

export function ring(count, index, rx, ry, spin) {
    const a = -Math.PI / 2 + (Math.PI * 2 * index) / Math.max(1, count) + (spin || 0)
    return { x: Math.cos(a) * rx, y: Math.sin(a) * ry, depth: (Math.sin(a) + 1) / 2 }
}

export function uptime(seconds) {
    const s = Math.max(0, Math.floor(seconds))
    const d = Math.floor(s / 86400)
    const h = Math.floor((s % 86400) / 3600)
    const m = Math.floor((s % 3600) / 60)
    if (d > 0)
        return d + "d " + h + "h"
    if (h > 0)
        return h + "h " + m + "m"
    return m + "m"
}
