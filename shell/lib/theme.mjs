import { expandHome } from "./settings.mjs"

export const COLOR_KEYS = ["base", "surface", "accent", "accentHi", "accentDeep", "onAccent", "text", "textDim", "textSoft", "danger"]
export const ALPHA_KEYS = ["surface", "glass", "line", "tint"]

export const DEFAULT_THEME = {
    version: 1,
    id: "sylvaris",
    name: "Sylvaris",
    description: "Moss and slate",
    wallpaper: "",
    colors: {
        base: "#121417",
        surface: "#1d2126",
        accent: "#5fb3a1",
        accentHi: "#86d1bf",
        accentDeep: "#3f8a7a",
        onAccent: "#0c1412",
        text: "#e4ece9",
        textDim: "#8fa39d",
        textSoft: "#c3d2cd",
        danger: "#e0705a"
    },
    alpha: { surface: 0.9, glass: 0.62, line: 0.16, tint: 0.08 }
}

const HEX = /^#([0-9a-fA-F]{6})$/
const ID = /^[a-z0-9_-]+$/

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function clone(v) {
    return JSON.parse(JSON.stringify(v))
}

function hex2(n) {
    const s = n.toString(16)
    return s.length === 1 ? "0" + s : s
}

export function parseHex(s) {
    const m = typeof s === "string" ? HEX.exec(s) : null
    if (m === null)
        return null
    const n = parseInt(m[1], 16)
    return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 }
}

export function withAlpha(hex, alpha) {
    const c = parseHex(hex)
    if (c === null)
        return "#00000000"
    const a = Math.round(Math.min(1, Math.max(0, alpha)) * 255)
    return "#" + hex2(a) + hex2(c.r) + hex2(c.g) + hex2(c.b)
}

export function validateTheme(raw) {
    if (!isObject(raw))
        return { ok: false, theme: clone(DEFAULT_THEME), errors: ["theme is not an object"] }
    const errors = []
    if (typeof raw.id !== "string" || !ID.test(raw.id))
        errors.push("id must match [a-z0-9_-]+")
    if (typeof raw.name !== "string" || raw.name.length === 0)
        errors.push("name is required")
    if (errors.length > 0)
        return { ok: false, theme: clone(DEFAULT_THEME), errors: errors }

    const rc = isObject(raw.colors) ? raw.colors : {}
    const colors = {}
    for (const key of COLOR_KEYS) {
        if (parseHex(rc[key]) !== null) {
            colors[key] = rc[key].toLowerCase()
            continue
        }
        if (rc[key] !== undefined)
            errors.push("invalid color " + key)
        colors[key] = key === "textSoft" && parseHex(rc.text) !== null ? rc.text.toLowerCase() : DEFAULT_THEME.colors[key]
    }
    if (parseHex(rc.rgb) !== null)
        colors.rgb = rc.rgb.toLowerCase()
    else if (rc.rgb !== undefined)
        errors.push("invalid color rgb")

    const links = {}
    if (raw.links !== undefined && !isObject(raw.links))
        errors.push("links must be an object")
    for (const [target, source] of Object.entries(isObject(raw.links) ? raw.links : {})) {
        if (target === "" || target[0] === "/" || target.split("/").indexOf("..") >= 0 || typeof source !== "string" || source === "")
            errors.push("invalid link " + target)
        else
            links[target] = source
    }

    const ra = isObject(raw.alpha) ? raw.alpha : {}
    const alpha = {}
    for (const key of ALPHA_KEYS) {
        const a = ra[key]
        if (typeof a === "number" && a >= 0 && a <= 1) {
            alpha[key] = a
            continue
        }
        if (a !== undefined)
            errors.push("invalid alpha " + key)
        alpha[key] = DEFAULT_THEME.alpha[key]
    }

    return {
        ok: true,
        errors: errors,
        theme: {
            version: 1,
            id: raw.id,
            name: raw.name,
            description: typeof raw.description === "string" ? raw.description : "",
            wallpaper: typeof raw.wallpaper === "string" ? raw.wallpaper : "",
            workspaceIcon: typeof raw.workspaceIcon === "string" && /^[a-z]{1,20}$/.test(raw.workspaceIcon) ? raw.workspaceIcon : "",
            look: typeof raw.look === "string" && /^[a-z0-9][a-z0-9-]{0,39}$/.test(raw.look) ? raw.look : "",
            colors: colors,
            alpha: alpha,
            links: links
        }
    }
}

export function tokens(theme) {
    const c = theme.colors
    const a = theme.alpha
    return {
        pane: c.surface,
        base: c.base,
        surface: withAlpha(c.base, a.surface),
        glass: withAlpha(c.base, a.glass),
        node: withAlpha(c.surface, 0.94),
        line: withAlpha(c.accentDeep, a.line),
        lineStrong: withAlpha(c.accentDeep, 0.24),
        cardLine: withAlpha(c.accentDeep, 0.14),
        tint: withAlpha(c.accentDeep, a.tint),
        tintSoft: withAlpha(c.accentDeep, 0.06),
        tintMid: withAlpha(c.accentDeep, 0.1),
        tintStrong: withAlpha(c.accentDeep, 0.16),
        moon: withAlpha(c.accentDeep, 0.4),
        fill: withAlpha(c.accent, 0.35),
        glow: withAlpha(c.accent, 0.25),
        silk: withAlpha(c.accentHi, 0.8),
        sonar: withAlpha(c.accentHi, 0.7),
        accent: c.accent,
        accentHi: c.accentHi,
        accentDeep: c.accentDeep,
        onAccent: c.onAccent,
        text: c.text,
        textDim: c.textDim,
        textSoft: c.textSoft,
        danger: c.danger
    }
}

