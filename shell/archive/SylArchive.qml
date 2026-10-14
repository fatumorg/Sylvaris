import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import "../lib/files.mjs" as F
import "../lib/archive.mjs" as A
import "../lib/icons.mjs" as Icons

Scope {
    id: root

    property bool wanted: false
    property bool shown: false
    property var screenInfo: null
    readonly property bool windowed: true
    readonly property bool inArchive: true
    readonly property var own: Settings.values.archive
    readonly property var shared: Settings.values.files
    readonly property var cfg: ({
            view: root.own.view,
            iconSize: root.shared.iconSize,
            sort: root.shared.sort,
            descending: root.shared.descending,
            foldersFirst: root.shared.foldersFirst,
            hidden: true,
            thumbnails: false,
            icons: root.shared.icons,
            click: root.shared.click,
            typing: root.shared.typing
        })
    readonly property var keys: F.keymap(root.own.keys, A.ARCHIVE_ACTIONS)
    readonly property string home: Quickshell.env("HOME") || "/"
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || root.home + "/.cache"
    readonly property string cacheDir: root.cacheHome + "/sylvaris/archive"
    readonly property string helper: Quickshell.shellDir + "/helpers/archive.py"
    readonly property string title: (root.archive === "" ? "Archive" : F.nameOf(root.archive)) + " — SylArchive"

    property string archive: ""
    readonly property string archiveName: F.nameOf(root.archive)
    readonly property string format: A.formatLabel(root.archive)
    readonly property bool canChange: A.writable(root.archive)
    property real archiveSize: -1
    property var tree: ({
            "": []
        })
    readonly property var counts: A.countOf(root.tree)
    property var current: ({
            path: "",
            back: [],
            forward: []
        })
    readonly property string path: root.current.path
    readonly property string inner: A.innerOf(root.archive, root.path)
    readonly property int depth: root.inner === "" ? 0 : root.inner.split("/").length
    readonly property var crumbs: root.archive === "" ? [] : A.crumbsOf(root.archive, root.path)
    readonly property var entries: A.folderOf(root.tree, root.inner)
    property string query: ""
    property bool filtering: false
    property bool locating: false
    readonly property var items: F.arrange(root.entries, {
        sort: root.cfg.sort,
        descending: root.cfg.descending,
        foldersFirst: root.cfg.foldersFirst,
        hidden: true,
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
    property string problem: ""
    property string problemText: ""
    property var menu: null
    property string dialog: ""
    property var targets: []
    property var asking: null
    property string secret: ""
    property var retry: null
    property string dragDir: ""
    property var queue: []
    property var job: null
    property var result: null
    property real done: 0
    property real total: 0
    property string note: ""
    readonly property bool noteUndo: false
    readonly property string renaming: ""
    readonly property string renameError: ""
    readonly property bool inTrash: false
    readonly property real free: -1
    readonly property var thumbs: ({})
    readonly property var clip: ({
            mode: "",
            items: []
        })

    signal opened
    signal revealed(int index)
    signal focusView
    signal focusFilter
    signal focusLocation

    function open(arg: string): void {
        const p = F.expand(arg, root.home, root.home);
        if (p === "") {
            if (root.wanted) {
                root.raise();
                return;
            }
            throw new Error("usage: archive open <archive file>");
        }
        root.secret = "";
        root.retry = null;
        root.asking = null;
        root.dialog = "";
        root.menu = null;
        root.archive = p;
        root.archiveSize = -1;
        root.tree = {
            "": []
        };
        root.current = {
            path: p,
            back: [],
            forward: []
        };
        root.arrived("");
        root.problem = "loading";
        root.problemText = "";
        const fresh = !root.wanted;
        root.wanted = true;
        root.shown = true;
        root.load();
        sweep.running = true;
        if (fresh)
            root.opened();
        else
            root.raise();
    }

    function toggleOn(screen: var): void {
        root.screenInfo = screen;
        root.toggle();
    }

    function toggle(): void {
        if (root.wanted)
            root.close();
        else
            throw new Error("usage: archive open <archive file>");
    }

    function close(): void {
        root.cancelJob();
        root.wanted = false;
        root.shown = false;
        root.menu = null;
        root.dialog = "";
        root.asking = null;
        root.secret = "";
        root.retry = null;
        root.queue = [];
    }

    function raise(): void {
        const t = ToplevelManager.toplevels.values.find(w => w.title === root.title);
        if (t)
            t.activate();
    }

    function load(): void {
        lister.running = false;
        lister.command = ["python3", root.helper].concat(root.secret !== "" ? ["--ask"] : []).concat(["list", root.archive]);
        lister.stdinEnabled = root.secret !== "";
        lister.running = true;
        sizer.running = false;
        sizer.command = ["stat", "-L", "-c", "%s", "--", root.archive];
        sizer.running = true;
    }

    function listed(r: var): void {
        if (r === null) {
            root.problem = "broken";
            root.problemText = "The archive helper did not answer";
            return;
        }
        if (r.password !== "") {
            root.problem = "locked";
            root.askPassword(r.password === "wrong", null);
            return;
        }
        if (r.failed.length > 0) {
            root.problem = "broken";
            root.problemText = r.failed[0].error;
            return;
        }
        if (root.asking !== null && root.asking.kind === "password")
            root.asking = null;
        root.tree = A.treeOf(r.entries);
        root.problem = "";
        if (root.inner !== "" && root.tree[root.inner] === undefined)
            root.current = F.visit(root.current, root.archive);
        root.rescan();
    }

    function askPassword(wrong: bool, op: var): void {
        root.retry = op;
        root.asking = {
            kind: "password",
            title: "“" + root.archiveName + "” has a password",
            text: op === null ? "Type it to see what is inside." : "Type it to unpack the files.",
            glyph: F.GLYPH.lock,
            password: true,
            value: "",
            placeholder: "Password",
            button: "Unlock",
            error: wrong ? "Wrong password" : "",
            busy: false
        };
    }

    function answer(value: string, choice: string): void {
        const a = root.asking;
        if (a === null || a.busy || value === "")
            return;
        if (a.kind === "password") {
            root.secret = value;
            root.asking = Object.assign({}, a, {
                busy: true,
                error: ""
            });
            if (root.retry !== null) {
                const op = root.retry;
                root.retry = null;
                root.asking = null;
                root.run(op);
            } else {
                root.load();
            }
        } else if (a.kind === "extractTo") {
            const dest = F.expand(value, root.home, F.parentOf(root.archive));
            if (dest === "")
                return;
            root.asking = null;
            root.extract(a.names, dest);
        }
    }

    function cancelAsk(): void {
        root.asking = null;
        root.retry = null;
        root.focusView();
    }

    function rescan(): void {
        root.selected = root.selected.filter(n => root.names.indexOf(n) >= 0);
        if (root.wanting.length > 0) {
            const have = root.names.filter(n => root.wanting.indexOf(n) >= 0);
            if (have.length > 0) {
                root.selected = have;
                root.anchor = have[0];
                root.cursor = have[have.length - 1];
                root.revealed(root.names.indexOf(root.cursor));
            }
            root.wanting = [];
        }
    }

    function arrived(old: string): void {
        root.selected = [];
        root.anchor = "";
        root.cursor = "";
        root.query = "";
        root.filtering = false;
        root.locating = false;
        root.menu = null;
        root.wanting = old !== "" && F.parentOf(old) === root.path ? [F.nameOf(old)] : [];
        Qt.callLater(root.rescan);
        root.focusView();
    }

    function inside(p: string): bool {
        return p === root.archive || p.startsWith(root.archive + "/");
    }

    function go(p: string): void {
        if (p === "" || p === root.path || !root.inside(p))
            return;
        const old = root.path;
        root.current = F.visit(root.current, p);
        root.arrived(old);
    }

    function goTo(text: string): void {
        const p = F.expand(text, root.home, root.path);
        if (!root.inside(p))
            throw new Error("that is not inside " + root.archiveName);
        root.go(p);
    }

    function back(): void {
        const old = root.path;
        root.current = F.goBack(root.current);
        if (root.path !== old)
            root.arrived(old);
    }

    function forward(): void {
        const old = root.path;
        root.current = F.goForward(root.current);
        if (root.path !== old)
            root.arrived(old);
    }

    function up(): void {
        if (root.path !== root.archive)
            root.go(F.parentOf(root.path));
    }

    function newTab(p: string): void {
        root.go(p);
    }

    function say(text: string, undo: bool): void {
        root.note = text;
        noteTimer.restart();
    }

    function undo(): void {
    }

    function cancelRename(): void {
    }

    function restoreSelected(): void {
    }

    function entryOf(name: string): var {
        return root.entries.find(e => e.name === name) || null;
    }

    function innerPath(name: string): string {
        return A.joinInner(root.inner, name);
    }

    function pick(name: string, mode: string): void {
        const r = F.pick(root.selected, root.names, name, mode, root.anchor || name);
        root.selected = r.selected;
        root.anchor = r.anchor;
        root.cursor = name;
    }

    function press(name: string, mods: int): void {
        root.menu = null;
        if (mods & Qt.ShiftModifier)
            root.pick(name, mods & Qt.ControlModifier ? "extend" : "range");
        else if (mods & Qt.ControlModifier)
            root.pick(name, "toggle");
        else if (!root.selection[name])
            root.pick(name, "only");
        else
            root.cursor = name;
        root.dragDir = root.cacheDir + "/" + Qt.md5(root.archive) + "/drag-" + Date.now();
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

    function chosen(): var {
        return root.selected.length > 0 ? root.selected : root.cursor !== "" ? [root.cursor] : [];
    }

    function activate(name: string, inTab: bool): void {
        const e = root.entryOf(name);
        if (e === null)
            return;
        if (e.dir)
            root.go(F.joinPath(root.path, name));
        else
            root.peek([name], true);
    }

    function openSelected(): void {
        const list = root.chosen();
        const dirs = list.filter(n => {
            const e = root.entryOf(n);
            return e !== null && e.dir;
        });
        if (list.length === 1 && dirs.length === 1)
            root.go(F.joinPath(root.path, dirs[0]));
        else if (list.length > dirs.length)
            root.peek(list.filter(n => dirs.indexOf(n) < 0), true);
    }

    function peek(names: var, launch: bool): void {
        root.run({
            kind: "peek",
            names: names.map(n => root.innerPath(n)),
            dest: launch ? root.cacheDir + "/" + Qt.md5(root.archive) + "/open-" + Date.now() : root.dragDir,
            mode: "into",
            strip: root.depth,
            launch: launch
        });
    }

    function dragUris(name: string): string {
        const list = root.selection[name] ? root.selected : [name];
        return F.urisOf(list.map(n => root.dragDir + "/" + n));
    }

    function dragging(name: string): void {
        root.peek(root.selection[name] ? root.selected : [name], false);
    }

    function extract(names: var, dest: string): void {
        root.run({
            kind: "extract",
            names: names.map(n => root.innerPath(n)),
            dest: dest,
            mode: names.length > 0 ? "into" : root.own.extract,
            strip: names.length > 0 ? root.depth : 0,
            launch: false
        });
    }

    function extractText(text: string): void {
        const dest = F.expand(text, root.home, F.parentOf(root.archive));
        if (dest === "")
            throw new Error("usage: archive extract [folder]");
        root.extract(root.selected, dest);
    }

    function extractTo(names: var): void {
        root.asking = {
            kind: "extractTo",
            names: names,
            title: names.length === 0 ? "Extract everything to" : "Extract " + (names.length === 1 ? "“" + names[0] + "”" : names.length + " items") + " to",
            text: "A folder that does not exist yet is made for you.",
            glyph: F.GLYPH.folderOpen,
            password: false,
            value: F.pretty(F.parentOf(root.archive), root.home),
            placeholder: "Folder",
            button: "Extract",
            error: "",
            busy: false
        };
    }

    function removeSelected(): void {
        const list = root.chosen();
        if (list.length === 0)
            return;
        if (!root.canChange) {
            root.say(root.format + "s can only be read; extract the files to change them", false);
            return;
        }
        root.targets = list.map(n => root.innerPath(n));
        root.dialog = "remove";
    }

    function confirm(): void {
        const d = root.dialog;
        root.dialog = "";
        if (d === "remove")
            root.run({
                kind: "remove",
                paths: root.targets
            });
        root.focusView();
    }

    function dropped(dest: string, urls: var, action: int): void {
        root.addSources(dest, F.pathsOfUris(urls.map(u => String(u)).join("\n")));
    }

    function addFiles(list: var): void {
        const sources = list.map(t => F.expand(t, root.home, root.home)).filter(p => p !== "");
        if (!root.wanted)
            throw new Error("SylArchive is not open; open an archive with: sylvaris archive open <file>");
        if (sources.length === 0)
            throw new Error("usage: archive add <file>...");
        root.addSources(root.path, sources);
    }

    function addSources(dest: string, list: var): void {
        const sources = list.filter(p => !root.inside(p) && p !== root.archive);
        if (sources.length === 0)
            return;
        if (!root.canChange) {
            root.say(root.format + "s can only be read; pack the files into a new archive from SylFiles instead", false);
            return;
        }
        root.run({
            kind: "add",
            inner: A.innerOf(root.archive, root.inside(dest) ? dest : root.path),
            sources: sources
        });
    }

    function reveal(): void {
        try {
            Ipc.run(["files", "open", root.archive]);
        } catch (e) {
            root.say("Turn SylFiles on to show the archive there", false);
        }
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

    function menuOf(at: var, item: var): var {
        const sep = {
            sep: true
        };
        if (at.view) {
            const radio = (label, on, run) => item(label, "", "", {
                    check: on,
                    run: run
                });
            return [radio("Grid", root.cfg.view === "grid", () => root.act("grid")), radio("List", root.cfg.view === "list", () => root.act("list")), sep, radio("Sort by name", root.cfg.sort === "name", () => Settings.put("files.sort", "name")), radio("Sort by date modified", root.cfg.sort === "modified", () => Settings.put("files.sort", "modified")), radio("Sort by size", root.cfg.sort === "size", () => Settings.put("files.sort", "size")), radio("Sort by kind", root.cfg.sort === "kind", () => Settings.put("files.sort", "kind")), radio("Reversed", root.cfg.descending, () => Settings.put("files.descending", !root.cfg.descending)), radio("Folders first", root.cfg.foldersFirst, () => Settings.put("files.foldersFirst", !root.cfg.foldersFirst)), sep, item("Settings and keys…", Icons.GLYPHS.tune, "", {
                        run: () => Ipc.run(["settings", "open", "archive"])
                    })];
        }
        const ready = root.problem === "";
        if (at.name === "")
            return [item("Extract everything", F.GLYPH.extract, "extractAll", {
                        enabled: ready
                    }), item("Extract to…", F.GLYPH.folderOpen, "extractTo", {
                        enabled: ready
                    }), sep, item("Select all", F.GLYPH.selectAll, "selectAll", {
                        enabled: root.items.length > 0
                    }), sep, item("Show the archive in SylFiles", F.GLYPH.folder, "reveal"), item("Reload", Icons.GLYPHS.restart, "reload")];
        return [item("Open", F.GLYPH.openWith, "open"), sep, item("Extract", F.GLYPH.extract, "extract"), item("Extract to…", F.GLYPH.folderOpen, "extractTo"), sep, item("Remove from the archive", F.GLYPH.deleteForever, "remove", {
                        danger: true,
                        enabled: root.canChange
                    })];
    }

    function act(id: string): void {
        const a = {
            open: () => root.openSelected(),
            extract: () => root.extract(root.chosen(), F.parentOf(root.archive)),
            extractAll: () => root.extract([], F.parentOf(root.archive)),
            extractTo: () => root.extractTo(root.chosen()),
            remove: () => root.removeSelected(),
            back: () => root.back(),
            forward: () => root.forward(),
            up: () => root.up(),
            location: () => {
                root.locating = true;
                root.focusLocation();
            },
            search: () => {
                root.filtering = true;
                root.focusFilter();
            },
            selectAll: () => root.selectNames(root.names),
            invert: () => root.selectNames(F.invert(root.selected, root.names)),
            grid: () => Settings.put("archive.view", "grid"),
            list: () => Settings.put("archive.view", "list"),
            reveal: () => root.reveal(),
            reload: () => root.load(),
            quit: () => root.close()
        }[id];
        if (a === undefined)
            throw new Error("unknown action: " + id + "; one of " + A.ARCHIVE_ACTIONS.map(x => x.id).join(", "));
        if (!root.wanted)
            throw new Error("SylArchive is not open; open an archive with: sylvaris archive open <file>");
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
        if (root.problem !== "" && op.kind !== "peek") {
            root.say("Wait until the archive is open", false);
            return;
        }
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
        root.done = 0;
        root.total = 0;
        const ask = root.secret !== "" ? ["--ask"] : [];
        const base = ["python3", root.helper].concat(ask);
        runner.command = op.kind === "extract" || op.kind === "peek" ? base.concat(["extract", root.archive, op.dest, op.mode, String(op.strip)]).concat(op.names) : op.kind === "add" ? base.concat(["add", root.archive, op.inner]).concat(op.sources) : base.concat(["remove", root.archive]).concat(op.paths);
        runner.stdinEnabled = root.secret !== "";
        runner.running = true;
    }

    function cancelJob(): void {
        if (root.job !== null && runner.running)
            runner.signal(15);
    }

    function finish(code: int): void {
        const op = root.job;
        const r = root.result || {
            ok: [],
            failed: code === 0 ? [] : [{
                    path: root.archive,
                    error: "The archive helper stopped"
                }],
            cancelled: false,
            password: ""
        };
        if (r.password !== "") {
            root.secret = "";
            root.askPassword(r.password === "wrong", op);
        } else if (op.kind === "peek") {
            if (r.failed.length > 0)
                root.say(A.extractNote(r), false);
            else if (op.launch)
                for (const pair of r.ok)
                    Quickshell.execDetached(["gio", "open", pair[1]]);
        } else if (op.kind === "extract") {
            root.say(A.extractNote(r), false);
            if (r.ok.length > 0 && r.failed.length === 0 && !r.cancelled && root.own.reveal)
                try {
                    Ipc.run(["files", "open", r.ok[0][1]]);
                } catch (e) {}
        } else if (op.kind === "add") {
            root.say(r.cancelled ? "Stopped" : r.failed.length > 0 ? F.nameOf(r.failed[0].path) + ": " + r.failed[0].error : "Added " + (r.ok.length === 1 ? "“" + F.nameOf(r.ok[0][1]) + "”" : r.ok.length + " items"), false);
            root.wanting = r.ok.map(p => p[1]).filter(p => F.parentOf(p) === root.path).map(p => F.nameOf(p));
            root.load();
        } else if (op.kind === "remove") {
            root.say(r.cancelled ? "Stopped" : r.failed.length > 0 ? r.failed[0].error : "Removed " + (op.paths.length === 1 ? "“" + F.nameOf(op.paths[0]) + "”" : op.paths.length + " items"), false);
            root.load();
        }
        root.next();
    }

    function state(): var {
        return {
            open: root.wanted,
            archive: root.archive,
            path: root.inner,
            format: root.format,
            writable: root.canChange,
            problem: root.problem,
            count: root.items.length,
            items: root.names.slice(0, 200),
            selected: root.selected,
            files: root.counts.files,
            folders: root.counts.folders,
            bytes: root.counts.bytes,
            busy: root.job !== null,
            progress: root.total > 0 ? Math.round(root.done / root.total * 100) / 100 : 0,
            note: root.note,
            menu: root.menu !== null,
            dialog: root.dialog,
            asking: root.asking === null ? "" : root.asking.kind,
            askError: root.asking === null ? "" : root.asking.error
        };
    }

    Process {
        id: lister
        property var last: null
        stdout: SplitParser {
            onRead: line => {
                if (line.charAt(0) !== "{")
                    return;
                try {
                    lister.last = JSON.parse(line);
                } catch (e) {
                    lister.last = null;
                }
            }
        }
        onStarted: {
            if (lister.stdinEnabled) {
                lister.write(root.secret + "\n");
                lister.stdinEnabled = false;
            }
        }
        onRunningChanged: {
            if (lister.running)
                lister.last = null;
        }
        onExited: root.listed(lister.last)
    }

    Process {
        id: sizer
        stdout: StdioCollector {
            onStreamFinished: root.archiveSize = /^\d+/.test(text) ? Number(text.trim()) : -1
        }
    }

    Process {
        id: sweep
        command: ["sh", "-c", "mkdir -p \"$1\" && find \"$1\" -mindepth 2 -maxdepth 2 -mmin +1440 -exec rm -rf {} +", "sh", root.cacheDir]
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
                } else if (msg.total !== undefined) {
                    root.total = msg.total;
                    root.done = msg.done;
                }
            }
        }
        onStarted: {
            if (runner.stdinEnabled) {
                runner.write(root.secret + "\n");
                runner.stdinEnabled = false;
            }
        }
        onExited: code => root.finish(code)
    }

    Timer {
        id: noteTimer
        interval: 4200
        onTriggered: root.note = ""
    }

    LazyLoader {
        active: root.shown

        ArchiveWindow {
            archive: root
        }
    }
}
