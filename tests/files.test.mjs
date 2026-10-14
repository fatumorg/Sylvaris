import { test } from "node:test"
import assert from "node:assert/strict"
import {
    DEFAULT_FILES, validateFiles, FILE_ACTIONS, validateKeys, keymap, comboOf,
    joinPath, parentOf, nameOf, expand, pretty, crumbs,
    kindOf, kindLabel, glyphOf, themeIcon, arrange, sizeText, whenText, summary,
    uniqueName, checkName, pick, invert, nextIndex, bandHits,
    visit, goBack, goForward, userDirs, places, gtkBookmarks, mounts, trashInfo,
    pastePlan, inverse, openers, sidebarOf, pathsOfUris, urisOf, keyText, statInfo
} from "../shell/lib/files.mjs"

const CTRL = 0x04000000
const SHIFT = 0x02000000
const ALT = 0x08000000

test("validateFiles keeps good values, replaces bad ones with defaults and keeps unknown keys", () => {
    assert.deepEqual(validateFiles(undefined), DEFAULT_FILES)
    const v = validateFiles({ view: "list", iconSize: 96, sort: "size", descending: true, hidden: true, extra: 1, icons: "theme", click: "single", typing: "jump", start: "~/Projects" })
    assert.equal(v.view, "list")
    assert.equal(v.iconSize, 96)
    assert.equal(v.sort, "size")
    assert.equal(v.descending, true)
    assert.equal(v.hidden, true)
    assert.equal(v.extra, 1)
    assert.equal(v.icons, "theme")
    assert.equal(v.click, "single")
    assert.equal(v.typing, "jump")
    assert.equal(v.start, "~/Projects")
    const bad = validateFiles({ view: "tree", iconSize: 9000, sort: "colour", descending: "yes", start: "relative/dir", bookmarks: "x", keys: [] })
    assert.equal(bad.view, "grid")
    assert.equal(bad.iconSize, DEFAULT_FILES.iconSize)
    assert.equal(bad.sort, "name")
    assert.equal(bad.descending, false)
    assert.equal(bad.start, "~")
    assert.deepEqual(bad.bookmarks, [])
    assert.deepEqual(bad.keys, {})
})

test("bookmarks keep absolute paths and ~ paths once, in order", () => {
    assert.deepEqual(validateFiles({ bookmarks: ["/srv/a", "~/b", "rel", 4, "/srv/a", "/srv/../etc"] }).bookmarks, ["/srv/a", "~/b", "/etc"])
})

test("every file action has a unique id, a label and valid default keys", () => {
    const ids = FILE_ACTIONS.map(a => a.id)
    assert.equal(new Set(ids).size, ids.length)
    for (const a of FILE_ACTIONS) {
        assert.ok(a.label.length > 0)
        for (const k of a.keys)
            assert.notEqual(keymap({}).byAction[a.id].indexOf(k), -1, a.id + " default " + k + " is not normalized")
    }
    const combos = FILE_ACTIONS.reduce((out, a) => out.concat(a.keys), [])
    assert.equal(new Set(combos).size, combos.length, "two actions share a default key")
})

test("validateKeys normalizes overrides, drops unknown actions and keeps explicit unbinding", () => {
    assert.deepEqual(validateKeys({ rename: "ctrl+e", trash: ["Delete", "ctrl+BackSpace"], copy: "", paste: [], nope: "F1", undo: "Ctrl+!!", reload: 5 }), {
        rename: ["CTRL+E"],
        trash: ["Delete", "CTRL+BackSpace"],
        copy: [],
        paste: []
    })
    assert.deepEqual(validateKeys("x"), {})
})

test("keymap merges overrides over defaults and an override wins a key a default also uses", () => {
    const m = keymap({ rename: "CTRL+C" })
    assert.deepEqual(m.byAction.rename, ["CTRL+C"])
    assert.equal(m.byCombo["CTRL+C"], "rename")
    assert.equal(keymap({ copy: "F2", rename: "F2" }).byCombo.F2, "rename")
    assert.equal(m.byCombo.F2, undefined)
    assert.equal(keymap({}).byCombo.F2, "rename")
    assert.equal(keymap({}).byCombo.BackSpace, "back")
    assert.equal(keymap({ back: [] }).byCombo.BackSpace, undefined)
})

