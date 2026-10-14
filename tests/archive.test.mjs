import { test } from "node:test"
import assert from "node:assert/strict"
import {
    DEFAULT_ARCHIVE, validateArchive, ARCHIVE_ACTIONS, FORMATS, LEVELS, EXTRACTS,
    archiveExt, isArchive, stemOf, writable, formatLabel, treeOf, folderOf, crumbsOf, innerOf,
    newName, countOf, extractNote, compressNote, joinInner
} from "../shell/lib/archive.mjs"
import { keymap, validateKeys } from "../shell/lib/files.mjs"

test("defaults and validation keep only known values", () => {
    assert.deepEqual(validateArchive(undefined), DEFAULT_ARCHIVE)
    assert.deepEqual(DEFAULT_ARCHIVE, { view: "list", format: "zip", level: "normal", extract: "smart", reveal: true, keys: {} })
    const v = validateArchive({ view: "grid", format: "tar.zst", level: "best", extract: "folder", reveal: false, keys: { extract: "ctrl+shift+x", nope: ["F1"] } })
    assert.deepEqual(v, { view: "grid", format: "tar.zst", level: "best", extract: "folder", reveal: false, keys: { extract: ["CTRL+SHIFT+X"] } })
    assert.deepEqual(validateArchive({ view: "tiles", format: "rar", level: 3, extract: "here", reveal: "yes", keys: [] }), DEFAULT_ARCHIVE)
    assert.deepEqual(FORMATS.map(f => f.key), ["zip", "7z", "tar.gz", "tar.xz", "tar.zst", "tar"])
    assert.deepEqual(LEVELS, ["fast", "normal", "best"])
    assert.deepEqual(EXTRACTS, ["smart", "folder"])
})

test("archive keys have their own defaults and can be rebound", () => {
    const ids = ARCHIVE_ACTIONS.map(a => a.id)
    assert.equal(new Set(ids).size, ids.length)
    const k = keymap({}, ARCHIVE_ACTIONS)
    assert.equal(k.byCombo["CTRL+E"], "extract")
    assert.equal(k.byCombo["CTRL+SHIFT+E"], "extractAll")
    assert.equal(k.byCombo["Delete"], "remove")
    assert.equal(k.byCombo["CTRL+W"], "quit")
    const own = keymap({ extract: ["Delete"] }, ARCHIVE_ACTIONS)
    assert.equal(own.byCombo["Delete"], "extract")
    assert.deepEqual(validateKeys({ remove: [], back: "alt+b" }, ARCHIVE_ACTIONS), { remove: [], back: ["ALT+B"] })
    assert.deepEqual(validateKeys({ extract: ["F1"] }), {})
})

test("archiveExt knows every format libarchive reads, longest suffix first", () => {
    assert.equal(archiveExt("a.zip"), "zip")
    assert.equal(archiveExt("A.TAR.GZ"), "tar.gz")
    assert.equal(archiveExt("x.tgz"), "tgz")
    assert.equal(archiveExt("x.tar.zst"), "tar.zst")
    assert.equal(archiveExt("film.part1.rar"), "rar")
    assert.equal(archiveExt("notes.txt.gz"), "gz")
    for (const n of ["a.7z", "a.iso", "a.cab", "a.deb", "a.rpm", "a.cpio", "a.xar", "a.lha", "a.jar", "a.apk", "a.tar", "a.tar.bz2", "a.tar.xz", "a.tar.lz", "a.zst", "a.xz", "a.bz2"])
        assert.ok(isArchive(n), n)
    assert.ok(!isArchive("a.txt"))
    assert.ok(!isArchive(".zip"))
    assert.ok(!isArchive("zip"))
})

test("stemOf drops the archive extension, double ones too", () => {
    assert.equal(stemOf("photos.tar.gz"), "photos")
    assert.equal(stemOf("photos.zip"), "photos")
    assert.equal(stemOf("notes.txt.gz"), "notes.txt")
    assert.equal(stemOf("plain"), "plain")
    assert.equal(stemOf("x.tgz"), "x")
})

test("writable formats can be changed, the rest only read", () => {
    for (const n of ["a.zip", "a.7z", "a.tar", "a.tar.gz", "a.tgz", "a.tar.xz", "a.tar.zst", "a.tar.bz2"])
        assert.ok(writable(n), n)
    for (const n of ["a.rar", "a.iso", "a.deb", "a.gz", "a.jar", "a.cab"])
        assert.ok(!writable(n), n)
})

