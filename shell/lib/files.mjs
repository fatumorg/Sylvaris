import { natural, pathFrom, uriOf } from "./viewer.mjs"
import { normalize, keyName } from "./keys.mjs"

const g = cp => String.fromCodePoint(cp)

export const VIEWS = ["grid", "list"]
export const SORTS = ["name", "modified", "size", "kind"]
export const ICON_STYLES = ["glyphs", "theme"]
export const CLICKS = ["double", "single"]
export const TYPING = ["filter", "jump"]
export const SECTIONS = ["places", "bookmarks", "devices"]
export const ICON_MIN = 40
export const ICON_MAX = 160

export const DEFAULT_FILES = {
    view: "grid",
    iconSize: 64,
    sort: "name",
    descending: false,
    foldersFirst: true,
    hidden: false,
    thumbnails: true,
    icons: "glyphs",
    sidebar: true,
    sections: SECTIONS.slice(),
    details: false,
    click: "double",
    typing: "filter",
    start: "~",
    confirmTrash: false,
    openArchives: true,
    bookmarks: [],
    keys: {}
}

export const GLYPH = {
    folder: g(0xF024B),
    folderOpen: g(0xF0770),
    home: g(0xF02DC),
    desktop: g(0xF07C0),
    documents: g(0xF0C82),
    downloads: g(0xF024D),
    music: g(0xF1359),
    pictures: g(0xF024F),
    videos: g(0xF19FA),
    drive: g(0xF02CA),
    usb: g(0xF129E),
    card: g(0xF0479),
    disc: g(0xF05EE),
    phone: g(0xF011C),
    network: g(0xF048D),
    eject: g(0xF01EA),
    archive: g(0xF05C4),
    extract: g(0xF125B),
    compress: g(0xF1259),
    trash: g(0xF0A7A),
    bookmark: g(0xF00C0),
    forward: g(0xF0054),
    list: g(0xF0572),
    sort: g(0xF04BA),
    eyeOff: g(0xF0209),
    newFolder: g(0xF0257),
    newFile: g(0xF0752),
    cut: g(0xF0190),
    paste: g(0xF0192),
    terminal: g(0xF018D),
    more: g(0xF01D9),
    restore: g(0xF0670),
    deleteForever: g(0xF05E8),
    newTab: g(0xF075C),
    openWith: g(0xF08C6),
    keyboard: g(0xF097B),
    alert: g(0xF05D6),
    lock: g(0xF0341),
    selectAll: g(0xF0486),
    clock: g(0xF0150),
    weight: g(0xF05A1)
}

export const FILE_ACTIONS = [
    { id: "open", label: "Open", keys: ["Return"] },
    { id: "openTab", label: "Open in a new tab", keys: ["CTRL+Return"] },
    { id: "openWith", label: "Open with another app", keys: ["CTRL+O"] },
    { id: "back", label: "Back", keys: ["ALT+Left", "BackSpace"] },
    { id: "forward", label: "Forward", keys: ["ALT+Right"] },
    { id: "up", label: "Parent folder", keys: ["ALT+Up"] },
    { id: "home", label: "Home folder", keys: ["ALT+Home"] },
    { id: "reload", label: "Reload", keys: ["F5", "CTRL+R"] },
    { id: "location", label: "Type a location", keys: ["CTRL+L"] },
    { id: "search", label: "Filter this folder", keys: ["CTRL+F", "slash"] },
    { id: "newFolder", label: "New folder", keys: ["CTRL+SHIFT+N"] },
    { id: "newFile", label: "New empty file", keys: ["CTRL+ALT+N"] },
    { id: "rename", label: "Rename", keys: ["F2"] },
    { id: "copy", label: "Copy", keys: ["CTRL+C"] },
    { id: "cut", label: "Cut", keys: ["CTRL+X"] },
    { id: "paste", label: "Paste", keys: ["CTRL+V"] },
    { id: "copyPath", label: "Copy path", keys: ["CTRL+SHIFT+C"] },
    { id: "compress", label: "Compress into an archive", keys: ["CTRL+ALT+C"] },
    { id: "extract", label: "Extract here", keys: ["CTRL+ALT+X"] },
    { id: "trash", label: "Move to the trash", keys: ["Delete"] },
    { id: "delete", label: "Delete permanently", keys: ["SHIFT+Delete"] },
    { id: "undo", label: "Undo", keys: ["CTRL+Z"] },
    { id: "selectAll", label: "Select all", keys: ["CTRL+A"] },
    { id: "invert", label: "Invert selection", keys: ["CTRL+SHIFT+I"] },
    { id: "hidden", label: "Show hidden files", keys: ["CTRL+H"] },
    { id: "grid", label: "Grid view", keys: ["CTRL+1"] },
    { id: "list", label: "List view", keys: ["CTRL+2"] },
    { id: "zoomIn", label: "Bigger icons", keys: ["CTRL+plus", "CTRL+equal"] },
    { id: "zoomOut", label: "Smaller icons", keys: ["CTRL+minus"] },
    { id: "zoomReset", label: "Default icon size", keys: ["CTRL+0"] },
    { id: "sidebar", label: "Show the sidebar", keys: ["F9"] },
    { id: "details", label: "Show the details pane", keys: ["ALT+Return", "CTRL+I"] },
    { id: "bookmark", label: "Bookmark this folder", keys: ["CTRL+D"] },
    { id: "terminal", label: "Open a terminal here", keys: ["F4"] },
    { id: "newTab", label: "New tab", keys: ["CTRL+T"] },
    { id: "closeTab", label: "Close tab", keys: ["CTRL+W"] },
    { id: "nextTab", label: "Next tab", keys: ["CTRL+Tab", "CTRL+Next"] },
    { id: "prevTab", label: "Previous tab", keys: ["CTRL+SHIFT+Tab", "CTRL+Prior"] },
    { id: "quit", label: "Close the window", keys: ["CTRL+Q"] }
]

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

