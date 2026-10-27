pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import SylStack
import qs
import "../lib/theme.mjs" as T
import "../lib/settings.mjs" as S

Singleton {
    id: root

    readonly property string home: Stack.env("HOME")
    readonly property string stateFile: S.expandHome(Config.values.themeStateFile, root.home)
    readonly property string themesDir: S.expandHome(Config.values.themesDir, root.home)
    readonly property string configHome: Stack.env("XDG_CONFIG_HOME") || root.home + "/.config"
    property int linked: 0
    property bool relink: false
    property string currentId: ""
    property var theme: T.DEFAULT_THEME
    property var errors: []

    onErrorsChanged: {
        for (const e of root.errors)
            console.warn("sylvaris: " + e);
    }
    property var ids: []
    readonly property var target: T.tokens(root.theme)
    property var fromTokens: T.tokens(T.DEFAULT_THEME)
    property var toTokens: root.fromTokens
    property real progress: 1
    readonly property var tk: T.mixTokens(root.fromTokens, root.toTokens, root.progress)
    readonly property string wallpaper: S.expandHome(root.theme.wallpaper, root.home)

    property color base: root.tk.base
    property color surface: root.tk.surface
    property color glass: root.tk.glass
    property color node: root.tk.node
    property color line: root.tk.line
    property color lineStrong: root.tk.lineStrong
    property color cardLine: root.tk.cardLine
    property color tint: root.tk.tint
    property color tintSoft: root.tk.tintSoft
    property color tintMid: root.tk.tintMid
    property color tintStrong: root.tk.tintStrong
    property color moon: root.tk.moon
    property color fill: root.tk.fill
    property color glow: root.tk.glow
    property color silk: root.tk.silk
    property color sonar: root.tk.sonar
    property color accent: root.tk.accent
    property color accentHi: root.tk.accentHi
    property color accentDeep: root.tk.accentDeep
    property color onAccent: root.tk.onAccent
    property color text: root.tk.text
    property color textDim: root.tk.textDim
    property color textSoft: root.tk.textSoft
    property color danger: root.tk.danger
    property color pane: root.tk.pane
    property var catalog: ({})
    property string hookError: ""
    property string queued: ""
    property bool hookStuck: false

    function remember(id: string, text: string): void {
        const p = S.parseJson(text);
        const e = T.catalogEntry(id, p.ok ? p.value : null);
        e.wallpaper = S.expandHome(e.wallpaper, root.home);
        const next = Object.assign({}, root.catalog);
        next[id] = e;
        root.catalog = next;
    }

    function runHook(id: string): void {
        const hook = S.expandHome(Config.values.themeHook, root.home);
        hookProc.command = hook !== "" ? ["sh", "-c", hook + " \"$1\"", "sylvaris-theme", id] : ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf %s \"$2\" > \"$1\"", "sylvaris-theme", root.stateFile, id];
        hookProc.running = true;
    }


    onTargetChanged: {
        root.fromTokens = root.tk;
        root.toTokens = root.target;
        root.progress = 0;
        fade.restart();
    }

    NumberAnimation {
        id: fade
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Tokens.colorDuration
    }

    function fallback(reason: string): void {
        root.theme = T.DEFAULT_THEME;
        root.errors = reason === "" ? [] : [reason];
    }

    function ingest(text: string): void {
        const p = S.parseJson(text);
        if (!p.ok) {
            root.fallback("theme " + root.currentId + " is not valid JSON");
            return;
        }
        const r = T.validateTheme(p.value);
        root.theme = r.theme;
        root.errors = r.errors;
        root.link();
    }

    function link(): void {
        const cmd = T.linkCommand(root.theme.links, root.home, root.configHome);
        if (cmd === null)
            return;
        if (linkProc.running) {
            root.relink = true;
            return;
        }
        linkProc.command = cmd;
        linkProc.running = true;
    }

    function linkDone(text: string): void {
        const r = T.parseLinkOutput(text);
        root.linked = r.changed;
        if (r.missing.length > 0)
            root.errors = root.errors.concat(r.missing.map(m => "link source not found: " + m));
        if (r.changed === 0 || Demo.enabled)
            return;
        Stack.execDetached(["pkill", "-USR1", "kitty"]);
        Stack.execDetached(["pkill", "-USR2", "waybar"]);
        try {
            Compositor.run("reload", []);
        } catch (e) {
            console.warn("sylvaris: " + e.message);
        }
    }

    function refreshIds(): void {
        const out = [];
        for (let i = 0; i < folder.count; i++)
            out.push(String(folder.get(i, "fileBaseName")));
        root.ids = out.sort();
    }

    function apply(id: string): void {
        if (id === "")
            return;
        if (hookProc.running) {
            root.queued = id;
            hookProc.running = false;
            return;
        }
        root.runHook(id);
    }

    function share(): void {
        const dir = Config.values.greeterShare;
        if (dir === "" || Demo.enabled || root.currentId === "" || !/^[A-Za-z0-9_.-]+$/.test(root.currentId))
            return;
        const copy = Object.assign({}, root.theme, {
            wallpaper: dir + "/wallpaper",
            links: {}
        });
        shareProc.command = ["sh", "-c", "d=\"$1\"; [ -d \"$d\" ] && [ -w \"$d\" ] || exit 0; mkdir -p \"$d/themes\" || exit 1; for p in wallpaper:\"$3\" avatar:\"$4\"; do n=${p%%:*}; f=${p#*:}; [ -f \"$f\" ] && cp -f \"$f\" \"$d/$n.part\" && mv -f \"$d/$n.part\" \"$d/$n\"; done; printf '%s' \"$5\" > \"$d/themes/$2.json\" && printf '%s' \"$2\" > \"$d/theme\"; chmod -f 664 \"$d/wallpaper\" \"$d/avatar\" \"$d/theme\" \"$d/themes/$2.json\"; exit 0", "sylvaris-share", dir, root.currentId, root.wallpaper, S.expandHome(Config.values.avatar, root.home), JSON.stringify(copy)];
        shareProc.running = false;
        shareProc.running = true;
    }

    onThemeChanged: shareTimer.restart()

    function cycle(): void {
        root.apply(T.nextThemeId(root.ids, root.currentId));
    }

    onCurrentIdChanged: {
        if (root.currentId === "")
            root.fallback("");
    }

    FileView {
        id: stateView
        path: root.stateFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.currentId = text().trim()
        onLoadFailed: root.currentId = ""
    }

    FileView {
        id: themeView
        path: root.currentId === "" ? "" : root.themesDir + "/" + root.currentId + ".json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.ingest(text())
        onLoadFailed: root.fallback("theme file not found: " + root.currentId + ".json")
    }

    FolderListModel {
        id: folder
        folder: "file://" + root.themesDir
        nameFilters: ["*.json"]
        showDirs: false
        onCountChanged: root.refreshIds()
    }

    Process {
        id: hookProc
        onExited: code => {
            root.hookError = root.hookStuck ? "The theme hook did not finish in 15 seconds and was stopped" : code === 0 || root.queued !== "" ? "" : "The theme hook failed with exit code " + code;
            root.hookStuck = false;
            if (root.queued !== "") {
                const next = root.queued;
                root.queued = "";
                root.runHook(next);
            }
        }
    }

    Timer {
        id: shareTimer
        interval: 1500
        onTriggered: root.share()
    }

    Process {
        id: shareProc
    }

    Process {
        id: linkProc
        stdout: StdioCollector {
            onStreamFinished: root.linkDone(text)
        }
        onExited: {
            if (!root.relink)
                return;
            root.relink = false;
            root.link();
        }
    }

    Timer {
        interval: 15000
        running: hookProc.running
        onTriggered: {
            root.hookStuck = true;
            hookProc.running = false;
        }
    }

    Instantiator {
        model: root.ids
        delegate: FileView {
            required property string modelData
            path: root.themesDir + "/" + modelData + ".json"
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onLoaded: root.remember(modelData, text())
            onLoadFailed: root.remember(modelData, "")
        }
    }
}
