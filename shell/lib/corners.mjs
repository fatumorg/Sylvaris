export const CORNER_NAMES = ["top-left", "top-right", "bottom-left", "bottom-right"]
export const DEFAULT_CORNERS = { enabled: false, dwell: 250, actions: {} }

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function validKey(key) {
    const at = key.lastIndexOf(":")
    return at > 0 && CORNER_NAMES.includes(key.slice(at + 1))
}

function validAction(v) {
    if (typeof v === "string")
        return v.trim() !== ""
    return isObject(v) && Array.isArray(v.command) && v.command.length > 0 && v.command.every(a => typeof a === "string") && v.command[0] !== ""
}

export function validateCorners(raw) {
    const r = isObject(raw) ? raw : {}
    const actions = {}
    const given = isObject(r.actions) ? r.actions : {}
    for (const key of Object.keys(given)) {
        if (validKey(key) && validAction(given[key]))
            actions[key] = given[key]
    }
    return Object.assign({}, r, {
        enabled: r.enabled === true,
        dwell: Number.isInteger(r.dwell) ? Math.max(0, Math.min(2000, r.dwell)) : DEFAULT_CORNERS.dwell,
        actions: actions
    })
}

export function cornerAction(actions, screen, corner) {
    const own = actions[screen + ":" + corner]
    return own !== undefined ? own : actions["*:" + corner] !== undefined ? actions["*:" + corner] : null
}

export function cornersOn(actions, screen) {
    return CORNER_NAMES.filter(c => cornerAction(actions, screen, c) !== null)
}