test("comboOf turns Qt key events into combos, folding shift into symbols", () => {
    assert.equal(comboOf(0x43, CTRL), "CTRL+C")
    assert.equal(comboOf(0x4e, CTRL | SHIFT), "CTRL+SHIFT+N")
    assert.equal(comboOf(0x01000031, 0), "F2")
    assert.equal(comboOf(0x01000004, ALT), "ALT+Return")
    assert.equal(comboOf(0x01000005, 0), "Return")
    assert.equal(comboOf(0x2b, CTRL | SHIFT), "CTRL+plus")
    assert.equal(comboOf(0x3d, CTRL), "CTRL+equal")
    assert.equal(comboOf(0x2d, CTRL), "CTRL+minus")
    assert.equal(comboOf(0x2f, 0), "slash")
    assert.equal(comboOf(0x01000002, CTRL | SHIFT), "CTRL+SHIFT+Tab")
    assert.equal(comboOf(0x01000007, SHIFT), "SHIFT+Delete")
    assert.equal(comboOf(0x01000020, SHIFT), "")
    assert.equal(comboOf(0x41, 0x20000000), "A")
})

test("path helpers join, split and walk up", () => {
    assert.equal(joinPath("/", "a"), "/a")
    assert.equal(joinPath("/a/b", "c d"), "/a/b/c d")
    assert.equal(parentOf("/a/b"), "/a")
    assert.equal(parentOf("/a"), "/")
    assert.equal(parentOf("/"), "/")
    assert.equal(nameOf("/a/b c"), "b c")
    assert.equal(nameOf("/"), "/")
})

test("expand understands ~, relative paths, .. and file URIs, and rejects junk", () => {
    assert.equal(expand("~", "/home/n", "/tmp"), "/home/n")
    assert.equal(expand("~/Doc s/", "/home/n", "/tmp"), "/home/n/Doc s")
    assert.equal(expand("sub/../x", "/home/n", "/srv"), "/srv/x")
    assert.equal(expand("/a/./b/../c", "/home/n", "/"), "/a/c")
    assert.equal(expand("file:///home/n/a%20b", "/home/n", "/"), "/home/n/a b")
    assert.equal(expand("  ", "/home/n", "/"), "")
    assert.equal(expand("file://host/x", "/home/n", "/"), "")
})

test("pretty shortens home to ~ and crumbs start at Home or /", () => {
    assert.equal(pretty("/home/n", "/home/n"), "~")
    assert.equal(pretty("/home/n/a", "/home/n"), "~/a")
    assert.equal(pretty("/home/nx", "/home/n"), "/home/nx")
    assert.deepEqual(crumbs("/home/n/a/b", "/home/n"), [
        { label: "Home", path: "/home/n", home: true },
        { label: "a", path: "/home/n/a", home: false },
        { label: "b", path: "/home/n/a/b", home: false }
    ])
    assert.deepEqual(crumbs("/etc/x", "/home/n").map(c => c.path), ["/", "/etc", "/etc/x"])
    assert.deepEqual(crumbs("/", "/home/n"), [{ label: "/", path: "/", home: false }])
})

test("kinds come from extensions, with labels, glyphs and theme icons for each", () => {
    assert.equal(kindOf("Docs", true), "folder")
    assert.equal(kindOf("a.PNG", false), "image")
    assert.equal(kindOf("b.tar.gz", false), "archive")
    assert.equal(kindOf("c.mkv", false), "video")
    assert.equal(kindOf("d.flac", false), "audio")
    assert.equal(kindOf("e.qml", false), "code")
    assert.equal(kindOf("f.md", false), "text")
    assert.equal(kindOf("g.pdf", false), "pdf")
    assert.equal(kindOf("Makefile", false), "file")
    assert.equal(kindOf(".bashrc", false), "file")
    assert.equal(kindLabel("a.png", false), "PNG image")
    assert.equal(kindLabel("x.pdf", false), "PDF document")
    assert.equal(kindLabel("Docs", true), "Folder")
    assert.equal(kindLabel("README", false), "File")
    for (const k of ["folder", "image", "video", "audio", "pdf", "archive", "code", "text", "document", "sheet", "slides", "font", "file"]) {
        assert.equal(typeof glyphOf(k), "string")
        assert.ok(glyphOf(k).length > 0)
        assert.ok(themeIcon(k).length > 0)
    }
})