function placePath(s) {
    if (typeof s !== "string")
        return ""
    const t = s.trim()
    if (t === "~")
        return "~"
    if (t.startsWith("~/")) {
        const p = pathFrom(t.slice(1))
        return p === "" ? "" : p === "/" ? "~" : "~" + p
    }
    return t.startsWith("/") ? pathFrom(t) : ""
}

export function validateKeys(raw, actions) {
    const out = {}
    if (!isObject(raw))
        return out
    for (const a of actions || FILE_ACTIONS) {
        if (!Object.prototype.hasOwnProperty.call(raw, a.id))
            continue
        const v = raw[a.id]
        const list = typeof v === "string" ? [v] : Array.isArray(v) ? v.filter(s => typeof s === "string") : null
        if (list === null)
            continue
        const given = list.filter(s => s.trim() !== "")
        const keys = given.map(normalize).filter((s, i, all) => s !== "" && all.indexOf(s) === i)
        if (given.length > 0 && keys.length === 0)
            continue
        out[a.id] = keys
    }
    return out
}

export function validateFiles(raw) {
    const v = isObject(raw) ? raw : {}
    const pick = (key, list) => list.indexOf(v[key]) >= 0 ? v[key] : DEFAULT_FILES[key]
    const bool = key => typeof v[key] === "boolean" ? v[key] : DEFAULT_FILES[key]
    const marks = []
    for (const b of Array.isArray(v.bookmarks) ? v.bookmarks : []) {
        const p = placePath(b)
        if (p !== "" && marks.indexOf(p) < 0)
            marks.push(p)
    }
    const order = []
    for (const k of Array.isArray(v.sections) ? v.sections : [])
        if (SECTIONS.indexOf(k) >= 0 && order.indexOf(k) < 0)
            order.push(k)
    for (const k of SECTIONS)
        if (order.indexOf(k) < 0)
            order.push(k)
    const start = placePath(v.start)
    return Object.assign({}, v, {
        view: pick("view", VIEWS),
        iconSize: Number.isInteger(v.iconSize) && v.iconSize >= ICON_MIN && v.iconSize <= ICON_MAX ? v.iconSize : DEFAULT_FILES.iconSize,
        sort: pick("sort", SORTS),
        descending: bool("descending"),
        foldersFirst: bool("foldersFirst"),
        hidden: bool("hidden"),
        thumbnails: bool("thumbnails"),
        icons: pick("icons", ICON_STYLES),
        sidebar: bool("sidebar"),
        sections: order,
        details: bool("details"),
        click: pick("click", CLICKS),
        typing: pick("typing", TYPING),
        start: start === "" ? DEFAULT_FILES.start : start,
        confirmTrash: bool("confirmTrash"),
        openArchives: bool("openArchives"),
        bookmarks: marks,
        keys: validateKeys(v.keys)
    })
}