test("formatLabel names the format the way people say it", () => {
    assert.equal(formatLabel("a.zip"), "ZIP archive")
    assert.equal(formatLabel("a.tar.gz"), "Tar archive, gzip")
    assert.equal(formatLabel("a.tgz"), "Tar archive, gzip")
    assert.equal(formatLabel("a.7z"), "7-Zip archive")
    assert.equal(formatLabel("a.rar"), "RAR archive")
    assert.equal(formatLabel("a.iso"), "Disc image")
    assert.equal(formatLabel("a.txt.gz"), "gzip file")
    assert.equal(formatLabel("a.weird"), "Archive")
})

test("treeOf builds folders, adds the ones the archive leaves out and drops ./ and duplicates", () => {
    const tree = treeOf([
        { path: "./", dir: true, size: 0, mtime: 1 },
        { path: "./docs/", dir: true, size: 0, mtime: 5 },
        { path: "./docs/a.txt", dir: false, size: 10, mtime: 6 },
        { path: "deep/er/b.md", dir: false, size: 3, mtime: 7 },
        { path: "./docs/a.txt", dir: false, size: 12, mtime: 8 },
        { path: "/abs.txt", dir: false, size: 1, mtime: 9 },
        { path: "link", dir: false, size: 0, mtime: 2, link: "docs/a.txt" }
    ])
    assert.deepEqual(Object.keys(tree).sort(), ["", "deep", "deep/er", "docs"])
    assert.deepEqual(folderOf(tree, ""), [
        { name: "abs.txt", dir: false, size: 1, modified: 9, link: "" },
        { name: "deep", dir: true, size: 0, modified: 0, link: "" },
        { name: "docs", dir: true, size: 0, modified: 5, link: "" },
        { name: "link", dir: false, size: 0, modified: 2, link: "docs/a.txt" }
    ])
    assert.deepEqual(folderOf(tree, "docs"), [{ name: "a.txt", dir: false, size: 12, modified: 8, link: "" }])
    assert.deepEqual(folderOf(tree, "missing"), [])
    assert.deepEqual(countOf(tree), { files: 4, folders: 3, bytes: 16 })
    assert.deepEqual(treeOf(undefined), { "": [] })
})

test("crumbs and inner paths treat the archive like a folder", () => {
    assert.deepEqual(crumbsOf("/home/n/x.zip", "/home/n/x.zip/docs/sub"), [
        { label: "x.zip", path: "/home/n/x.zip", home: false },
        { label: "docs", path: "/home/n/x.zip/docs", home: false },
        { label: "sub", path: "/home/n/x.zip/docs/sub", home: false }
    ])
    assert.equal(innerOf("/a/x.zip", "/a/x.zip"), "")
    assert.equal(innerOf("/a/x.zip", "/a/x.zip/d/e"), "d/e")
    assert.equal(innerOf("/a/x.zip", "/elsewhere"), "")
    assert.equal(joinInner("", "a"), "a")
    assert.equal(joinInner("d", "a"), "d/a")
})

test("newName suggests a free archive name from what is being packed", () => {
    assert.equal(newName(["report.pdf"], "/home/n/Docs", "zip", []), "report.zip")
    assert.equal(newName(["photos"], "/home/n", "tar.gz", ["photos.tar.gz"]), "photos (2).tar.gz")
    assert.equal(newName(["a.txt", "b.txt"], "/home/n/Docs", "7z", []), "Docs.7z")
    assert.equal(newName(["a", "b"], "/", "zip", []), "Archive.zip")
})

test("notes say what happened", () => {
    assert.equal(extractNote({ ok: [["/a/x.zip", "/a/x"]], failed: [], cancelled: false, password: "" }), "Extracted to “x”")
    assert.equal(extractNote({ ok: [["/a/x.zip", "/a/x"], ["/a/y.zip", "/a/y"]], failed: [], cancelled: false, password: "" }), "Extracted 2 archives")
    assert.equal(extractNote({ ok: [], failed: [{ path: "/a/x.rar", error: "Truncated input file" }], cancelled: false, password: "" }), "x.rar: Truncated input file")
    assert.equal(extractNote({ ok: [], failed: [], cancelled: true, password: "" }), "Stopped")
    assert.equal(compressNote({ ok: [["", "/a/b.zip"]], failed: [], cancelled: false }), "Packed into “b.zip”")
    assert.equal(compressNote({ ok: [], failed: [{ path: "/a/b.zip", error: "No space left on device" }], cancelled: false }), "b.zip: No space left on device")
})
