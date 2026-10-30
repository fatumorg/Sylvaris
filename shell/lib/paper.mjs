export const FITS = ["cover", "contain", "center", "tile"]
export const TRANSITIONS = ["fade", "zoom", "slide", "none"]
export const DEFAULT_PAPER = { enabled: true, folder: "~/Pictures/wallpapers", wallpaper: "", themes: {}, outputs: {}, fit: "cover", blur: 0, dim: 0, tint: 0, transition: "zoom", duration: 900, drift: false, parallax: 0.4, menu: true }

const IMAGE = /\.(png|jpe?g|webp|bmp|gif|avif|jxl)$/i

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function num(v, lo, hi, fallback) {
    return typeof v === "number" && Number.isFinite(v) && v >= lo && v <= hi ? v : fallback
}

function paths(v) {
    const out = {}
    if (isObject(v)) {
        for (const k of Object.keys(v)) {
            if (typeof v[k] === "string" && v[k] !== "")
                out[k] = v[k]
        }
    }
    return out
}

export function validatePaper(raw) {
    const p = isObject(raw) ? raw : {}
    const d = DEFAULT_PAPER
    return Object.assign({}, p, {
        enabled: p.enabled !== false,
        folder: typeof p.folder === "string" && p.folder !== "" ? p.folder : d.folder,
        wallpaper: typeof p.wallpaper === "string" ? p.wallpaper : d.wallpaper,
        themes: paths(p.themes),
        outputs: paths(p.outputs),
        fit: FITS.indexOf(p.fit) >= 0 ? p.fit : d.fit,
        blur: num(p.blur, 0, 1, d.blur),
        dim: num(p.dim, 0, 0.9, d.dim),
        tint: num(p.tint, 0, 1, d.tint),
        transition: TRANSITIONS.indexOf(p.transition) >= 0 ? p.transition : d.transition,
        duration: Number.isInteger(p.duration) && p.duration >= 0 && p.duration <= 5000 ? p.duration : d.duration,
        drift: p.drift === true,
        parallax: typeof p.parallax === "number" && Number.isFinite(p.parallax) ? Math.max(0, Math.min(1, p.parallax)) : d.parallax,
        menu: p.menu !== false
    })
}

export function resolve(paper, themeId, themeWallpaper, output) {
    if (paper.outputs[output] !== undefined)
        return paper.outputs[output]
    if (paper.themes[themeId] !== undefined)
        return paper.themes[themeId]
    return paper.wallpaper || themeWallpaper || ""
}

export function preview(paper, themeId, themeWallpaper) {
    if (paper.themes[themeId] !== undefined)
        return paper.themes[themeId]
    return themeWallpaper || paper.wallpaper || ""
}

export function dropsPick(paper, fromId, toId, toWallpaper) {
    return paper.wallpaper !== "" && toId !== fromId && toWallpaper !== "" && paper.themes[toId] === undefined
}

export function choose(paper, scope, themeId, output, path) {
    const set = (map, key) => {
        const out = Object.assign({}, map)
        if (path === "")
            delete out[key]
        else
            out[key] = path
        return out
    }
    if (scope === "output" && output !== "")
        return { outputs: set(paper.outputs, output) }
    if (scope === "theme")
        return { themes: set(paper.themes, themeId) }
    return { wallpaper: path, themes: {}, outputs: {} }
}

export function isImage(name) {
    return IMAGE.test(String(name || ""))
}

export function fillMode(fit) {
    return { cover: 2, contain: 1, center: 6, tile: 3 }[fit]
}