export function keymap(overrides, actions) {
    const list = actions || FILE_ACTIONS
    const own = validateKeys(overrides, list)
    const byAction = {}
    const byCombo = {}
    for (const a of list)
        byAction[a.id] = own[a.id] !== undefined ? own[a.id] : a.keys.map(normalize)
    for (const pass of [true, false])
        for (const a of list)
            if ((own[a.id] !== undefined) === pass)
                for (const c of byAction[a.id])
                    if (byCombo[c] === undefined)
                        byCombo[c] = a.id
    return { byAction: byAction, byCombo: byCombo }
}

const QT_MODS = [[0x10000000, "SUPER"], [0x04000000, "CTRL"], [0x08000000, "ALT"], [0x02000000, "SHIFT"]]
const SYMBOLS = {
    0x2b: "plus", 0x2d: "minus", 0x3d: "equal", 0x2f: "slash", 0x2e: "period", 0x2c: "comma", 0x5c: "backslash",
    0x3b: "semicolon", 0x27: "apostrophe", 0x60: "grave", 0x5b: "bracketleft", 0x5d: "bracketright"
}

export function comboOf(key, modifiers) {
    if (key === 0x01000002)
        return comboOf(0x01000001, modifiers | 0x02000000)
    const symbol = SYMBOLS[key]
    const name = symbol || keyName(key, "")
    if (!name)
        return ""
    const mods = QT_MODS.filter(m => (modifiers & m[0]) !== 0 && !(symbol && m[1] === "SHIFT")).map(m => m[1])
    return normalize(mods.concat([name]).join("+"))
}

export function joinPath(dir, name) {
    return dir === "/" ? "/" + name : dir + "/" + name
}

export function parentOf(path) {
    if (path === "/" || path === "")
        return path
    const i = path.lastIndexOf("/")
    return i <= 0 ? "/" : path.slice(0, i)
}

export function nameOf(path) {
    return path === "/" ? "/" : path.slice(path.lastIndexOf("/") + 1)
}

export function expand(text, home, cwd) {
    let s = String(text === undefined || text === null ? "" : text).trim()
    if (s === "")
        return ""
    if (s === "~" || s.startsWith("~/"))
        s = home + s.slice(1)
    else if (!s.startsWith("/") && !s.startsWith("file://"))
        s = joinPath(cwd, s)
    return pathFrom(s)
}

export function pretty(path, home) {
    if (home !== "" && home !== "/" && path === home)
        return "~"
    if (home !== "" && home !== "/" && path.startsWith(home + "/"))
        return "~" + path.slice(home.length)
    return path
}

export function crumbs(path, home) {
    const underHome = home !== "" && home !== "/" && (path === home || path.startsWith(home + "/"))
    const out = [underHome ? { label: "Home", path: home, home: true } : { label: "/", path: "/", home: false }]
    let at = underHome ? home : "/"
    for (const part of path.slice(at.length).split("/").filter(p => p !== "")) {
        at = joinPath(at, part)
        out.push({ label: part, path: at, home: false })
    }
    return out
}

const EXTS = {
    image: "png jpg jpeg gif bmp webp svg tif tiff tga ico heic heif avif jxl psd xcf kra cr2 nef dng",
    video: "mp4 m4v mkv webm mov avi ogv mpg mpeg wmv flv 3gp",
    audio: "mp3 flac ogg oga opus wav m4a aac wma aiff mid midi",
    pdf: "pdf",
    archive: "zip tar gz tgz bz2 xz zst 7z rar lz lzma tbz2 txz cab iso deb rpm apk jar",
    code: "js mjs cjs ts tsx jsx py rb go rs c h cc cpp hpp cs java kt swift php sh bash zsh fish lua nix qml json yaml yml toml xml html htm css scss sql pl r dart zig hs ml ex exs vue svelte ini conf cfg",
    text: "txt md markdown rst log csv tsv org tex nfo",
    document: "doc docx odt rtf epub",
    sheet: "xls xlsx ods",
    slides: "ppt pptx odp",
    font: "ttf otf woff woff2"
}