const E = (name, dir, size, modified) => ({ name: name, dir: dir, size: size || 0, modified: modified || 0 })

test("arrange sorts naturally with folders first and filters hidden files and the query", () => {
    const list = [E("b10.txt", false, 5, 3), E("b2.txt", false, 50, 1), E("Zeta", true), E(".hid", false), E("alpha", true), E("A1.png", false, 10, 2)]
    const names = opts => arrange(list, Object.assign({ sort: "name", descending: false, foldersFirst: true, hidden: false, query: "" }, opts)).map(e => e.name)
    assert.deepEqual(names({}), ["alpha", "Zeta", "A1.png", "b2.txt", "b10.txt"])
    assert.deepEqual(names({ descending: true }), ["Zeta", "alpha", "b10.txt", "b2.txt", "A1.png"])
    assert.deepEqual(names({ foldersFirst: false }), ["A1.png", "alpha", "b2.txt", "b10.txt", "Zeta"])
    assert.deepEqual(names({ hidden: true }).indexOf(".hid") >= 0, true)
    assert.deepEqual(names({ query: "B" }), ["b2.txt", "b10.txt"])
    assert.deepEqual(names({ sort: "size" }), ["alpha", "Zeta", "b10.txt", "A1.png", "b2.txt"])
    assert.deepEqual(names({ sort: "modified", descending: true }), ["Zeta", "alpha", "b10.txt", "A1.png", "b2.txt"])
    assert.deepEqual(names({ sort: "kind" }), ["alpha", "Zeta", "A1.png", "b2.txt", "b10.txt"])
})

test("sizeText and whenText read like a file manager", () => {
    assert.equal(sizeText(0), "0 bytes")
    assert.equal(sizeText(1), "1 byte")
    assert.equal(sizeText(999), "999 bytes")
    assert.equal(sizeText(1500), "1.5 kB")
    assert.equal(sizeText(999600), "1.0 MB")
    assert.equal(sizeText(123456789), "123 MB")
    assert.equal(sizeText(-1), "")
    const now = new Date(2026, 9, 13, 18, 0).getTime()
    assert.equal(whenText(new Date(2026, 9, 13, 9, 5).getTime(), now), "Today 09:05")
    assert.equal(whenText(new Date(2026, 9, 12, 23, 59).getTime(), now), "Yesterday 23:59")
    assert.equal(whenText(new Date(2026, 2, 4, 10, 0).getTime(), now), "4 Mar")
    assert.equal(whenText(new Date(2024, 11, 31, 10, 0).getTime(), now), "31 Dec 2024")
    assert.equal(whenText(0, now), "")
})

test("summary counts items and the size of selected files", () => {
    const list = [E("a", true), E("b", false, 1500), E("c", false, 500)]
    assert.equal(summary(list, []), "3 items")
    assert.equal(summary([E("a", false)], []), "1 item")
    assert.equal(summary(list, ["b", "c"]), "2 of 3 selected · 2.0 kB")
    assert.equal(summary(list, ["a"]), "1 of 3 selected")
})

test("uniqueName numbers clashes and keeps extensions, double extensions and folder dots", () => {
    assert.equal(uniqueName("a.txt", ["b"], false), "a.txt")
    assert.equal(uniqueName("a.txt", ["a.txt"], false), "a (2).txt")
    assert.equal(uniqueName("a.txt", ["a.txt", "a (2).txt"], false), "a (3).txt")
    assert.equal(uniqueName("a (2).txt", ["a (2).txt"], false), "a (3).txt")
    assert.equal(uniqueName("x.tar.gz", ["x.tar.gz"], false), "x (2).tar.gz")
    assert.equal(uniqueName("my.dir", ["my.dir"], true), "my.dir (2)")
    assert.equal(uniqueName(".bashrc", [".bashrc"], false), ".bashrc (2)")
    assert.equal(uniqueName("New folder", ["New folder"], true), "New folder (2)")
})

test("checkName explains what is wrong with a name", () => {
    assert.equal(checkName("ok.txt", ["a"], ""), "")
    assert.equal(checkName("a", ["a"], "a"), "")
    assert.equal(checkName("  ", [], ""), "Type a name")
    assert.equal(checkName("a/b", [], ""), "Names cannot contain /")
    assert.equal(checkName("..", [], ""), "That name is reserved")
    assert.equal(checkName("ż".repeat(128), [], ""), "That name is too long")
    assert.equal(checkName("a", ["a"], "b"), "Something with that name is already here")
})