export function parseArgb(s) {
    if (typeof s !== "string")
        return null
    const m8 = /^#([0-9a-fA-F]{8})$/.exec(s)
    if (m8 !== null) {
        const n = parseInt(m8[1], 16)
        return { a: Math.floor(n / 16777216) & 255, r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 }
    }
    const c = parseHex(s)
    return c === null ? null : { a: 255, r: c.r, g: c.g, b: c.b }
}

export function mixArgb(from, to, t) {
    const b = parseArgb(to)
    if (b === null)
        return "#00000000"
    const a = parseArgb(from)
    const k = Math.min(1, Math.max(0, t))
    const src = a === null ? b : a
    const lerp = (x, y) => Math.round(x + (y - x) * k)
    return "#" + hex2(lerp(src.a, b.a)) + hex2(lerp(src.r, b.r)) + hex2(lerp(src.g, b.g)) + hex2(lerp(src.b, b.b))
}

export function mixTokens(from, to, t) {
    const out = {}
    for (const key of Object.keys(to))
        out[key] = mixArgb(from && from[key] !== undefined ? from[key] : to[key], to[key], t)
    return out
}

export function nextThemeId(ids, current) {
    if (!Array.isArray(ids) || ids.length === 0)
        return ""
    const sorted = ids.slice().sort()
    const i = sorted.indexOf(current)
    return i < 0 ? sorted[0] : sorted[(i + 1) % sorted.length]
}

export function catalogEntry(id, raw) {
    const named = isObject(raw) && typeof raw.name === "string" && raw.name.trim() !== ""
    const name = named ? raw.name : id
    const t = validateTheme(isObject(raw) ? Object.assign({}, raw, { id: ID.test(id) ? id : "theme", name: name }) : raw).theme
    return { id: id, name: name, description: t.description, wallpaper: t.wallpaper, look: t.look, colors: t.colors, links: t.links || {} }
}

const UNLINK_SCRIPT = 'k=$1; shift; r=0; while [ "$k" -gt 0 ]; do if [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ] && rm -f -- "$2"; then r=$((r + 1)); if [ -e "$2.before-sylvaris" ] || [ -L "$2.before-sylvaris" ]; then mv -- "$2.before-sylvaris" "$2"; fi; fi; shift 2; k=$((k - 1)); done; echo "removed $r"; '

const LINK_SCRIPT = 'n=0; while [ $# -ge 2 ]; do if [ ! -e "$1" ]; then echo "missing $1"; elif [ "$(readlink "$2")" != "$1" ]; then if [ -e "$2" ] && [ ! -L "$2" ] && { [ -e "$2.before-sylvaris" ] || [ -L "$2.before-sylvaris" ] || ! mv -- "$2" "$2.before-sylvaris"; }; then echo "kept $2"; else mkdir -p "$(dirname "$2")" && ln -sfn "$1" "$2" && n=$((n + 1)); fi; fi; shift 2; done; echo "changed $n"'

export function staleLinks(catalog, links, home, configHome) {
    const keep = links || {}
    const out = []
    for (const entry of Object.values(catalog || {}))
        for (const [target, source] of Object.entries((entry && entry.links) || {}))
            if (!Object.prototype.hasOwnProperty.call(keep, target))
                out.push([expandHome(source, home), configHome + "/" + target])
    return out
}

export function linkCommand(links, home, configHome, stale = []) {
    const targets = Object.keys(links || {})
    if (targets.length === 0 && stale.length === 0)
        return null
    const pairs = targets.reduce((out, t) => out.concat([expandHome(links[t], home), configHome + "/" + t]), [])
    return ["sh", "-c", UNLINK_SCRIPT + LINK_SCRIPT, "sylvaris-links", String(stale.length)].concat(...stale, pairs)
}

export function parseLinkOutput(text) {
    const out = { changed: 0, removed: 0, missing: [], kept: [] }
    for (const line of String(text || "").split("\n")) {
        if (line.indexOf("missing ") === 0)
            out.missing.push(line.slice(8))
        else if (line.indexOf("kept ") === 0)
            out.kept.push(line.slice(5))
        else if (/^changed \d+$/.test(line))
            out.changed = Number(line.slice(8))
        else if (/^removed \d+$/.test(line))
            out.removed = Number(line.slice(8))
    }
    return out
}

const SHARE_SCRIPT = 'r="$1"; d="$1/$2"; [ -d "$r" ] && [ -w "$r" ] && [ -k "$r" ] || exit 0; umask 022; if [ ! -e "$d" ] && [ ! -L "$d" ]; then mkdir "$d" || exit 1; fi; [ ! -L "$d" ] && cd -P -- "$d" && [ "$(stat -c %u .)" = "$(id -u)" ] || exit 1; chmod 755 . && mkdir -p themes && chmod 755 themes || exit 1; for p in wallpaper:"$4" avatar:"$5"; do n=${p%%:*}; f=${p#*:}; [ -f "$f" ] && cp -f "$f" "$n.part" && chmod 644 "$n.part" && mv -f "$n.part" "$n"; done; printf "%s" "$6" > "themes/$3.json" && printf "%s" "$3" > theme && chmod 644 "themes/$3.json" theme'

export function shareCommand(root, user, id, wallpaper, avatar, json) {
    if (!root || !/^[A-Za-z0-9_][A-Za-z0-9_.-]*$/.test(user || "") || !/^[A-Za-z0-9_.-]+$/.test(id || ""))
        return null
    return ["sh", "-c", SHARE_SCRIPT, "sylvaris-share", root, user, id, wallpaper, avatar, json]
}