const KIND_OF_EXT = {}
for (const kind of Object.keys(EXTS))
    for (const ext of EXTS[kind].split(" "))
        KIND_OF_EXT[ext] = kind

const KIND_GLYPH = {
    folder: g(0xF024B), image: g(0xF021F), video: g(0xF022B), audio: g(0xF0223), pdf: g(0xF0226), archive: g(0xF05C4),
    code: g(0xF022E), text: g(0xF0219), document: g(0xF022C), sheet: g(0xF021B), slides: g(0xF0227), font: g(0xF06D6), file: g(0xF0214)
}

const KIND_ICON = {
    folder: "folder", image: "image-x-generic", video: "video-x-generic", audio: "audio-x-generic", pdf: "application-pdf",
    archive: "package-x-generic", code: "text-x-script", text: "text-x-generic", document: "x-office-document",
    sheet: "x-office-spreadsheet", slides: "x-office-presentation", font: "font-x-generic", file: "text-x-generic"
}

const KIND_LABEL = {
    image: "image", video: "video", audio: "audio", pdf: "document", archive: "archive", code: "source", text: "text",
    document: "document", sheet: "spreadsheet", slides: "presentation", font: "font", file: "file"
}

function extOfName(name) {
    const dot = name.lastIndexOf(".")
    return dot <= 0 ? "" : name.slice(dot + 1).toLowerCase()
}

export function kindOf(name, isDir) {
    if (isDir)
        return "folder"
    return KIND_OF_EXT[extOfName(name)] || "file"
}

export function kindLabel(name, isDir) {
    if (isDir)
        return "Folder"
    const ext = extOfName(name)
    return ext === "" ? "File" : ext.toUpperCase() + " " + KIND_LABEL[kindOf(name, false)]
}

export function glyphOf(kind) {
    return KIND_GLYPH[kind] || KIND_GLYPH.file
}

export function themeIcon(kind) {
    return KIND_ICON[kind] || KIND_ICON.file
}

const BY = {
    name: () => 0,
    modified: (a, b) => a.modified - b.modified,
    size: (a, b) => a.size - b.size,
    kind: (a, b) => {
        const x = kindOf(a.name, a.dir)
        const y = kindOf(b.name, b.dir)
        const ex = extOfName(a.name)
        const ey = extOfName(b.name)
        return x < y ? -1 : x > y ? 1 : ex < ey ? -1 : ex > ey ? 1 : 0
    }
}

export function arrange(entries, opts) {
    const q = String(opts.query || "").trim().toLowerCase()
    const by = BY[opts.sort] || BY.name
    const sign = opts.descending ? -1 : 1
    return entries.filter(e => (opts.hidden || e.name.charAt(0) !== ".") && (q === "" || e.name.toLowerCase().indexOf(q) >= 0))
        .sort((a, b) => {
            if (opts.foldersFirst && a.dir !== b.dir)
                return a.dir ? -1 : 1
            return sign * (by(a, b) || natural(a.name, b.name))
        })
}

