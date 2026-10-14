import { validateKeys, uniqueName, nameOf, joinPath } from "./files.mjs"
import { natural } from "./viewer.mjs"

export const FORMATS = [
    { key: "zip", label: "zip" },
    { key: "7z", label: "7z" },
    { key: "tar.gz", label: "tar.gz" },
    { key: "tar.xz", label: "tar.xz" },
    { key: "tar.zst", label: "tar.zst" },
    { key: "tar", label: "tar" }
]
export const LEVELS = ["fast", "normal", "best"]
export const EXTRACTS = ["smart", "folder"]
export const VIEWS = ["list", "grid"]

export const DEFAULT_ARCHIVE = {
    view: "list",
    format: "zip",
    level: "normal",
    extract: "smart",
    reveal: true,
    keys: {}
}

export const ARCHIVE_ACTIONS = [
    { id: "open", label: "Open", keys: ["Return"] },
    { id: "extract", label: "Extract the selection", keys: ["CTRL+E"] },
    { id: "extractAll", label: "Extract everything", keys: ["CTRL+SHIFT+E"] },
    { id: "extractTo", label: "Extract to a folder", keys: ["CTRL+ALT+E"] },
    { id: "remove", label: "Remove from the archive", keys: ["Delete"] },
    { id: "back", label: "Back", keys: ["ALT+Left", "BackSpace"] },
    { id: "forward", label: "Forward", keys: ["ALT+Right"] },
    { id: "up", label: "Parent folder", keys: ["ALT+Up"] },
    { id: "location", label: "Type a location", keys: ["CTRL+L"] },
    { id: "reload", label: "Reload", keys: ["F5", "CTRL+R"] },
    { id: "search", label: "Filter this folder", keys: ["CTRL+F", "slash"] },
    { id: "selectAll", label: "Select all", keys: ["CTRL+A"] },
    { id: "invert", label: "Invert selection", keys: ["CTRL+SHIFT+I"] },
    { id: "grid", label: "Grid view", keys: ["CTRL+1"] },
    { id: "list", label: "List view", keys: ["CTRL+2"] },
    { id: "reveal", label: "Show the archive in SylFiles", keys: ["CTRL+ALT+O"] },
    { id: "quit", label: "Close the window", keys: ["CTRL+W", "CTRL+Q"] }
]

const EXTS = [
    "tar.gz", "tar.bz2", "tar.xz", "tar.zst", "tar.lz", "tar.lzma", "tar.lz4", "tar.z",
    "tgz", "tbz", "tbz2", "txz", "tzst", "tlz", "taz",
    "zip", "jar", "war", "apk", "xpi", "7z", "rar", "tar", "cpio", "iso", "cab", "deb", "rpm", "ar", "xar", "pkg", "lha", "lzh", "warc",
    "gz", "bz2", "xz", "zst", "lz", "lzma", "lz4", "z"
]
const SINGLE = ["gz", "bz2", "xz", "zst", "lz", "lzma", "lz4", "z"]
const WRITABLE = ["zip", "7z", "tar", "tar.gz", "tgz", "tar.bz2", "tbz", "tbz2", "tar.xz", "txz", "tar.zst", "tzst"]
const COMPRESSORS = { gz: "gzip", tgz: "gzip", taz: "gzip", bz2: "bzip2", tbz: "bzip2", tbz2: "bzip2", xz: "xz", txz: "xz", zst: "zstd", tzst: "zstd", lz: "lzip", tlz: "lzip", lzma: "lzma", lz4: "lz4", z: "compress" }
const LABELS = { zip: "ZIP archive", jar: "Java archive", war: "Java web archive", apk: "Android package", xpi: "Browser extension", "7z": "7-Zip archive", rar: "RAR archive", tar: "Tar archive", cpio: "cpio archive", iso: "Disc image", cab: "Cabinet archive", deb: "Debian package", rpm: "RPM package", ar: "ar archive", xar: "XAR archive", pkg: "Installer package", lha: "LHA archive", lzh: "LHA archive", warc: "Web archive" }

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

export function validateArchive(raw) {
    const v = isObject(raw) ? raw : {}
    const pick = (key, list) => list.indexOf(v[key]) >= 0 ? v[key] : DEFAULT_ARCHIVE[key]
    return Object.assign({}, v, {
        view: pick("view", VIEWS),
        format: pick("format", FORMATS.map(f => f.key)),
        level: pick("level", LEVELS),
        extract: pick("extract", EXTRACTS),
        reveal: typeof v.reveal === "boolean" ? v.reveal : DEFAULT_ARCHIVE.reveal,
        keys: validateKeys(v.keys, ARCHIVE_ACTIONS)
    })
}

