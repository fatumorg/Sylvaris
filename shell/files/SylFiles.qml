import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import "../lib/files.mjs" as F
import "../lib/viewer.mjs" as V
import "../lib/drives.mjs" as D
import "../lib/archive.mjs" as A

Scope {
    id: root

    property bool wanted: false
    property bool shown: false
    property var screenInfo: null
    readonly property bool windowed: true
    readonly property var cfg: Settings.values.files
    readonly property var keys: F.keymap(root.cfg.keys)
    readonly property string home: Quickshell.env("HOME") || "/"
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || root.home + "/.local/share"
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || root.home + "/.cache"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || root.home + "/.config"
    readonly property string trashPath: root.dataHome + "/Trash/files"
    readonly property string helper: Quickshell.shellDir + "/helpers/files.py"
    readonly property string archiveHelper: Quickshell.shellDir + "/helpers/archive.py"
    readonly property var packing: Settings.values.archive
    readonly property bool archiveOn: Settings.values.parts.archive === true
    property bool picker: false
    property var chooser: null
    property string pickName: ""
    property string pickError: ""
    readonly property string title: (root.chooser !== null ? F.pickTitle(root.chooser.mode, root.chooser.multiple) : root.path === "" ? "Files" : root.path === root.home ? "Home" : F.nameOf(root.path)) + " — SylFiles"

    property var tabs: []
    property int tab: 0
    readonly property var current: root.tabs.length > 0 ? root.tabs[Math.min(root.tab, root.tabs.length - 1)] : ({
            path: "",
            back: [],
            forward: []
        })
    readonly property string path: root.current.path
    readonly property bool inTrash: root.path === root.trashPath
    readonly property var crumbs: root.path === "" ? [] : F.crumbs(root.path, root.home)
    property bool reloading: false
    property var entries: []
    property string query: ""
    property bool filtering: false
    property bool locating: false
    readonly property var items: F.arrange(root.entries, {
        sort: root.cfg.sort,
        descending: root.cfg.descending,
        foldersFirst: root.cfg.foldersFirst,
        hidden: root.cfg.hidden,
        query: root.query
    })
    readonly property var names: root.items.map(e => e.name)
    property var selected: []
    readonly property var selection: {
        const out = {};
        for (const n of root.selected)
            out[n] = true;
        return out;
    }
    property string anchor: ""
    property string cursor: ""
    property var wanting: []
    property string renameNext: ""
    property string renaming: ""
    property string renameError: ""
    property string problem: ""
    property real free: -1
    property var clip: ({
            mode: "",
            items: []
        })
    property var history: []
    property var queue: []
    property var job: null
    property var result: null
    property var clash: null
    property real done: 0
    property real total: 0
    property string note: ""
    property bool noteUndo: false
    property var menu: null
    property string dialog: ""
    property var targets: []
    property var dirs: ({})
    property var gtk: []
    property string lsblkOut: ""
    property string gioOut: ""
    property string mountsOut: ""
    readonly property var drives: D.drives(root.lsblkOut, root.gioOut, root.mountsOut)
    property string driveBusy: ""
    property var driveNext: null
    property var asking: null
    property var info: F.statInfo("")
    property var thumbs: ({})
    property real thumbsAt: 0
    readonly property var sidebar: F.sidebarOf({
        home: root.home,
        dirs: root.dirs,
        bookmarks: root.cfg.bookmarks,
        gtk: root.gtk,
        drives: root.drives,
        trash: root.trashPath,
        current: root.path
    })
    readonly property var focusEntry: root.selected.length === 1 ? root.entryOf(root.selected[0]) : null

    signal opened
    signal revealed(int index)
    signal focusView
    signal focusFilter
    signal focusLocation

    function open(arg: string): void {
        const p = arg.trim() === "" ? "" : F.expand(arg, root.home, root.wanted ? root.path : root.home);
        if (arg.trim() !== "" && p === "")
            throw new Error("usage: files open [folder or file]");
        if (root.wanted) {
            if (p !== "" && p !== root.path)
                root.newTab(p);
            root.raise();
            return;
        }
        root.tabs = [
            {
                path: p !== "" ? p : root.startPath(),
                back: [],
                forward: []
            }
        ];
        root.tab = 0;
        root.entries = [];
        root.wanted = true;
        root.shown = true;
        root.arrived("");
        root.opened();
    }

    function toggleOn(screen: var): void {
        root.screenInfo = screen;
        root.toggle();
    }

    function toggle(): void {
        if (root.wanted)
            root.close();
        else
            root.open("");
    }

    function startPick(mode: string, multiple: string, out: string, path: string): void {
        if (["open", "save", "folder"].indexOf(mode) < 0 || out === "")
            throw new Error("usage: files pick open|save|folder 0|1 <answer file> [suggested path]");
        if (root.chooser !== null)
            root.writePick(root.chooser.out, []);
        const s = F.pickStart(mode, path, root.home);
        root.chooser = {
            mode: mode,
            multiple: multiple === "1" || multiple === "true",
            out: out
        };
        root.pickName = s.name;
        root.pickError = "";
        const target = mode === "save" ? s.folder : s.path;
        if (root.wanted) {
            root.go(target);
            root.raise();
        } else {
            root.open(target);
        }
    }

    function picking(out: string): bool {
        return root.chooser !== null && root.chooser.out === out;
    }

    function writePick(out: string, paths: var): void {
        Quickshell.execDetached(["sh", "-c", "out=$1; shift; { for p in \"$@\"; do printf '%s\\n' \"$p\"; done; printf '\\n'; } > \"$out\"", "sh", out].concat(paths));
    }

    function answerPick(paths: var): void {
        if (root.chooser === null)
            return;
        root.writePick(root.chooser.out, paths);
        root.chooser = null;
        Qt.callLater(root.close);
    }

    function choosePick(): void {
        if (root.chooser === null)
            return;
        const paths = F.pickChoice(root.chooser.mode, root.chooser.multiple, root.itemsOf(root.selected), root.path);
        if (paths.length === 0)
            root.say(root.chooser.multiple ? "Select the files first" : "Select a file first", false);
        else
            root.answerPick(paths);
    }

    function savePick(name: string): void {
        if (root.chooser === null || root.chooser.mode !== "save")
            return;
        const problem = F.checkName(name, [], "");
        if (problem !== "" || root.problem !== "") {
            root.pickError = problem !== "" ? problem : "Pick a folder you can save in";
            return;
        }
        root.pickError = "";
        const e = root.entries.find(x => x.name === name) || null;
        const full = F.joinPath(root.path, name);
        if (e !== null && e.dir) {
            root.go(full);
            return;
        }
        if (e !== null) {
            root.targets = [full];
            root.dialog = "replace";
            return;
        }
        root.answerPick([full]);
    }

    function close(): void {
        if (root.chooser !== null) {
            root.writePick(root.chooser.out, []);
            root.chooser = null;
        }
        if (root.clash !== null)
            root.answerClash("cancel", "", false);
        root.wanted = false;
        root.shown = false;
        root.menu = null;
        root.dialog = "";
        root.asking = null;
        root.renaming = "";
    }

    function raise(): void {
        const t = ToplevelManager.toplevels.values.find(w => w.title === root.title);
        if (t)
            t.activate();
    }

    function startPath(): string {
        return F.expand(root.cfg.start, root.home, root.home) || root.home;
    }

    function setTab(t: var): void {
        if (t.path !== root.path)
            root.entries = [];
        const next = root.tabs.slice();
        next[root.tab] = t;
        root.tabs = next;
    }

    function arrived(old: string): void {
        root.selected = [];
        root.anchor = "";
        root.cursor = "";
        root.renaming = "";
        root.query = "";
        root.filtering = false;
        root.locating = false;
        root.menu = null;
        root.problem = "";
        root.wanting = old !== "" && F.parentOf(old) === root.path ? [F.nameOf(old)] : [];
        probe.check(root.path);
        root.focusView();
        if (Date.now() - root.thumbsAt > 8000)
            thumbScan.scan();
    }

    function go(p: string): void {
        if (p === "" || p === root.path)
            return;
        const old = root.path;
        root.setTab(F.visit(root.current, p));
        root.arrived(old);
    }

    function goTo(text: string): void {
        const p = F.expand(text, root.home, root.path || root.home);
        if (p === "")
            throw new Error("usage: files go <folder>");
        if (!root.wanted)
            root.open(p);
        else
            root.go(p);
    }

    function back(): void {
        const old = root.path;
        root.setTab(F.goBack(root.current));
        if (root.path !== old)
            root.arrived(old);
    }

    function forward(): void {
        const old = root.path;
        root.setTab(F.goForward(root.current));
        if (root.path !== old)
            root.arrived(old);
    }

    function up(): void {
        root.go(F.parentOf(root.path));
    }

    function newTab(p: string): void {
        if (p !== root.path)
            root.entries = [];
        root.tabs = root.tabs.concat([
            {
                path: p,
                back: [],
                forward: []
            }
        ]);
        root.tab = root.tabs.length - 1;
        root.arrived("");
    }

    function openTab(text: string): void {
        const p = text.trim() === "" ? root.path : F.expand(text, root.home, root.path || root.home);
        if (p === "")
            throw new Error("usage: files tab [folder]");
        if (!root.wanted)
            root.open(p);
        else
            root.newTab(p);
    }

    function selectTab(i: int): void {
        if (i < 0 || i >= root.tabs.length || i === root.tab)
            return;
        if (root.tabs[i].path !== root.path)
            root.entries = [];
        root.tab = i;
        root.arrived("");
    }

    function closeTab(i: int): void {
        if (root.tabs.length <= 1) {
            Qt.callLater(root.close);
            return;
        }
        const next = root.tabs.slice();
        next.splice(i, 1);
        const was = root.path;
        const at = Math.min(i <= root.tab && root.tab > 0 ? root.tab - 1 : root.tab, next.length - 1);
        if (next[at].path !== was)
            root.entries = [];
        root.tabs = next;
        root.tab = at;
        if (root.path !== was)
            root.arrived("");
    }

    function reload(): void {
        thumbScan.scan();
        root.reloading = true;
        Qt.callLater(() => root.reloading = false);
        probe.check(root.path);
    }

    function rescan(): void {
        const out = [];
        for (let i = 0; i < model.count; i++)
            out.push({
                name: model.get(i, "fileName"),
                dir: model.get(i, "fileIsDir"),
                size: model.get(i, "fileSize"),
                modified: model.get(i, "fileModified").getTime()
            });
        root.entries = out;
        root.selected = root.selected.filter(n => root.names.indexOf(n) >= 0);
        if (root.wanting.length > 0) {
            const have = root.names.filter(n => root.wanting.indexOf(n) >= 0);
            if (have.length > 0) {
                root.selected = have;
                root.anchor = have[0];
                root.cursor = have[have.length - 1];
                root.revealed(root.names.indexOf(root.cursor));
            }
            if (have.length === root.wanting.length)
                root.wanting = [];
        }
        if (root.renameNext !== "" && root.names.indexOf(root.renameNext) >= 0) {
            root.startRename(root.renameNext);
            root.renameNext = "";
        }
    }

    function entryOf(name: string): var {
        return root.items.find(e => e.name === name) || root.entries.find(e => e.name === name) || null;
    }

    function allNames(): var {
        return root.entries.map(e => e.name);
    }

    function itemsOf(list: var): var {
        return list.map(n => root.entryOf(n)).filter(e => e !== null).map(e => ({
                    path: F.joinPath(root.path, e.name),
                    dir: e.dir
                }));
    }

    function pick(name: string, mode: string): void {
        const r = F.pick(root.selected, root.names, name, mode, root.anchor || name);
        root.selected = r.selected;
        root.anchor = r.anchor;
        root.cursor = name;
    }

    function press(name: string, mods: int): void {
        root.menu = null;
        if (root.renaming !== "" && root.renaming !== name)
            root.cancelRename();
        if (mods & Qt.ShiftModifier)
            root.pick(name, mods & Qt.ControlModifier ? "extend" : "range");
        else if (mods & Qt.ControlModifier)
            root.pick(name, "toggle");
        else if (!root.selection[name])
            root.pick(name, "only");
        else
            root.cursor = name;
        root.focusView();
    }

    function tap(name: string, mods: int): void {
        if (!(mods & (Qt.ShiftModifier | Qt.ControlModifier)) && root.selected.length > 1 && root.selection[name])
            root.pick(name, "only");
    }

    function clearSelection(): void {
        root.selected = [];
        root.anchor = "";
    }

    function selectNames(list: var): void {
        root.selected = root.names.filter(n => list.indexOf(n) >= 0);
        root.anchor = root.selected.length > 0 ? root.selected[0] : "";
        root.cursor = root.selected.length > 0 ? root.selected[root.selected.length - 1] : "";
        if (root.cursor !== "")
            root.revealed(root.names.indexOf(root.cursor));
    }

    function band(hits: var, keep: var): void {
        const out = keep.slice();
        for (const i of hits)
            if (out.indexOf(root.names[i]) < 0)
                out.push(root.names[i]);
        root.selected = out;
    }

    function move(key: string, mods: int, cols: int, rows: int): void {
        const i = F.nextIndex(root.names.indexOf(root.cursor), key, cols, root.names.length, rows);
        if (i < 0)
            return;
        const name = root.names[i];
        if (mods & Qt.ShiftModifier) {
            const r = F.pick(root.selected, root.names, name, "range", root.anchor || root.cursor || name);
            root.selected = r.selected;
            root.anchor = r.anchor;
        } else if (!(mods & Qt.ControlModifier)) {
            root.selected = [name];
            root.anchor = name;
        }
        root.cursor = name;
        root.revealed(i);
    }

    function jump(text: string): void {
        const q = text.toLowerCase();
        const i = root.names.findIndex(n => n.toLowerCase().indexOf(q) === 0);
        if (i >= 0) {
            root.selected = [root.names[i]];
            root.anchor = root.names[i];
            root.cursor = root.names[i];
            root.revealed(i);
        }
    }

    function search(text: string): void {
        root.query = text;
        root.filtering = text !== "";
    }

    function activate(name: string, inTab: bool): void {
        const e = root.entryOf(name);
        if (e === null)
            return;
        const p = F.joinPath(root.path, name);
        if (root.chooser !== null && !e.dir) {
            if (root.chooser.mode === "save")
                root.pickName = name;
            else if (root.chooser.mode === "open")
                root.chooser.multiple && root.selection[name] ? root.choosePick() : root.answerPick([p]);
            return;
        }
        if (e.dir) {
            if (inTab)
                root.newTab(p);
            else
                root.go(p);
        } else if (root.inTrash) {
            root.say("Restore it first to open it", false);
        } else if (root.cfg.openArchives && root.archiveOn && A.isArchive(name)) {
            root.openArchive(p);
        } else {
            Quickshell.execDetached(["gio", "open", p]);
        }
    }

    function openArchive(p: string): void {
        try {
            Ipc.run(["archive", "open", p]);
        } catch (e) {
            root.say(String(e.message || e), false);
        }
    }

    function archivesSelected(): var {
        return root.itemsOf(root.selected).filter(i => !i.dir && A.isArchive(F.nameOf(i.path))).map(i => i.path);
    }

    function askCompress(): void {
        const names = root.selected.slice();
        if (root.inTrash || root.problem !== "")
            return;
        if (names.length === 0) {
            root.say("Select what to pack first", false);
            return;
        }
        const suggested = A.newName(names, root.path, root.packing.format, root.allNames());
        root.asking = {
            kind: "compress",
            names: names,
            title: "Compress " + (names.length === 1 ? "“" + names[0] + "”" : names.length + " items"),
            text: "The archive is made in this folder. Pick a format, or type one after the name.",
            glyph: F.GLYPH.compress,
            password: false,
            value: suggested.slice(0, suggested.length - root.packing.format.length - 1),
            placeholder: "Name",
            choices: A.FORMATS,
            choice: root.packing.format,
            button: "Compress",
            error: "",
            busy: false
        };
    }

    function compressTo(text: string): void {
        if (!root.wanted)
            throw new Error("SylFiles is not open; open it with: sylvaris files open");
        if (root.selected.length === 0)
            throw new Error("select what to pack first, for example: sylvaris files select a.txt b.txt");
        if (text.trim() === "") {
            root.askCompress();
            return;
        }
        const out = A.outName(text, root.packing.format);
        if (out === "")
            throw new Error("usage: files compress [name, like photos.zip]");
        root.compress(root.selected.slice(), out);
    }

    function compress(names: var, out: string): void {
        root.run({
            kind: "compress",
            out: F.joinPath(root.path, out),
            names: names,
            base: root.path,
            level: root.packing.level
        });
    }

    function extractSelected(mode: string): void {
        const list = root.archivesSelected();
        if (list.length === 0) {
            root.say("Select an archive to extract", false);
            return;
        }
        for (const a of list)
            root.run({
                kind: "extract",
                archive: a,
                dest: root.path,
                mode: mode,
                secret: ""
            });
    }

    function openSelected(inTab: bool): void {
        const list = root.selected.length > 0 ? root.selected : root.cursor !== "" ? [root.cursor] : [];
        if (root.chooser !== null) {
            const one = list.length === 1 ? root.entryOf(list[0]) : null;
            if (one !== null && (one.dir || root.chooser.mode === "save"))
                root.activate(list[0], false);
            else if (root.chooser.mode === "save")
                root.savePick(root.pickName);
            else
                root.choosePick();
            return;
        }
        if (list.length === 1) {
            root.activate(list[0], inTab);
            return;
        }
        for (const n of list) {
            const e = root.entryOf(n);
            if (e !== null && e.dir)
                root.newTab(F.joinPath(root.path, n));
            else if (e !== null && !root.inTrash)
                Quickshell.execDetached(["gio", "open", F.joinPath(root.path, n)]);
        }
    }

    function openWith(app: var): void {
        for (const p of root.targets) {
            const args = V.execArgs(app.execString, p);
            if (args.length > 0)
                Quickshell.execDetached(args);
        }
        root.dialog = "";
    }

    function terminal(dir: string): void {
        const words = String(Config.values.terminal || "").trim().split(/\s+/).filter(w => w !== "");
        if (words.length === 0) {
            root.say("Set a terminal in config.json first", false);
            return;
        }
        Quickshell.execDetached({
            command: words,
            workingDirectory: dir
        });
    }

    function say(text: string, undo: bool): void {
        root.note = text;
        root.noteUndo = undo;
        noteTimer.restart();
    }

    function startRename(name: string): void {
        if (root.inTrash || root.entryOf(name) === null)
            return;
        root.selected = [name];
        root.anchor = name;
        root.cursor = name;
        root.renameError = "";
        root.renaming = name;
        root.revealed(root.names.indexOf(name));
    }

    function cancelRename(): void {
        root.renaming = "";
        root.renameError = "";
        root.focusView();
    }

    function commitRename(name: string, text: string): bool {
        if (text === name) {
            root.cancelRename();
            return true;
        }
        const err = F.checkName(text, root.allNames(), name);
        if (err !== "") {
            root.renameError = err;
            return false;
        }
        root.renaming = "";
        root.renameError = "";
        root.run({
            kind: "rename",
            pairs: [[F.joinPath(root.path, name), F.joinPath(root.path, text)]]
        });
        root.focusView();
        return true;
    }

    function renameTo(text: string): void {
        if (root.selected.length !== 1)
            throw new Error("select exactly one item to rename");
        if (!root.commitRename(root.selected[0], text))
            throw new Error(root.renameError);
    }

    function create(folder: bool): void {
        if (root.inTrash || root.problem !== "")
            return;
        const name = F.uniqueName(folder ? "New folder" : "New file", root.allNames(), folder);
        root.run({
            kind: folder ? "mkdir" : "touch",
            paths: [F.joinPath(root.path, name)],
            renameAfter: true
        });
    }

    function copyItems(mode: string): void {
        const items = root.itemsOf(root.selected);
        if (items.length === 0)
            return;
        root.clip = {
            mode: mode,
            items: items
        };
        Quickshell.execDetached(["wl-copy", "-t", "text/uri-list", F.urisOf(items.map(i => i.path))]);
        root.say((items.length === 1 ? "“" + F.nameOf(items[0].path) + "”" : items.length + " items") + (mode === "cut" ? " will move when you paste" : " copied"), false);
    }

    function copyPath(): void {
        const list = root.selected.length > 0 ? root.selected.map(n => F.joinPath(root.path, n)) : [root.path];
        Quickshell.execDetached(["wl-copy", "--", list.join("\n")]);
        root.say(list.length === 1 ? "Path copied" : "Paths copied", false);
    }

    function paste(dest: string): void {
        if (root.inTrash && dest === root.path)
            return;
        pasteReader.dest = dest;
        pasteReader.answered = false;
        pasteReader.running = true;
    }

    function pasted(dest: string, paths: var, fromSystem: bool): void {
        const mine = root.clip.items.map(i => i.path);
        const list = fromSystem ? paths : mine;
        if (list.length === 0) {
            root.say("Nothing to paste", false);
            return;
        }
        const cut = root.clip.mode === "cut" && JSON.stringify(list) === JSON.stringify(mine);
        const items = list.map(p => ({
                    path: p,
                    dir: (root.clip.items.find(i => i.path === p) || {
                            dir: false
                        }).dir
                }));
        root.transfer(items, dest, cut ? "move" : "copy");
        if (cut)
            root.clip = {
                mode: "",
                items: []
            };
    }

    function transfer(items: var, dest: string, mode: string): void {
        const plan = F.pastePlan(items, dest, mode);
        if (plan.skipped.length > 0 && plan.pairs.length === 0) {
            root.say(plan.skipped[0].why, false);
            return;
        }
        root.run({
            kind: mode,
            pairs: plan.pairs
        });
    }

    function dropped(dest: string, urls: var, action: int): void {
        const paths = F.pathsOfUris(urls.map(u => String(u)).join("\n"));
        if (paths.length === 0)
            return;
        if (dest === root.trashPath) {
            const out = paths.filter(p => F.parentOf(p) !== root.trashPath);
            if (out.length > 0)
                root.run({
                    kind: "trash",
                    paths: out
                });
            return;
        }
        const known = root.itemsOf(root.allNames());
        root.transfer(paths.map(p => ({
                    path: p,
                    dir: (known.find(i => i.path === p) || {
                            dir: false
                        }).dir
                })), dest, action === Qt.CopyAction ? "copy" : "move");
    }

    function dragUris(name: string): string {
        const list = root.selection[name] ? root.selected : [name];
        return F.urisOf(list.map(n => F.joinPath(root.path, n)));
    }

    function trashSelected(): void {
        const paths = root.itemsOf(root.selected).map(i => i.path);
        if (paths.length === 0)
            return;
        root.targets = paths;
        if (root.inTrash)
            root.dialog = "delete";
        else if (root.cfg.confirmTrash)
            root.dialog = "trash";
        else
            root.run({
                kind: "trash",
                paths: paths
            });
    }

    function deleteSelected(): void {
        const paths = root.itemsOf(root.selected).map(i => i.path);
        if (paths.length === 0)
            return;
        root.targets = paths;
        root.dialog = "delete";
    }

    function confirm(): void {
        const d = root.dialog;
        root.dialog = "";
        if (d === "delete")
            root.run({
                kind: "delete",
                paths: root.targets
            });
        else if (d === "trash")
            root.run({
                kind: "trash",
                paths: root.targets
            });
        else if (d === "empty")
            root.run({
                kind: "empty",
                paths: []
            });
        else if (d === "replace") {
            root.answerPick(root.targets.slice(0, 1));
            return;
        }
        root.focusView();
    }

    function restoreSelected(): void {
        if (!root.inTrash || root.selected.length === 0)
            return;
        root.run({
            kind: "restore",
            paths: root.selected.slice()
        });
    }

    function undo(): void {
        if (root.history.length === 0) {
            root.say("Nothing to undo", false);
            return;
        }
        const last = root.history[root.history.length - 1];
        root.history = root.history.slice(0, -1);
        const inv = F.inverse(last);
        if (inv === null)
            return;
        const step = x => ({
                kind: x.kind === "move" ? "rename" : x.kind === "restore" ? "untrash" : x.kind,
                pairs: x.pairs || [],
                paths: x.paths || [],
                names: x.names || [],
                undoing: true
            });
        root.run(step(inv));
        if (inv.then)
            root.run(step(inv.then));
    }

    function answerClash(what: string, name: string, all: bool): void {
        if (root.clash === null)
            return;
        root.clash = null;
        if (runner.running)
            runner.write(JSON.stringify({
                do: what,
                name: name,
                all: all
            }) + "\n");
    }

    function clashCommand(words: var): void {
        if (root.clash === null)
            throw new Error("nothing is waiting for an answer");
        const a = F.clashAnswer(words, root.clash.actions);
        root.answerClash(a.do, a.name, a.all);
    }

    function remember(entry: var): void {
        if (F.inverse(entry) !== null)
            root.history = root.history.concat([entry]).slice(-30);
    }

    function toggleBookmark(p: string): void {
        const short = F.pretty(p, root.home);
        const marks = root.cfg.bookmarks.slice();
        const i = marks.findIndex(b => b === short || b === p);
        if (i >= 0)
            marks.splice(i, 1);
        else
            marks.push(short);
        Settings.put("files.bookmarks", marks);
        root.say(i >= 0 ? "Bookmark removed" : "Bookmarked " + F.nameOf(p), false);
    }

    function moveBookmark(from: int, to: int): void {
        Settings.put("files.bookmarks", F.moved(root.cfg.bookmarks, from, to));
    }

    function driveOf(key: string): var {
        const k = key.trim();
        return root.drives.find(d => d.id === k) || root.drives.find(d => d.label === k) || root.drives.find(d => d.label.toLowerCase() === k.toLowerCase()) || null;
    }

    function scanDrives(): void {
        if (!driveScan.running)
            driveScan.running = true;
        if (!gioScan.running)
            gioScan.running = true;
        mountsFile.reload();
    }

    function openDrive(d: var, inTab: bool): void {
        if (d.locked)
            root.asking = {
                kind: "unlock",
                id: d.id,
                tab: inTab,
                title: "Unlock “" + d.label + "”",
                text: "It is encrypted. Type its passphrase to open it.",
                glyph: F.GLYPH.lock,
                password: true,
                value: "",
                placeholder: "Passphrase",
                button: "Unlock",
                error: "",
                busy: false
            };
        else if (d.mounted && d.path !== "")
            inTab ? root.newTab(d.path) : root.go(d.path);
        else
            root.runDrive(d, d.mounted ? "find" : "mount", inTab ? "tab" : "open", "");
    }

    function driveVerb(verb: string, key: string): void {
        const d = root.driveOf(key);
        if (!root.wanted)
            throw new Error("SylFiles is not open; open it with: sylvaris files open");
        if (d === null)
            throw new Error("no drive called " + key + "; one of " + root.drives.map(x => x.label).join(", "));
        if (verb === "eject")
            root.ejectDrive(d);
        else
            root.openDrive(d, false);
    }

    function contextDrive(id: string, x: real, y: real): void {
        root.menu = {
            x: x,
            y: y,
            name: "",
            drive: id
        };
    }

    function leave(p: string): void {
        const inside = q => q === p || q.startsWith(p + "/");
        root.tabs = root.tabs.map((t, i) => i !== root.tab && inside(t.path) ? F.visit(t, root.home) : t);
        if (inside(root.path))
            root.go(root.home);
    }

    function ejectDrive(d: var): void {
        if (d.path !== "")
            root.leave(d.path);
        root.runDrive(d, "eject", "", "");
    }

    function runDrive(d: var, verb: string, then: string, secret: string): void {
        if (driveOp.running) {
            root.say("Wait a moment, a drive is still busy", false);
            return;
        }
        const cmd = D.driveCommand(d, verb, root.drives);
        if (cmd.length === 0) {
            root.say("Sylvaris cannot do that with “" + d.label + "”", false);
            return;
        }
        root.driveBusy = d.id;
        driveOp.drive = d;
        driveOp.verb = verb;
        driveOp.then = then;
        driveOp.secret = secret;
        driveOp.began = false;
        driveOp.stdinEnabled = verb === "unlock";
        driveOp.command = cmd;
        driveOp.running = true;
    }

    function driveFailed(text: string): void {
        if (driveOp.verb === "unlock" && root.asking !== null)
            root.asking = Object.assign({}, root.asking, {
                busy: false,
                error: text
            });
        else
            root.say(text, false);
    }

    function driveDone(code: int, out: string, err: string): void {
        const d = driveOp.drive;
        const verb = driveOp.verb;
        const then = driveOp.then;
        driveOp.secret = "";
        root.driveBusy = "";
        if (code !== 0 && !/AlreadyMounted/.test(err)) {
            root.driveFailed(D.driveError(err));
            root.scanDrives();
            return;
        }
        if (verb === "unlock") {
            root.asking = null;
            root.driveNext = {
                crypt: d.id,
                then: then,
                tries: 8
            };
        } else if (verb === "mount" && d.via === "gio") {
            Qt.callLater(() => root.runDrive(d, "find", then, ""));
        } else if (verb === "mount") {
            root.driveNext = {
                id: d.id,
                then: then,
                tries: 8
            };
        } else if (verb === "find") {
            const p = D.localPath(out);
            if (p === "")
                root.say("“" + d.label + "” has no folder to open; gvfs needs its FUSE part for that", false);
            else if (then === "tab")
                root.newTab(p);
            else
                root.go(p);
        } else if (verb === "eject") {
            root.say(d.kind === "usb" || d.kind === "card" ? "“" + d.label + "” can be unplugged now" : "“" + d.label + "” is unmounted", false);
        }
        root.scanDrives();
    }

    function followDrive(): void {
        const n = root.driveNext;
        if (n === null)
            return;
        const d = n.crypt !== undefined ? root.drives.find(r => r.crypt === n.crypt) : root.drives.find(r => r.id === n.id);
        if (d !== undefined && (n.crypt !== undefined || (d.mounted && d.path !== ""))) {
            root.driveNext = null;
            root.openDrive(d, n.then === "tab");
            return;
        }
        root.driveNext = n.tries > 1 ? Object.assign({}, n, {
            tries: n.tries - 1
        }) : null;
        if (root.driveNext !== null)
            driveRetry.restart();
    }

    function answer(value: string, choice: string): void {
        const a = root.asking;
        if (a === null || a.busy)
            return;
        if (a.kind === "compress") {
            const out = A.outName(value, choice);
            if (out === "") {
                root.asking = Object.assign({}, a, {
                    error: "Type a name without a slash"
                });
                return;
            }
            if (choice !== root.packing.format)
                Settings.put("archive.format", choice);
            root.asking = null;
            root.compress(a.names, out);
            return;
        }
        if (a.kind === "archivePassword") {
            if (value === "")
                return;
            root.asking = null;
            root.run(Object.assign({}, a.op, {
                secret: value
            }));
            return;
        }
        if (a.kind === "unlock") {
            const d = root.driveOf(a.id);
            if (d === null || value === "")
                return;
            root.asking = Object.assign({}, a, {
                busy: true,
                error: ""
            });
            root.runDrive(d, "unlock", a.tab ? "tab" : "open", value);
        }
    }

    function cancelAsk(): void {
        root.asking = null;
        root.focusView();
    }

    function zoom(d: int): void {
        const steps = [40, 48, 56, 64, 80, 96, 128, 160];
        const at = root.cfg.iconSize;
        const next = d === 0 ? F.DEFAULT_FILES.iconSize : d > 0 ? (steps.find(s => s > at) || at) : (steps.slice().reverse().find(s => s < at) || at);
        if (next !== at)
            Settings.put("files.iconSize", next);
    }

    function sortBy(key: string): void {
        if (root.cfg.sort === key)
            Settings.put("files.descending", !root.cfg.descending);
        else
            Settings.put("files.sort", key);
    }

    function contextAt(name: string, x: real, y: real): void {
        if (name !== "" && !root.selection[name])
            root.pick(name, "only");
        if (name === "")
            root.clearSelection();
        root.menu = {
            x: x,
            y: y,
            name: name
        };
    }

    function chooseApp(): void {
        const files = root.itemsOf(root.selected).filter(i => !i.dir).map(i => i.path);
        if (files.length === 0 || root.inTrash)
            return;
        root.targets = files;
        root.dialog = "openWith";
    }

    function act(id: string): void {
        const a = {
            open: () => root.openSelected(false),
            openTab: () => root.openSelected(true),
            openWith: () => root.chooseApp(),
            back: () => root.back(),
            forward: () => root.forward(),
            up: () => root.up(),
            home: () => root.go(root.home),
            reload: () => root.reload(),
            location: () => {
                root.locating = true;
                root.focusLocation();
            },
            search: () => {
                root.filtering = true;
                root.focusFilter();
            },
            newFolder: () => root.create(true),
            newFile: () => root.create(false),
            rename: () => {
                if (root.selected.length === 1)
                    root.startRename(root.selected[0]);
            },
            copy: () => root.copyItems("copy"),
            cut: () => root.copyItems("cut"),
            paste: () => root.paste(root.path),
            copyPath: () => root.copyPath(),
            trash: () => root.trashSelected(),
            delete: () => root.deleteSelected(),
            undo: () => root.undo(),
            selectAll: () => root.selectNames(root.names),
            invert: () => root.selectNames(F.invert(root.selected, root.names)),
            hidden: () => Settings.put("files.hidden", !root.cfg.hidden),
            grid: () => Settings.put("files.view", "grid"),
            list: () => Settings.put("files.view", "list"),
            zoomIn: () => root.zoom(1),
            zoomOut: () => root.zoom(-1),
            zoomReset: () => root.zoom(0),
            sidebar: () => Settings.put("files.sidebar", !root.cfg.sidebar),
            details: () => Settings.put("files.details", !root.cfg.details),
            bookmark: () => root.toggleBookmark(root.path),
            terminal: () => root.terminal(root.focusEntry !== null && root.focusEntry.dir ? F.joinPath(root.path, root.focusEntry.name) : root.path),
            compress: () => root.askCompress(),
            extract: () => root.extractSelected(root.packing.extract),
            newTab: () => root.newTab(root.path),
            closeTab: () => root.closeTab(root.tab),
            nextTab: () => root.selectTab((root.tab + 1) % root.tabs.length),
            prevTab: () => root.selectTab((root.tab - 1 + root.tabs.length) % root.tabs.length),
            quit: () => Qt.callLater(root.close)
        }[id];
        if (a === undefined)
            throw new Error("unknown action: " + id + "; one of " + F.FILE_ACTIONS.map(x => x.id).join(", "));
        if (!root.wanted)
            throw new Error("SylFiles is not open; open it with: sylvaris files open");
        root.menu = null;
        a();
    }

    function key(combo: string): bool {
        const id = root.keys.byCombo[combo];
        if (id === undefined)
            return false;
        root.act(id);
        return true;
    }

    function run(op: var): void {
        root.queue = root.queue.concat([op]);
        if (root.job === null)
            root.next();
    }

    function next(): void {
        if (root.queue.length === 0) {
            root.job = null;
            return;
        }
        const op = root.queue[0];
        root.queue = root.queue.slice(1);
        root.job = op;
        root.result = null;
        root.clash = null;
        root.done = 0;
        root.total = 0;
        const flat = (op.pairs || []).reduce((out, p) => out.concat(p), []);
        const asks = ["copy", "move", "restore", "untrash", "bin", "compress", "extract"].indexOf(op.kind) >= 0;
        runner.command = {
            copy: ["python3", root.helper, "--clashes", "copy"].concat(flat),
            move: ["python3", root.helper, "--clashes", "move"].concat(flat),
            rename: ["python3", root.helper, "rename"].concat(flat),
            trash: ["gio", "trash", "--"].concat(op.paths || []),
            delete: ["rm", "-rf", "--"].concat(op.paths || []),
            mkdir: ["mkdir", "--"].concat(op.paths || []),
            touch: ["sh", "-c", "set -C; : > \"$1\"", "sh"].concat(op.paths || []),
            restore: ["python3", root.helper, "--clashes", "restore"].concat(op.paths || []),
            untrash: ["python3", root.helper, "--clashes", "untrash"].concat(op.paths || []),
            bin: ["python3", root.helper, "--clashes", "restore"].concat(op.names || []),
            empty: ["gio", "trash", "--empty"],
            compress: ["python3", root.archiveHelper, "--clashes", "compress", op.out, op.level, op.base].concat(op.names || []),
            extract: ["python3", root.archiveHelper].concat(op.secret ? ["--ask"] : []).concat(["--clashes", "extract", op.archive, op.dest, op.mode, "0"])
        }[op.kind];
        runner.stdinEnabled = asks || (op.secret ? true : false);
        runner.running = true;
    }

    function cancelJob(): void {
        if (root.job !== null && runner.running)
            runner.signal(15);
    }

    function packed(code: int): void {
        const op = root.job;
        const r = root.result || {
            ok: [],
            failed: code === 0 ? [] : [{
                    path: op.archive || op.out,
                    error: "The archive helper stopped"
                }],
            cancelled: false,
            password: ""
        };
        if (r.password !== "") {
            root.asking = {
                kind: "archivePassword",
                op: Object.assign({}, op, {
                    secret: ""
                }),
                title: "“" + F.nameOf(op.archive) + "” has a password",
                text: "Type it to unpack the files.",
                glyph: F.GLYPH.lock,
                password: true,
                value: "",
                placeholder: "Password",
                button: "Extract",
                error: r.password === "wrong" ? "Wrong password" : "",
                busy: false
            };
            root.next();
            return;
        }
        const made = r.ok.map(p => p[1]);
        const created = op.kind === "extract" ? (r.moved || []).map(p => p[1]) : (r.made || made);
        const before = root.history.length;
        root.remember({
            kind: "create",
            paths: created,
            binned: r.binned || []
        });
        root.say(op.kind === "compress" ? A.compressNote(r) : A.extractNote(r), root.history.length > before);
        const here = made.filter(p => F.parentOf(p) === root.path).map(p => F.nameOf(p));
        if (here.length > 0)
            root.wanting = here;
        root.rescanSoon();
        root.next();
    }

    function finish(code: int): void {
        if (root.job.kind === "compress" || root.job.kind === "extract") {
            root.packed(code);
            return;
        }
        const op = root.job;
        const r = root.result;
        const pairs = r !== null ? r.ok : code === 0 ? (op.paths || []).map(p => [p, p]) : [];
        const made = pairs.map(p => p[1]);
        const failed = r !== null ? r.failed : [];
        const skipped = r !== null && r.skipped ? r.skipped : [];
        let text = "";
        if ((op.kind === "copy" || op.kind === "move") && made.length === 0 && skipped.length > 0 && failed.length === 0)
            text = "Skipped " + (skipped.length === 1 ? "“" + F.nameOf(skipped[0]) + "”" : skipped.length + " items");
        else if (op.kind === "copy" || op.kind === "move" || op.kind === "rename")
            text = (op.kind === "copy" ? "Copied " : op.kind === "move" ? "Moved " : op.undoing ? "Put back " : "Renamed ") + (made.length === 1 ? "“" + F.nameOf(made[0]) + "”" : made.length + " items") + (skipped.length > 0 ? " · skipped " + skipped.length : "") + (r !== null && r.trashed && r.trashed.length > 0 ? " · replaced " + r.trashed.length : "");
        else if (op.kind === "trash")
            text = code === 0 ? (op.paths.length === 1 ? "“" + F.nameOf(op.paths[0]) + "” moved to the trash" : op.paths.length + " items moved to the trash") : "Some items could not be moved to the trash";
        else if (op.kind === "delete")
            text = code === 0 ? "Deleted for good" : "Some items could not be deleted";
        else if (op.kind === "restore" || op.kind === "untrash" || op.kind === "bin")
            text = made.length > 0 ? "Restored " + (made.length === 1 ? "“" + F.nameOf(made[0]) + "”" : made.length + " items") : "Nothing was restored";
        else if (op.kind === "empty")
            text = code === 0 ? "Trash emptied" : "The trash could not be emptied";
        else if (code !== 0)
            text = "Could not create it here";
        if (r !== null && r.cancelled)
            text = "Stopped" + (made.length > 0 ? " after " + made.length + (made.length === 1 ? " item" : " items") : "");
        else if (failed.length > 0)
            text = (made.length > 0 ? text + " · " : "") + (failed.length === 1 ? F.nameOf(failed[0].path) + ": " + failed[0].error : failed.length + " items failed");
        const before = root.history.length;
        if (!op.undoing && made.length > 0 && ["copy", "move", "rename", "trash", "mkdir", "touch"].indexOf(op.kind) >= 0 && !(op.kind === "trash" && code !== 0))
            root.remember(op.kind === "mkdir" || op.kind === "touch" ? {
                kind: "create",
                paths: made
            } : op.kind === "trash" ? {
                kind: "trash",
                paths: op.paths
            } : {
                kind: op.kind,
                pairs: pairs,
                made: r !== null ? r.made : undefined,
                moved: r !== null ? r.moved : undefined,
                binned: r !== null ? r.binned : []
            });
        const undoable = root.history.length > before;
        const here = made.filter(p => F.parentOf(p) === root.path).map(p => F.nameOf(p));
        if (here.length > 0 && op.kind !== "trash" && op.kind !== "delete") {
            root.wanting = here;
            if (op.renameAfter && code === 0)
                root.renameNext = here[0];
        }
        if (text !== "" && !op.renameAfter)
            root.say(text, undoable);
        if (["copy", "move", "rename", "mkdir", "touch", "restore", "untrash", "bin"].indexOf(op.kind) >= 0)
            root.rescanSoon();
        root.next();
    }

    function rescanSoon(): void {
        rescanTimer.restart();
    }

    function state(): var {
        return {
            open: root.wanted,
            path: root.path,
            tab: root.tab,
            tabs: root.tabs.map(t => t.path),
            view: root.cfg.view,
            sort: root.cfg.sort,
            hidden: root.cfg.hidden,
            query: root.query,
            problem: root.problem,
            count: root.items.length,
            items: root.names.slice(0, 200),
            selected: root.selected,
            renaming: root.renaming,
            busy: root.job !== null,
            progress: root.total > 0 ? Math.round(root.done / root.total * 100) / 100 : 0,
            note: root.note,
            menu: root.menu !== null,
            dialog: root.dialog,
            asking: root.asking === null ? "" : root.asking.kind,
            askError: root.asking === null ? "" : root.asking.error,
            drives: root.drives.map(d => ({
                        id: d.id,
                        label: d.label,
                        kind: d.kind,
                        mounted: d.mounted,
                        path: d.path,
                        locked: d.locked
                    })),
            driveBusy: root.driveBusy,
            clip: {
                mode: root.clip.mode,
                count: root.clip.items.length
            },
            undo: root.history.length,
            clash: root.clash === null ? null : {
                op: root.clash.op,
                name: root.clash.name,
                actions: root.clash.actions,
                error: root.clash.error || ""
            },
            pick: root.chooser === null ? null : {
                mode: root.chooser.mode,
                multiple: root.chooser.multiple,
                name: root.pickName,
                error: root.pickError
            }
        };
    }

    onPathChanged: root.renameNext = ""

    FolderListModel {
        id: model
        folder: root.shown && root.path !== "" && !root.reloading ? V.uriOf(root.path) : ""
        showDirs: true
        showFiles: true
        showHidden: true
        showDotAndDotDot: false
        showOnlyReadable: false
        sortField: FolderListModel.Unsorted
        onStatusChanged: root.rescanSoon()
        onCountChanged: root.rescanSoon()
        onDataChanged: root.rescanSoon()
    }

    Timer {
        id: rescanTimer
        interval: 30
        onTriggered: root.rescan()
    }

    Process {
        id: probe
        property string target: ""
        property var out: []

        function check(p: string): void {
            probe.running = false;
            probe.target = p;
            probe.out = [];
            probe.command = ["sh", "-c", "if [ -d \"$1\" ]; then if [ -r \"$1\" ] && [ -x \"$1\" ]; then echo dir; else echo denied; fi; df -B1 --output=avail -- \"$1\" 2>/dev/null | tail -n 1; elif [ -e \"$1\" ]; then echo file; else echo missing; fi", "sh", p];
            probe.running = true;
        }

        stdout: SplitParser {
            onRead: line => probe.out = probe.out.concat([line.trim()])
        }
        onExited: {
            if (probe.target !== root.path)
                return;
            const kind = probe.out[0] || "missing";
            root.free = /^\d+$/.test(probe.out[1] || "") ? Number(probe.out[1]) : -1;
            if (kind === "file") {
                const name = F.nameOf(root.path);
                root.setTab(Object.assign({}, root.current, {
                    path: F.parentOf(root.path)
                }));
                root.arrived("");
                root.wanting = [name];
                return;
            }
            root.problem = kind === "dir" ? "" : kind;
        }
    }

    Process {
        id: thumbScan
        property var found: ({})

        function scan(): void {
            if (thumbScan.running || !root.cfg.thumbnails)
                return;
            root.thumbsAt = Date.now();
            thumbScan.found = {};
            thumbScan.command = ["sh", "-c", "cd \"$1\" 2>/dev/null && find x-large large normal -maxdepth 1 -name '*.png' 2>/dev/null", "sh", root.cacheHome + "/thumbnails"];
            thumbScan.running = true;
        }

        stdout: SplitParser {
            onRead: line => thumbScan.found[line.trim()] = true
        }
        onExited: root.thumbs = thumbScan.found
    }

    Process {
        id: runner
        stdout: SplitParser {
            onRead: line => {
                if (line.charAt(0) !== "{")
                    return;
                let msg = null;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (msg.ok !== undefined) {
                    root.result = msg;
                } else if (msg.clash !== undefined) {
                    root.clash = msg.clash;
                    if (!root.wanted)
                        root.open(msg.clash.folder);
                    else
                        root.raise();
                } else if (msg.total !== undefined) {
                    root.total = msg.total;
                    root.done = msg.done;
                }
            }
        }
        onStarted: {
            if (root.job !== null && root.job.secret) {
                runner.write(root.job.secret + "\n");
                root.job = Object.assign({}, root.job, {
                    secret: ""
                });
            }
        }
        onExited: code => {
            root.clash = null;
            root.finish(code);
        }
    }

    Process {
        id: pasteReader
        property string dest: ""
        property bool answered: false
        command: ["wl-paste", "-n", "-t", "text/uri-list"]
        stdout: StdioCollector {
            id: pasteText
        }
        onStarted: pasteReader.answered = false
        onExited: code => {
            pasteReader.answered = true;
            const paths = code === 0 ? F.pathsOfUris(pasteText.text) : [];
            root.pasted(pasteReader.dest, paths, paths.length > 0);
        }
        onRunningChanged: {
            if (!pasteReader.running)
                Qt.callLater(() => {
                    if (!pasteReader.answered) {
                        pasteReader.answered = true;
                        root.pasted(pasteReader.dest, [], false);
                    }
                });
        }
    }

    Process {
        id: details
        property string target: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (details.target === (root.focusEntry !== null ? F.joinPath(root.path, root.focusEntry.name) : root.path))
                    root.info = F.statInfo(text);
            }
        }
    }

    Timer {
        id: detailsTimer
        interval: 120
        onTriggered: {
            const p = root.focusEntry !== null ? F.joinPath(root.path, root.focusEntry.name) : root.path;
            root.info = F.statInfo("");
            if (p === "" || !root.cfg.details || !root.shown)
                return;
            details.running = false;
            details.target = p;
            details.command = ["sh", "-c", "stat -c '%A|%U|%G' -- \"$1\" && if [ -d \"$1\" ]; then ls -A -- \"$1\" 2>/dev/null | wc -l; du -sb -- \"$1\" 2>/dev/null | cut -f1; fi", "sh", p];
            details.running = true;
        }
    }

    Connections {
        target: root
        function onFocusEntryChanged() {
            detailsTimer.restart();
        }
        function onPathChanged() {
            detailsTimer.restart();
        }
        function onCfgChanged() {
            if (root.cfg.details && root.info.perm === "")
                detailsTimer.restart();
        }
    }

    FileView {
        path: root.shown ? root.configHome + "/user-dirs.dirs" : ""
        printErrors: false
        watchChanges: true
        onLoaded: root.dirs = F.userDirs(text(), root.home)
        onLoadFailed: root.dirs = ({})
        onFileChanged: reload()
    }

    FileView {
        path: root.shown ? root.configHome + "/gtk-3.0/bookmarks" : ""
        printErrors: false
        watchChanges: true
        onLoaded: root.gtk = F.gtkBookmarks(text())
        onLoadFailed: root.gtk = []
        onFileChanged: reload()
    }

    FileView {
        id: mountsFile
        path: root.shown ? "/proc/self/mounts" : ""
        printErrors: false
        onLoaded: root.mountsOut = text()
    }

    Timer {
        interval: 3000
        running: root.shown
        repeat: true
        triggeredOnStart: true
        onTriggered: root.scanDrives()
    }

    Timer {
        id: driveRetry
        interval: 400
        onTriggered: root.scanDrives()
    }

    Process {
        id: driveScan
        command: D.LSBLK
        stdout: StdioCollector {
            onStreamFinished: {
                root.lsblkOut = text;
                root.followDrive();
            }
        }
    }

    Process {
        id: gioScan
        command: D.GIO_LIST
        stdout: StdioCollector {
            onStreamFinished: {
                root.gioOut = text;
                root.followDrive();
            }
        }
    }

    Process {
        id: driveOp
        property var drive: null
        property string verb: ""
        property string then: ""
        property string secret: ""
        property bool began: false
        stdout: StdioCollector {
            id: driveOut
        }
        stderr: StdioCollector {
            id: driveErr
        }
        onStarted: {
            driveOp.began = true;
            if (driveOp.secret !== "") {
                driveOp.write(driveOp.secret);
                driveOp.secret = "";
            }
            if (driveOp.stdinEnabled)
                driveOp.stdinEnabled = false;
        }
        onExited: code => root.driveDone(code, driveOut.text, driveErr.text)
        onRunningChanged: {
            if (!driveOp.running && !driveOp.began)
                Qt.callLater(() => {
                    if (driveOp.began || driveOp.running || root.driveBusy === "")
                        return;
                    driveOp.secret = "";
                    root.driveBusy = "";
                    root.driveFailed(driveOp.drive.via === "gio" ? "Phones and shares need gvfs, for example services.gvfs.enable = true on NixOS" : driveOp.drive.via === "udisks" ? D.driveError("udisks daemon") : "Could not run " + driveOp.command[0]);
                });
        }
    }

    Timer {
        id: noteTimer
        interval: 4200
        onTriggered: {
            root.note = "";
            root.noteUndo = false;
        }
    }

    LazyLoader {
        active: root.shown

        FilesWindow {
            files: root
        }
    }
}
