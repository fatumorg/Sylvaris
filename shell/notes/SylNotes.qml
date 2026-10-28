import QtQuick
import SylStack
import qs.services
import "../lib/notes.mjs" as N
import "../lib/files.mjs" as F

Scope {
    id: root

    property var screenInfo: null
    readonly property bool windowed: true
    readonly property string home: Stack.env("HOME") || "/"
    readonly property string swapDir: (Stack.env("XDG_STATE_HOME") || root.home + "/.local/state") + "/sylvaris/notes"
    property bool swapReady: false
    property var found: []
    property var swaps: []
    property int made: 0
    property int untitled: 0
    property int zoom: 0
    readonly property string themeJson: JSON.stringify(N.highlightTheme(Theme.target), null, 2) + "\n"
    readonly property string themePath: (Stack.env("XDG_DATA_HOME") || root.home + "/.local/share") + "/org.kde.syntax-highlighting/themes/sylvaris.theme"
    readonly property bool dark: Theme.base.hslLightness < 0.5
    property string themeWriting: ""
    property string themeBaked: ""
    property bool themeSettled: false
    property var windows: []
    property var last: null
    property var pending: []
    readonly property var current: root.last !== null && root.windows.indexOf(root.last) >= 0 ? root.last : root.windows.length > 0 ? root.windows[0] : null
    readonly property bool wanted: root.windows.length > 0

    signal opened

    function paths(list: var): var {
        return list.map(p => F.expand(String(p), root.home, root.home)).filter(p => p !== "");
    }

    function open(list: var): void {
        const ps = root.paths(list);
        if (!root.wanted) {
            root.newWindow(ps);
            return;
        }
        const w = root.current;
        for (const p of ps)
            w.openFile(p, root.claim(p));
        w.raise();
        root.opened();
    }

    function newWindow(list: var): void {
        root.pending = root.paths(list);
        slots.append({
            slot: root.made
        });
        root.made += 1;
    }

    function newTab(): void {
        if (!root.wanted)
            root.newWindow([]);
        else
            root.current.newTab(null);
    }

    function save(): void {
        if (root.current === null)
            throw new Error("SylNotes is not open; open a file with: sylvaris notes open <file>");
        const e = root.current.editor;
        if (e.path === "")
            throw new Error("this tab has no file yet; press Ctrl+S in the window to pick one");
        if (e.readOnly)
            throw new Error(e.why !== "" ? e.why : "this file is read-only");
        if (!e.save())
            throw new Error(e.problem);
    }

    function close(): void {
        slots.clear();
    }

    function drop(slot: int): void {
        for (let i = slots.count - 1; i >= 0; i--) {
            if (slots.get(i).slot === slot)
                slots.remove(i);
        }
    }

    function toggleOn(screen: var): void {
        root.screenInfo = screen;
        root.toggle();
    }

    function toggle(): void {
        if (root.wanted)
            root.close();
        else
            root.open([]);
    }

    function bake(): void {
        if (themeWriter.running || root.themeWriting === root.themeJson)
            return;
        root.themeWriting = root.themeJson;
        themeWriter.running = true;
    }

    function zoomBy(d: int): void {
        const size = Settings.values.notes.size;
        root.zoom = d === 0 ? 0 : Math.max(6 - size, Math.min(64 - size, root.zoom + d));
    }

    onThemeJsonChanged: {
        if (root.themeSettled)
            root.bake();
    }

    function nextUntitled(): int {
        root.untitled += 1;
        return root.untitled;
    }

    function remember(p: string): void {
        if (p !== "" && Settings.values.notes.recent[0] !== p)
            Settings.put("notes.recent", N.pushRecent(Settings.values.notes.recent, p));
    }

    function claim(p: string): var {
        const s = root.swaps.find(x => x.path === p) || null;
        if (s !== null)
            root.swaps = root.swaps.filter(x => x !== s);
        return s;
    }

    function adopt(): void {
        if (!root.swapReady || root.current === null || root.swaps.length === 0)
            return;
        const list = root.swaps;
        root.swaps = [];
        for (const s of list) {
            if (s.path !== "")
                root.current.openFile(s.path, s);
            else
                root.current.newTab(s);
        }
    }

    function attach(index: int, w: var): void {
        const list = root.windows.slice();
        list.splice(index, 0, w);
        root.windows = list;
        root.last = w;
        const ps = root.pending;
        root.pending = [];
        for (const p of ps)
            w.openFile(p, root.claim(p));
        root.adopt();
        if (w.editors.length === 0)
            w.newTab(null);
        root.opened();
    }

    function state(): var {
        const w = root.current;
        const tabs = w === null ? [] : w.editors.map(e => ({
                    path: e.path,
                    title: e.title,
                    dirty: e.dirty,
                    readOnly: e.readOnly,
                    why: e.why,
                    eol: e.eol,
                    language: e.language,
                    highlighted: e.highlighted,
                    recovered: e.recovered,
                    problem: e.problem,
                    length: e.edit.length
                }));
        return {
            open: root.wanted,
            windows: root.windows.length,
            swaps: root.swapReady,
            tab: w === null ? -1 : w.tab,
            asking: w !== null && w.asking !== null,
            tabs: tabs,
            recovered: root.windows.reduce((n, x) => n + x.editors.filter(e => e.recovered).length, 0),
            zoom: root.zoom,
            find: w === null ? null : w.findState(),
            line: w !== null && w.editor !== null ? w.editor.line : 0,
            column: w !== null && w.editor !== null ? w.editor.column : 0
        };
    }

    ListModel {
        id: slots
    }

    Instantiator {
        model: slots

        NotesWindow {
            notes: root
        }

        onObjectAdded: (index, w) => root.attach(index, w)
        onObjectRemoved: (index, w) => {
            root.windows = root.windows.filter(x => x !== w);
            if (root.last === w)
                root.last = null;
        }
    }

    Process {
        id: themeWriter
        command: ["sh", "-c", "mkdir -p \"${1%/*}\" && printf %s \"$2\" > \"$1.tmp\" && mv -f \"$1.tmp\" \"$1\"", "sh", root.themePath, root.themeWriting]
        onExited: code => {
            if (!root.themeSettled && code === 0)
                root.themeBaked = root.themeWriting;
            root.themeSettled = true;
            if (root.themeWriting !== root.themeJson)
                root.bake();
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "umask 077; mkdir -p \"$1\" && chmod 700 \"$1\" && for f in \"$1\"/*.swp; do [ -f \"$f\" ] && cat \"$f\"; done; exit 0", "sh", root.swapDir]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const r = JSON.parse(line);
                    if (r !== null && typeof r.text === "string" && typeof r.key === "string" && typeof r.path === "string")
                        root.found.push(r);
                } catch (e) {}
            }
        }
        onExited: {
            root.swaps = root.found;
            root.found = [];
            root.swapReady = true;
            root.adopt();
        }
    }
}
