export function pickScreen(names, wanted) {
    if (!Array.isArray(names) || names.length === 0)
        return -1
    const i = names.indexOf(wanted)
    return i < 0 ? 0 : i
}

export function roomHeight(screenHeight, bar, barHeight, barMargin, edgeMargin) {
    const horizontal = bar !== null && typeof bar === "object" && bar.enabled !== false && (bar.position === "top" || bar.position === "bottom")
    const reserve = horizontal ? barHeight + (bar.floating ? barMargin : 0) : 0
    return Math.max(0, screenHeight - reserve - 2 * edgeMargin)
}