test("pick selects one, toggles, and extends ranges from the anchor", () => {
    const order = ["a", "b", "c", "d", "e"]
    assert.deepEqual(pick(["a"], order, "c", "only", "a"), { selected: ["c"], anchor: "c" })
    assert.deepEqual(pick(["a"], order, "c", "toggle", "a"), { selected: ["a", "c"], anchor: "c" })
    assert.deepEqual(pick(["a", "c"], order, "c", "toggle", "a"), { selected: ["a"], anchor: "c" })
    assert.deepEqual(pick(["b"], order, "d", "range", "b"), { selected: ["b", "c", "d"], anchor: "b" })
    assert.deepEqual(pick(["b"], order, "a", "range", "c"), { selected: ["a", "b", "c"], anchor: "c" })
    assert.deepEqual(pick(["e"], order, "c", "extend", "a"), { selected: ["e", "a", "b", "c"], anchor: "a" })
    assert.deepEqual(pick([], order, "b", "range", "gone"), { selected: ["b"], anchor: "b" })
    assert.deepEqual(invert(["a", "c"], order), ["b", "d", "e"])
})

test("nextIndex moves through a grid like a file manager", () => {
    assert.equal(nextIndex(-1, "right", 4, 10, 3), 0)
    assert.equal(nextIndex(0, "left", 4, 10, 3), 0)
    assert.equal(nextIndex(1, "right", 4, 10, 3), 2)
    assert.equal(nextIndex(5, "up", 4, 10, 3), 1)
    assert.equal(nextIndex(1, "up", 4, 10, 3), 1)
    assert.equal(nextIndex(2, "down", 4, 10, 3), 6)
    assert.equal(nextIndex(7, "down", 4, 10, 3), 9)
    assert.equal(nextIndex(9, "down", 4, 10, 3), 9)
    assert.equal(nextIndex(4, "end", 4, 10, 3), 9)
    assert.equal(nextIndex(4, "home", 4, 10, 3), 0)
    assert.equal(nextIndex(0, "pageDown", 2, 10, 2), 4)
    assert.equal(nextIndex(9, "pageUp", 2, 10, 3), 3)
    assert.equal(nextIndex(3, "down", 1, 0, 3), -1)
})

test("bandHits returns every cell a rubber band touches, whichever way it was dragged", () => {
    const grid = { cols: 4, cellW: 100, cellH: 120, count: 10 }
    assert.deepEqual(bandHits({ x: 50, y: 50, w: 100, h: 100 }, grid), [0, 1, 4, 5])
    assert.deepEqual(bandHits({ x: 150, y: 150, w: -100, h: -100 }, grid), [0, 1, 4, 5])
    assert.deepEqual(bandHits({ x: 10, y: 250, w: 380, h: 10 }, grid), [8, 9])
    assert.deepEqual(bandHits({ x: 450, y: 10, w: 10, h: 10 }, grid), [])
    assert.deepEqual(bandHits({ x: 10, y: 10, w: 0, h: 0 }, grid), [])
    assert.deepEqual(bandHits({ x: 10, y: 30, w: 50, h: 60 }, { cols: 1, cellW: 500, cellH: 40, count: 3 }), [0, 1, 2])
})

test("history goes back and forward and visiting drops the forward list", () => {
    let t = { path: "/a", back: [], forward: [] }
    t = visit(t, "/b")
    t = visit(t, "/c")
    assert.deepEqual(t, { path: "/c", back: ["/a", "/b"], forward: [] })
    assert.equal(visit(t, "/c"), t)
    t = goBack(t)
    assert.deepEqual(t, { path: "/b", back: ["/a"], forward: ["/c"] })
    t = goForward(t)
    assert.equal(t.path, "/c")
    t = goBack(goBack(t))
    assert.equal(goBack(t), t)
    assert.deepEqual(visit(t, "/z").forward, [])
})