export function archiveExt(name) {
    const low = String(name || "").toLowerCase()
    for (const ext of EXTS)
        if (low.endsWith("." + ext) && low.length > ext.length + 1 && low.lastIndexOf("/") < low.length - ext.length - 2)
            return ext
    return ""
}

export function isArchive(name) {
    return archiveExt(name) !== ""
}

export function stemOf(name) {
    const ext = archiveExt(name)
    return ext === "" ? name : name.slice(0, name.length - ext.length - 1)
}

export function writable(name) {
    return WRITABLE.indexOf(archiveExt(name)) >= 0
}

export function formatLabel(name) {
    const ext = archiveExt(name)
    if (ext === "")
        return "Archive"
    if (SINGLE.indexOf(ext) >= 0)
        return COMPRESSORS[ext] + " file"
    if (ext.startsWith("tar.") || COMPRESSORS[ext] !== undefined)
        return "Tar archive, " + COMPRESSORS[ext.startsWith("tar.") ? ext.slice(4) : ext]
    return LABELS[ext] || "Archive"
}

function clean(path) {
    return String(path || "").replace(/^(\.\/|\/)+/, "").replace(/\/+$/, "").replace(/\/+/g, "/")
}

export function treeOf(entries) {
    const tree = { "": [] }
    const put = (folder, item) => {
        if (tree[folder] === undefined)
            tree[folder] = []
        const list = tree[folder]
        const at = list.findIndex(x => x.name === item.name)
        if (at < 0)
            list.push(item)
        else if (!item.implied)
            list[at] = item
    }
    const ensure = path => {
        const parts = path.split("/")
        for (let i = 1; i < parts.length; i++) {
            const folder = parts.slice(0, i - 1).join("/")
            const here = parts.slice(0, i).join("/")
            if (tree[here] === undefined) {
                tree[here] = []
                put(folder, { name: parts[i - 1], dir: true, size: 0, modified: 0, link: "", implied: true })
            }
        }
    }
    for (const e of Array.isArray(entries) ? entries : []) {
        const path = clean(e.path)
        if (path === "" || path === ".")
            continue
        ensure(path)
        const slash = path.lastIndexOf("/")
        const folder = slash < 0 ? "" : path.slice(0, slash)
        put(folder, { name: path.slice(slash + 1), dir: e.dir === true, size: e.dir ? 0 : Number(e.size) || 0, modified: Number(e.mtime) || 0, link: e.link || "" })
        if (e.dir && tree[path] === undefined)
            tree[path] = []
    }
    return tree
}

export function folderOf(tree, inner) {
    return (tree[inner] || []).map(e => ({ name: e.name, dir: e.dir, size: e.size, modified: e.modified, link: e.link })).sort((a, b) => natural(a.name, b.name))
}

export function countOf(tree) {
    let files = 0
    let folders = 0
    let bytes = 0
    for (const key of Object.keys(tree))
        for (const e of tree[key]) {
            if (e.dir)
                folders++
            else {
                files++
                bytes += e.size
            }
        }
    return { files: files, folders: folders, bytes: bytes }
}

export function innerOf(archive, path) {
    return path === archive || !path.startsWith(archive + "/") ? "" : path.slice(archive.length + 1)
}

export function joinInner(inner, name) {
    return inner === "" ? name : inner + "/" + name
}

export function crumbsOf(archive, path) {
    const out = [{ label: nameOf(archive), path: archive, home: false }]
    let at = archive
    for (const part of innerOf(archive, path).split("/").filter(p => p !== "")) {
        at = joinPath(at, part)
        out.push({ label: part, path: at, home: false })
    }
    return out
}

export function newName(names, folder, format, taken) {
    const base = names.length === 1 ? (stemOf(names[0]).replace(/\.[^./]+$/, "") || names[0]) : folder === "/" ? "Archive" : nameOf(folder)
    return uniqueName(base + "." + format, taken, false)
}

export function outName(text, format) {
    const name = String(text || "").trim()
    if (name === "" || name.indexOf("/") >= 0)
        return ""
    return WRITABLE.indexOf(archiveExt(name)) >= 0 ? name : name + "." + format
}

export function extractNote(r) {
    if (r.cancelled)
        return "Stopped"
    if (r.failed.length > 0)
        return nameOf(r.failed[0].path) + ": " + r.failed[0].error
    if (r.ok.length === 1)
        return "Extracted to “" + nameOf(r.ok[0][1]) + "”"
    return "Extracted " + r.ok.length + (r.ok.every(p => p[0] === r.ok[0][0]) ? " items" : " archives")
}

export function compressNote(r) {
    if (r.cancelled)
        return "Stopped"
    if (r.failed.length > 0)
        return nameOf(r.failed[0].path) + ": " + r.failed[0].error
    return "Packed into “" + nameOf(r.ok[0][1]) + "”"
}
