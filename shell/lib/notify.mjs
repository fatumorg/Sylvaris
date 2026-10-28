export const CRITICAL = 2

export function timeoutFor(urgency, expireTimeout, fallback) {
    if (urgency === CRITICAL || expireTimeout === 0)
        return 0
    if (typeof expireTimeout === "number" && expireTimeout > 0)
        return expireTimeout
    return fallback
}

export function insert(list, entry, cap) {
    const rest = list.filter(e => e.id !== entry.id)
    return [entry].concat(rest).slice(0, cap)
}

export function evicted(before, after) {
    const kept = new Set(after.map(e => e.id))
    return before.filter(e => !kept.has(e.id))
}

export function remove(list, id) {
    return list.filter(e => e.id !== id)
}

export function pushToast(toasts, id, max) {
    const rest = toasts.filter(t => t !== id)
    return rest.concat([id]).slice(-max)
}

export function groups(list, appOf) {
    const order = []
    const byApp = {}
    for (const e of list) {
        const app = appOf(e) || "Other"
        if (byApp[app] === undefined) {
            byApp[app] = []
            order.push(app)
        }
        byApp[app].push(e)
    }
    return order.map(app => ({ app: app, items: byApp[app] }))
}

export function ago(then, now) {
    const s = Math.max(0, Math.round((now - then) / 1000))
    if (s < 60)
        return "now"
    if (s < 3600)
        return Math.floor(s / 60) + "m"
    if (s < 86400)
        return Math.floor(s / 3600) + "h"
    return Math.floor(s / 86400) + "d"
}

const ALLOWED = /^\/?(b|i|u|a|br)(\s|>|\/|$)/i

export function cleanBody(text) {
    return String(text || "").replace(/<([^<>]*)>|</g, (m, inner) => inner === undefined ? "&lt;" : ALLOWED.test(inner.trim()) ? m : "").replace(/\n/g, "<br>")
}

export function plainText(text) {
    return String(text || "").replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;/g, "'").replace(/&amp;/g, "&")
}

const ICON_URL = "image://icon/"

export function isPicture(icon) {
    const s = String(icon || "")
    return s.indexOf(ICON_URL) !== 0 && (s.indexOf("://") > 0 || s[0] === "/")
}

export function iconSource(icon, lookup) {
    let s = String(icon || "")
    if (s.indexOf(ICON_URL) === 0)
        s = s.slice(ICON_URL.length)
    if (s === "")
        return ""
    if (s.indexOf("://") > 0)
        return /^(file|image):\/\//.test(s) ? s : ""
    if (s[0] === "/")
        return "file://" + s
    const found = lookup(s)
    return found ? String(found) : ""
}

export function toastShift(corner, screen, panel, gap) {
    if (!panel || panel.corner !== corner || panel.screen !== screen)
        return { x: 0, y: 0 }
    if (corner.indexOf("left") > 0 || corner.indexOf("right") > 0)
        return { x: panel.width + gap, y: 0 }
    return { x: 0, y: panel.height + gap }
}

export const STACKS = ["list", "cards"]

export function cardFrame(index, spread, listY) {
    if (spread)
        return { y: listY, scale: 1, opacity: 1 }
    const depth = Math.min(index, 2)
    return { y: depth * 6, scale: Math.pow(0.96, depth), opacity: index < 3 ? 1 : 0 }
}