test("userDirs reads user-dirs.dirs and places lists home and the folders that are not home", () => {
    const dirs = userDirs('# comment\nXDG_DESKTOP_DIR="$HOME/Desktop"\nXDG_DOWNLOAD_DIR="$HOME/Pobrane"\nXDG_MUSIC_DIR="$HOME/"\nXDG_VIDEOS_DIR="/srv/videos"\nXDG_BAD_DIR=x\n', "/home/n")
    assert.deepEqual(dirs, { DESKTOP: "/home/n/Desktop", DOWNLOAD: "/home/n/Pobrane", MUSIC: "/home/n", VIDEOS: "/srv/videos" })
    const p = places("/home/n", dirs)
    assert.deepEqual(p.map(x => x.path), ["/home/n", "/home/n/Desktop", "/home/n/Documents", "/home/n/Pobrane", "/home/n/Pictures", "/srv/videos"])
    assert.deepEqual(p.map(x => x.label), ["Home", "Desktop", "Documents", "Pobrane", "Pictures", "videos"])
    assert.ok(p.every(x => typeof x.glyph === "string" && x.glyph.length > 0))
})

test("gtkBookmarks keeps local folders with their labels", () => {
    assert.deepEqual(gtkBookmarks("file:///home/n/Code Code\nfile:///home/n/a%20b\nsftp://host/x Remote\n\n"), [
        { path: "/home/n/Code", label: "Code" },
        { path: "/home/n/a b", label: "a b" }
    ])
})

test("mounts lists the root and drives under /run/media, /media and /mnt once each", () => {
    const text = [
        "/dev/nvme0n1p2 / ext4 rw 0 0",
        "/dev/nvme0n1p1 /boot vfat rw 0 0",
        "tmpfs /tmp tmpfs rw 0 0",
        "/dev/sda1 /run/media/n/My\\040Disk exfat rw 0 0",
        "/dev/loop0 /mnt/iso iso9660 ro 0 0",
        "/dev/sdb1 /mnt/data btrfs rw 0 0",
        "/dev/sdb1 /mnt/data btrfs rw 0 0",
        "/dev/nvme0n1p2 /nix/store ext4 ro 0 0"
    ].join("\n")
    assert.deepEqual(mounts(text), [
        { path: "/", label: "File system", removable: false },
        { path: "/run/media/n/My Disk", label: "My Disk", removable: true },
        { path: "/mnt/data", label: "data", removable: false }
    ])
})

test("trashInfo reads the original path and deletion date", () => {
    assert.deepEqual(trashInfo("[Trash Info]\nPath=/home/n/a%20b.txt\nDeletionDate=2026-10-13T10:00:00\n"), { path: "/home/n/a b.txt", date: "2026-10-13T10:00:00" })
    assert.deepEqual(trashInfo("junk"), { path: "", date: "" })
})

test("pastePlan picks free names, skips moves onto themselves and refuses folders into themselves", () => {
    const plan = pastePlan([{ path: "/s/a.txt", dir: false }, { path: "/s/D", dir: true }, { path: "/t/x", dir: false }], "/t", ["a.txt", "x"], "copy")
    assert.deepEqual(plan.pairs, [["/s/a.txt", "/t/a (2).txt"], ["/s/D", "/t/D"], ["/t/x", "/t/x (2)"]])
    assert.deepEqual(plan.skipped, [])
    const move = pastePlan([{ path: "/t/x", dir: false }, { path: "/t", dir: true }, { path: "/s/b", dir: false }], "/t/in", [], "move")
    assert.deepEqual(move.pairs, [["/t/x", "/t/in/x"], ["/s/b", "/t/in/b"]])
    assert.deepEqual(move.skipped, [{ path: "/t", why: "A folder cannot go inside itself" }])
    const here = pastePlan([{ path: "/t/x", dir: false }], "/t", ["x"], "move")
    assert.deepEqual(here.pairs, [])
    assert.deepEqual(here.skipped, [{ path: "/t/x", why: "Already here" }])
})