export function sizeText(bytes) {
    if (typeof bytes !== "number" || !(bytes >= 0))
        return ""
    if (bytes < 1000)
        return bytes + (bytes === 1 ? " byte" : " bytes")
    const units = ["kB", "MB", "GB", "TB", "PB"]
    let v = bytes / 1000
    let i = 0
    while (v >= 999.5 && i < units.length - 1) {
        v /= 1000
        i++
    }
    return (v < 9.95 ? v.toFixed(1) : String(Math.round(v))) + " " + units[i]
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

export function whenText(ms, now) {
    if (typeof ms !== "number" || !(ms > 0))
        return ""
    const d = new Date(ms)
    const n = new Date(now)
    const pad = x => String(x).padStart(2, "0")
    const time = pad(d.getHours()) + ":" + pad(d.getMinutes())
    const day = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime()
    const diff = Math.round((day(n) - day(d)) / 86400000)
    if (diff === 0)
        return "Today " + time
    if (diff === 1)
        return "Yesterday " + time
    return d.getDate() + " " + MONTHS[d.getMonth()] + (d.getFullYear() === n.getFullYear() ? "" : " " + d.getFullYear())
}

export function countText(n) {
    return n + (n === 1 ? " item" : " items")
}

export function summary(entries, selected) {
    if (selected.length === 0)
        return countText(entries.length)
    let bytes = 0
    let files = 0
    for (const e of entries)
        if (!e.dir && selected.indexOf(e.name) >= 0) {
            bytes += e.size
            files++
        }
    return selected.length + " of " + entries.length + " selected" + (files > 0 ? " · " + sizeText(bytes) : "")
}

const DOUBLE = ["tar.gz", "tar.bz2", "tar.xz", "tar.zst", "tar.lz", "tar.lzma"]

function splitName(name, isDir) {
    if (isDir)
        return [name, ""]
    const lower = name.toLowerCase()
    for (const d of DOUBLE)
        if (lower.endsWith("." + d) && name.length > d.length + 1)
            return [name.slice(0, name.length - d.length - 1), name.slice(name.length - d.length - 1)]
    const dot = name.lastIndexOf(".")
    return dot <= 0 ? [name, ""] : [name.slice(0, dot), name.slice(dot)]
}

export function uniqueName(name, taken, isDir) {
    if (taken.indexOf(name) < 0)
        return name
    const parts = splitName(name, isDir)
    const m = /^(.*) \((\d+)\)$/.exec(parts[0])
    const base = m ? m[1] : parts[0]
    let n = m ? Number(m[2]) + 1 : 2
    while (taken.indexOf(base + " (" + n + ")" + parts[1]) >= 0)
        n++
    return base + " (" + n + ")" + parts[1]
}

export function checkName(name, taken, current) {
    const s = String(name === undefined || name === null ? "" : name)
    if (s.trim() === "")
        return "Type a name"
    if (s.indexOf("/") >= 0 || s.indexOf("\u0000") >= 0)
        return "Names cannot contain /"
    if (s === "." || s === "..")
        return "That name is reserved"
    if (encodeURIComponent(s).replace(/%[0-9A-F]{2}/g, "x").length > 255)
        return "That name is too long"
    if (s !== current && taken.indexOf(s) >= 0)
        return "Something with that name is already here"
    return ""
}

export function pick(selected, order, name, mode, anchor) {
    if (mode === "toggle")
        return { selected: selected.indexOf(name) >= 0 ? selected.filter(n => n !== name) : selected.concat([name]), anchor: name }
    const a = order.indexOf(anchor)
    const b = order.indexOf(name)
    if ((mode === "range" || mode === "extend") && a >= 0 && b >= 0) {
        const span = order.slice(Math.min(a, b), Math.max(a, b) + 1)
        return { selected: mode === "range" ? span : selected.concat(span.filter(n => selected.indexOf(n) < 0)), anchor: anchor }
    }
    return { selected: [name], anchor: name }
}

export function invert(selected, order) {
    return order.filter(n => selected.indexOf(n) < 0)
}

export function nextIndex(index, key, cols, count, rows) {
    if (count <= 0)
        return -1
    if (key === "end")
        return count - 1
    if (index < 0 || key === "home")
        return 0
    const c = Math.max(1, cols)
    const page = c * Math.max(1, rows)
    if (key === "left")
        return Math.max(0, index - 1)
    if (key === "right")
        return Math.min(count - 1, index + 1)
    if (key === "up")
        return index - c >= 0 ? index - c : index
    if (key === "down")
        return index + c < count ? index + c : Math.floor(index / c) < Math.floor((count - 1) / c) ? count - 1 : index
    if (key === "pageUp")
        return Math.max(0, index - page)
    if (key === "pageDown")
        return Math.min(count - 1, index + page)
    return index
}

export function bandHits(band, grid) {
    const x0 = Math.min(band.x, band.x + band.w)
    const x1 = Math.max(band.x, band.x + band.w)
    const y0 = Math.min(band.y, band.y + band.h)
    const y1 = Math.max(band.y, band.y + band.h)
    if (x1 - x0 <= 0 || y1 - y0 <= 0 || grid.count <= 0)
        return []
    const c0 = Math.max(0, Math.floor(x0 / grid.cellW))
    const c1 = Math.min(grid.cols - 1, Math.ceil(x1 / grid.cellW) - 1)
    const r0 = Math.max(0, Math.floor(y0 / grid.cellH))
    const r1 = Math.ceil(y1 / grid.cellH) - 1
    const out = []
    for (let r = r0; r <= r1; r++)
        for (let c = c0; c <= c1; c++) {
            const i = r * grid.cols + c
            if (i < grid.count)
                out.push(i)
        }
    return out
}

export function visit(tab, path) {
    if (path === tab.path)
        return tab
    return Object.assign({}, tab, { path: path, back: tab.back.concat([tab.path]).slice(-50), forward: [] })
}

export function goBack(tab) {
    if (tab.back.length === 0)
        return tab
    return Object.assign({}, tab, { path: tab.back[tab.back.length - 1], back: tab.back.slice(0, -1), forward: [tab.path].concat(tab.forward) })
}

export function goForward(tab) {
    if (tab.forward.length === 0)
        return tab
    return Object.assign({}, tab, { path: tab.forward[0], back: tab.back.concat([tab.path]), forward: tab.forward.slice(1) })
}

export function userDirs(text, home) {
    const out = {}
    for (const line of String(text || "").split("\n")) {
        const m = /^\s*XDG_([A-Z]+)_DIR="(.*)"\s*$/.exec(line)
        if (!m)
            continue
        const p = pathFrom(m[2].replace(/^\$HOME/, home))
        if (p !== "")
            out[m[1]] = p
    }
    return out
}

const PLACES = [["DESKTOP", "Desktop", "desktop"], ["DOCUMENTS", "Documents", "documents"], ["DOWNLOAD", "Downloads", "downloads"],
    ["MUSIC", "Music", "music"], ["PICTURES", "Pictures", "pictures"], ["VIDEOS", "Videos", "videos"]]

export function places(home, dirs) {
    const out = [{ label: "Home", path: home, glyph: GLYPH.home }]
    for (const p of PLACES) {
        const path = dirs[p[0]] !== undefined ? dirs[p[0]] : joinPath(home, p[1])
        if (path !== home)
            out.push({ label: nameOf(path), path: path, glyph: GLYPH[p[2]] })
    }
    return out
}

export function gtkBookmarks(text) {
    const out = []
    for (const line of String(text || "").split("\n")) {
        const t = line.trim()
        if (!t.startsWith("file://"))
            continue
        const space = t.indexOf(" ")
        const path = pathFrom(space < 0 ? t : t.slice(0, space))
        if (path !== "")
            out.push({ path: path, label: space < 0 ? nameOf(path) : t.slice(space + 1).trim() || nameOf(path) })
    }
    return out
}

export function trashInfo(text) {
    const path = /^Path=(.*)$/m.exec(String(text || ""))
    const date = /^DeletionDate=(.*)$/m.exec(String(text || ""))
    let p = ""
    if (path) {
        try {
            p = decodeURIComponent(path[1].trim())
        } catch (e) {
            p = ""
        }
    }
    return { path: p, date: date ? date[1].trim() : "" }
}

export function pastePlan(items, dest, mode) {
    const pairs = []
    const skipped = []
    for (const it of items) {
        if (dest === it.path || dest.startsWith(it.path + "/")) {
            skipped.push({ path: it.path, why: "A folder cannot go inside itself" })
            continue
        }
        if (mode === "move" && parentOf(it.path) === dest) {
            skipped.push({ path: it.path, why: "Already here" })
            continue
        }
        pairs.push([it.path, joinPath(dest, nameOf(it.path))])
    }
    return { pairs: pairs, skipped: skipped }
}

export function inverse(op) {
    let inv = null
    if (op.kind === "move" || op.kind === "rename")
        inv = { kind: "move", pairs: (op.moved || op.pairs).map(p => [p[1], p[0]]).reverse() }
    else if (op.kind === "copy")
        inv = { kind: "trash", paths: (op.made || op.pairs.map(p => p[1])).slice() }
    else if (op.kind === "create")
        inv = { kind: "trash", paths: op.paths.slice() }
    else if (op.kind === "trash")
        inv = { kind: "restore", paths: op.paths.slice() }
    const back = (op.binned || []).filter(n => n !== "")
    if (inv !== null && (inv.pairs || inv.paths).length === 0)
        inv = back.length > 0 ? { kind: "bin", names: back } : null
    else if (inv !== null && back.length > 0)
        inv.then = { kind: "bin", names: back }
    return inv
}

const CLASH_BUTTONS = [["skip", "Skip", "S"], ["both", "Keep both", "K"], ["rename", "Rename…", "N"], ["replace", "Replace", "R"], ["merge", "Merge", "M"]]

export const CLASH_KEYS = { M: "merge", R: "replace", S: "skip", K: "both", N: "rename" }

export function clashView(c, home, now) {
    const mine = c.existing
    const theirs = c.incoming
    const detail = f => {
        if (!f.dir && f.size < 0)
            return "Not made yet"
        const what = f.dir ? (f.count >= 0 ? countText(f.count) : "") : sizeText(f.size)
        const when = whenText(f.time, now)
        return [what, when].filter(x => x !== "").join(" · ")
    }
    const same = !theirs.dir && !mine.dir && theirs.size === mine.size && theirs.size >= 0 && Math.abs(theirs.time - mine.time) < 2000
    const badge = (a, b) => {
        if (same)
            return ""
        const out = []
        if (a.time > 0 && b.time > 0 && a.time > b.time + 1000)
            out.push("newer")
        if (!a.dir && !b.dir && a.size >= 0 && b.size >= 0 && a.size > b.size)
            out.push("larger")
        const text = out.join(", ")
        return text === "" ? "" : text.charAt(0).toUpperCase() + text.slice(1)
    }
    const from = c.op === "restore" ? "From the trash" : c.op === "compress" ? "The new archive" : c.op === "extract" ? "From " + nameOf(c.from) : "From " + pretty(c.from, home)
    const where = c.op === "add" ? "the archive" : pretty(c.folder, home)
    const folders = theirs.dir && mine.dir
    const primary = c.actions.indexOf("merge") >= 0 ? "merge" : c.actions.indexOf("replace") >= 0 ? "replace" : "both"
    return {
        title: primary === "merge" ? "Merge “" + c.name + "”?" : primary === "replace" ? "Replace “" + c.name + "”?" : "“" + c.name + "” is already there",
        text: folders ? "A folder called “" + c.name + "” is already in " + where + ". Merging adds what is new and asks about anything with the same name." : "Something called “" + c.name + "” is already in " + where + ".",
        primary: primary,
        same: same,
        sides: [
            { label: "Already there", detail: detail(mine), badge: badge(mine, theirs), folder: mine.dir },
            { label: from, detail: detail(theirs), badge: badge(theirs, mine), folder: theirs.dir }
        ],
        buttons: CLASH_BUTTONS.filter(b => c.actions.indexOf(b[0]) >= 0).map(b => ({ id: b[0], label: b[1], key: b[2] }))
    }
}

const CLASH_WORDS = { keep: "both", stop: "cancel" }

export function clashAnswer(words, actions) {
    const list = words.map(w => String(w))
    const first = (list[0] || "").toLowerCase()
    const what = CLASH_WORDS[first] || first
    if (what !== "cancel" && actions.indexOf(what) < 0)
        throw new Error(what + " is not one of: " + actions.concat(["cancel"]).join(", "))
    const all = what !== "rename" && list[1] === "all"
    const name = what === "rename" ? list.slice(1).join(" ").trim() : ""
    if (what === "rename" && name === "")
        throw new Error("rename needs a name")
    return { do: what, all: all, name: name }
}

const WANTS = {
    image: ["Graphics", "Viewer", "Photography"],
    video: ["Video", "AudioVideo", "Player"],
    audio: ["Audio", "AudioVideo", "Player", "Music"],
    pdf: ["Viewer", "Office"],
    archive: ["Archiving", "Compression"],
    code: ["TextEditor", "Development", "IDE"],
    text: ["TextEditor"],
    document: ["Office", "WordProcessor"],
    sheet: ["Office", "Spreadsheet"],
    slides: ["Office", "Presentation"],
    font: ["Viewer"],
    folder: ["FileManager", "TerminalEmulator"],
    file: ["TextEditor"]
}

export function openers(apps, kind, query) {
    const want = WANTS[kind] || []
    const q = String(query || "").trim().toLowerCase()
    const usable = apps.filter(a => String(a.execString || "").trim() !== "" && a.id !== "sylvaris-files" && (q === "" || a.name.toLowerCase().indexOf(q) >= 0))
    const fits = a => (a.categories || []).some(c => want.indexOf(c) >= 0)
    const byName = (a, b) => a.name.localeCompare(b.name)
    return usable.filter(fits).sort(byName).concat(usable.filter(a => !fits(a)).sort(byName))
}

const DRIVE_GLYPH = { usb: GLYPH.usb, card: GLYPH.card, optical: GLYPH.disc, phone: GLYPH.phone, image: GLYPH.disc, disk: GLYPH.drive, network: GLYPH.network }

export function moved(list, from, to) {
    const out = list.slice()
    if (from === to || from < 0 || to < 0 || from >= out.length || to >= out.length)
        return out
    out.splice(to, 0, out.splice(from, 1)[0])
    return out
}

export function sidebarOf(src) {
    const out = []
    for (const p of places(src.home, src.dirs))
        out.push({ section: "places", label: p.label, path: p.path, glyph: p.glyph, own: false, removable: false })
    const seen = []
    for (const b of src.bookmarks) {
        const path = b === "~" ? src.home : b.startsWith("~/") ? src.home + b.slice(1) : b
        if (seen.indexOf(path) < 0) {
            seen.push(path)
            out.push({ section: "bookmarks", label: nameOf(path), path: path, glyph: GLYPH.bookmark, own: true, removable: false })
        }
    }
    for (const b of src.gtk)
        if (seen.indexOf(b.path) < 0) {
            seen.push(b.path)
            out.push({ section: "bookmarks", label: b.label, path: b.path, glyph: GLYPH.bookmark, own: false, removable: false })
        }
    out.push({ section: "devices", label: "File system", path: "/", glyph: GLYPH.drive, own: false, removable: false })
    for (const d of src.drives)
        out.push({ section: "devices", label: d.label, path: d.path, glyph: d.locked ? GLYPH.lock : DRIVE_GLYPH[d.kind] || GLYPH.drive, own: false, removable: d.ejectable, drive: d })
    out.push({ section: "devices", label: "Trash", path: src.trash, glyph: GLYPH.trash, own: false, removable: false })
    let lit = false
    return out.map(x => {
        const active = !lit && x.path !== "" && x.path === src.current
        lit = lit || active
        return Object.assign({ drive: null }, x, { active: active })
    })
}

export function pathsOfUris(text) {
    return String(text || "").split(/\r?\n/).map(l => l.trim()).filter(l => l !== "" && l.charAt(0) !== "#").map(pathFrom).filter(p => p !== "")
}

export function urisOf(paths) {
    return paths.map(uriOf).join("\r\n") + "\r\n"
}

const KEY_TEXT = {
    SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift", plus: "+", minus: "-", equal: "=", slash: "/", period: ".", comma: ",",
    backslash: "\\", semicolon: ";", apostrophe: "'", grave: "`", bracketleft: "[", bracketright: "]", Return: "Enter", BackSpace: "Backspace",
    Delete: "Del", Insert: "Ins", Prior: "PgUp", Next: "PgDn", space: "Space"
}

export function keyText(combo) {
    return combo === "" ? "" : combo.split("+").map(p => KEY_TEXT[p] || p).join("+")
}

export function statInfo(text) {
    const lines = String(text || "").split("\n").map(l => l.trim())
    const head = lines[0].split("|")
    const num = s => /^\d+$/.test(s || "") ? Number(s) : -1
    return { perm: head[0] || "", owner: head[1] || "", group: head[2] || "", count: num(lines[1]), bytes: num(lines[2]) }
}

export function pickStart(mode, path, home) {
    const p = String(path || "")
    const absolute = p.startsWith("/")
    if (mode === "save") {
        const name = absolute ? nameOf(p) : ""
        return { folder: absolute ? parentOf(p) : home, name: name === "termfilechooser.tmp" ? "" : name, path: "" }
    }
    return { folder: "", name: "", path: absolute ? p : home }
}

export function pickTitle(mode, multiple) {
    if (mode === "save")
        return "Save as"
    if (mode === "folder")
        return multiple ? "Choose folders" : "Choose a folder"
    return multiple ? "Open files" : "Open a file"
}

export function pickChoice(mode, multiple, items, folder) {
    if (mode === "save")
        return []
    const fit = items.filter(i => mode === "folder" ? i.dir : !i.dir).map(i => i.path)
    if (mode === "folder" && fit.length === 0)
        return [folder]
    return multiple ? fit : fit.slice(0, 1)
}
