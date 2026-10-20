function raw(kelvin) {
    const t = Math.max(1000, Math.min(6500, kelvin)) / 100
    const clamp = v => Math.max(0, Math.min(255, v))
    const g = clamp(99.4708025861 * Math.log(t) - 161.1195681661)
    const b = t <= 19 ? 0 : clamp(138.5177312231 * Math.log(t - 10) - 305.0447927307)
    return [255, g, b]
}

export function kelvinRgb(kelvin) {
    const now = raw(kelvin)
    const white = raw(6500)
    return now.map((c, i) => Math.min(1, c / white[i]))
}

export function hasMirror(monitors) {
    return Array.isArray(monitors) && monitors.some(m => m !== null && typeof m === "object" && typeof m.mirrorOf === "string" && m.mirrorOf !== "none" && m.disabled !== true)
}