test("inverse undoes moves, renames, copies, new items and trashing", () => {
    assert.deepEqual(inverse({ kind: "move", pairs: [["/a", "/b"], ["/c", "/d"]] }), { kind: "move", pairs: [["/d", "/c"], ["/b", "/a"]] })
    assert.deepEqual(inverse({ kind: "rename", pairs: [["/a", "/b"]] }), { kind: "move", pairs: [["/b", "/a"]] })
    assert.deepEqual(inverse({ kind: "copy", pairs: [["/a", "/b"]] }), { kind: "trash", paths: ["/b"] })
    assert.deepEqual(inverse({ kind: "create", paths: ["/n"] }), { kind: "trash", paths: ["/n"] })
    assert.deepEqual(inverse({ kind: "trash", paths: ["/x"] }), { kind: "restore", paths: ["/x"] })
    assert.equal(inverse({ kind: "restore", paths: ["/x"] }), null)
})

test("openers puts apps for the file's kind first and filters by the query", () => {
    const apps = [
        { id: "gimp", name: "GIMP", categories: ["Graphics"], execString: "gimp %U" },
        { id: "kate", name: "Kate", categories: ["Utility", "TextEditor"], execString: "kate %U" },
        { id: "broken", name: "Broken", categories: ["Graphics"], execString: " " },
        { id: "feh", name: "feh", categories: ["Graphics", "Viewer"], execString: "feh %F" }
    ]
    assert.deepEqual(openers(apps, "image", "").map(a => a.id), ["feh", "gimp", "kate"])
    assert.deepEqual(openers(apps, "code", "").map(a => a.id), ["kate", "feh", "gimp"])
    assert.deepEqual(openers(apps, "image", "ka").map(a => a.id), ["kate"])
})

test("sidebarOf merges Sylvaris and GTK bookmarks without repeats and marks the open folder", () => {
    const s = sidebarOf({
        home: "/home/n",
        dirs: {},
        bookmarks: ["~/Code", "/srv"],
        gtk: [{ path: "/srv", label: "Server" }, { path: "/opt/x", label: "X" }],
        mounts: [{ path: "/", label: "File system", removable: false }],
        trash: "/home/n/.local/share/Trash/files",
        current: "/srv"
    })
    assert.deepEqual(s.map(x => x.section), ["places", "places", "places", "places", "places", "places", "places", "bookmarks", "bookmarks", "bookmarks", "devices", "devices"])
    const marks = s.filter(x => x.section === "bookmarks")
    assert.deepEqual(marks.map(x => [x.path, x.label, x.own]), [["/home/n/Code", "Code", true], ["/srv", "srv", true], ["/opt/x", "X", false]])
    assert.equal(s.filter(x => x.active).length, 1)
    assert.equal(s.find(x => x.active).path, "/srv")
    assert.equal(s[s.length - 1].label, "Trash")
})

test("pathsOfUris reads text/uri-list and plain paths, and urisOf writes them back", () => {
    assert.deepEqual(pathsOfUris("# comment\r\nfile:///a/b%20c\r\n/plain/path\r\nhttps://x.org/y\r\n\r\n"), ["/a/b c", "/plain/path"])
    assert.equal(urisOf(["/a/b c", "/x#1"]), "file:///a/b%20c\r\nfile:///x%231\r\n")
    assert.deepEqual(pathsOfUris(urisOf(["/a/b c", "/x#1"])), ["/a/b c", "/x#1"])
})

test("keyText shows combos the way menus print them", () => {
    assert.equal(keyText("CTRL+SHIFT+N"), "Ctrl+Shift+N")
    assert.equal(keyText("CTRL+plus"), "Ctrl++")
    assert.equal(keyText("SHIFT+Delete"), "Shift+Del")
    assert.equal(keyText("ALT+Return"), "Alt+Enter")
    assert.equal(keyText("slash"), "/")
    assert.equal(keyText("CTRL+Next"), "Ctrl+PgDn")
    assert.equal(keyText(""), "")
})

test("statInfo reads the details helper output for files and folders", () => {
    assert.deepEqual(statInfo("-rw-r--r--|naxce|users\n"), { perm: "-rw-r--r--", owner: "naxce", group: "users", count: -1, bytes: -1 })
    assert.deepEqual(statInfo("drwxr-xr-x|root|root\n12\n40960\n"), { perm: "drwxr-xr-x", owner: "root", group: "root", count: 12, bytes: 40960 })
    assert.deepEqual(statInfo("drwx------|root|root\n3\n"), { perm: "drwx------", owner: "root", group: "root", count: 3, bytes: -1 })
    assert.deepEqual(statInfo(""), { perm: "", owner: "", group: "", count: -1, bytes: -1 })
})
