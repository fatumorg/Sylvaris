pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import SylStack
import "../lib/look.mjs" as L
import "../lib/settings.mjs" as S
import "../lib/paper.mjs" as W
import "../lib/palette.mjs" as P

Singleton {
    id: root

    readonly property string dir: Settings.dir + "/looks"
    property var userLooks: ({})
    property var ids: []
    readonly property var families: Qt.fontFamilies()
    readonly property var sections: L.SECTIONS
    readonly property var glassResult: S.resolveGlass(Config.values.glass, Settings.values.glass, {})
    readonly property var lookErrors: L.validateLook(Config.values.look, root.userLooks).errors.concat(L.validateLook(Settings.raw.look, root.userLooks).errors)
    readonly property var values: L.resolveLook(Settings.values.look, root.glassResult.values, root.userLooks)
    readonly property var glass: root.values.glass
    readonly property string material: root.values.material
    readonly property real radius: root.values.radius
    readonly property real density: root.values.density
    readonly property string corners: root.values.corners
    readonly property var fonts: ({
            ui: L.pickFont(root.values.fonts.ui, root.families, "Inter"),
            mono: L.pickFont(root.values.fonts.mono, root.families, "JetBrainsMono Nerd Font"),
            display: L.pickFont(root.values.fonts.display, root.families, L.pickFont(root.values.fonts.ui, root.families, "Inter"))
        })
    readonly property int weight: root.values.weight === "light" ? Font.Normal : root.values.weight === "medium" ? Font.Bold : root.values.weight === "heavy" ? Font.Black : Font.DemiBold
    readonly property int labelCase: root.values.labelCase === "upper" ? Font.AllUppercase : root.values.labelCase === "smallcaps" ? Font.SmallCaps : Font.MixedCase
    property string followed: ""
    property string shuffledDay: ""
    readonly property string dayPath: (Stack.env("XDG_STATE_HOME") || Settings.home + "/.local/state") + "/sylvaris/shuffle-day"
    readonly property string wallPath: root.wallFor(Theme.currentId, Theme.wallpaper)
    readonly property string wallAccent: root.values.accent === "wallpaper" && root.wallPath !== "" ? P.accentFrom(Stack.pixels(root.wallPath, 64)) : ""
    readonly property string accentHex: root.values.accent === "wallpaper" ? root.wallAccent : root.values.accent === "theme" ? "" : root.values.accent
    readonly property string notice: {
        const errors = root.glassResult.errors.concat(root.lookErrors);
        return errors.length === 0 ? "" : "Look: " + errors.join("; ");
    }

    onNoticeChanged: {
        if (root.notice !== "")
            console.warn("sylvaris: " + root.notice);
    }

    function wallFor(id: string, wallpaper: string): string {
        return S.expandHome(W.resolve(Settings.values.paper, id, wallpaper, ""), Settings.home);
    }

    function glassFor(role: string): var {
        return L.glassFor(root.values, role);
    }

    function previewFor(id: string): var {
        if (L.LOOKS[id] === undefined && root.userLooks[id] === undefined)
            return null;
        return L.glassFor(L.resolveLook({
            preset: id
        }, {}, root.userLooks), "");
    }

    function list(): var {
        return Object.keys(L.LOOKS).concat(Object.keys(root.userLooks).filter(id => L.LOOKS[id] === undefined).sort());
    }

    function origin(id: string): string {
        return L.originOf(id, root.userLooks);
    }

    function styleOf(id: string): var {
        const s = root.userLooks[id] !== undefined ? root.userLooks[id] : L.LOOKS[id];
        if (s === undefined)
            throw new Error("unknown style: " + id);
        return s;
    }

    function keep(id: string, style: var): void {
        const v = L.validateStyle(L.styleFile(style));
        if (v === null)
            throw new Error("a style needs a name");
        root.store(id, L.styleFile(v));
    }

    function update(id: string, section: string, key: string, value: var): void {
        const s = JSON.parse(JSON.stringify(root.styleOf(id)));
        if (section === "name") {
            s.name = String(value).slice(0, 40);
        } else {
            if (L.SECTIONS.indexOf(section) < 0)
                throw new Error("unknown section: " + section);
            s[section][key] = value;
            if (JSON.stringify(L.validateStyle(L.styleFile(s))[section][key]) !== JSON.stringify(value))
                throw new Error("not a valid " + section + "." + key + ": " + JSON.stringify(value));
        }
        root.keep(id, s);
    }

    function takeFrom(id: string, section: string, fromId: string): void {
        if (L.SECTIONS.indexOf(section) < 0)
            throw new Error("unknown section: " + section);
        root.keep(id, L.takeSection(root.styleOf(id), section, root.styleOf(fromId)));
    }

    function create(name: string, fromId: string): string {
        const id = L.slugLook(name);
        if (id === "")
            throw new Error(String(name).trim() === "" ? "give the style a name" : "pick a name that is not a built-in style");
        if (root.userLooks[id] !== undefined)
            throw new Error("you already have a style called " + id);
        const s = JSON.parse(JSON.stringify(root.styleOf(fromId)));
        s.name = String(name).trim().slice(0, 40);
        root.keep(id, s);
        return id;
    }

    function duplicate(id: string): string {
        const base = root.styleOf(id).name + " copy";
        let name = base;
        for (let n = 2; root.userLooks[L.slugLook(name)] !== undefined || L.slugLook(name) === ""; n++)
            name = base + " " + n;
        return root.create(name, id);
    }

    function forget(id: string): void {
        if (!/^[a-z0-9][a-z0-9-]{0,39}$/.test(id) || root.userLooks[id] === undefined)
            throw new Error("no style file for " + id);
        remover.command = ["rm", "-f", "--", root.dir + "/" + id + ".json"];
        remover.running = true;
        const next = Object.assign({}, root.userLooks);
        delete next[id];
        root.userLooks = next;
    }

    function remove(id: string): void {
        if (L.LOOKS[id] !== undefined)
            throw new Error("built-in styles cannot be removed; use look reset " + id);
        const active = Settings.values.look.preset === id;
        root.forget(id);
        if (active)
            root.set(L.DEFAULT_LOOK.preset);
    }

    function reset(id: string): void {
        if (L.LOOKS[id] === undefined)
            throw new Error("only built-in styles can be reset: " + id);
        root.forget(id);
    }

    function set(id: string): void {
        if (L.LOOKS[id] === undefined && root.userLooks[id] === undefined)
            throw new Error("unknown look: " + id);
        if (!Settings.ready || Settings.frozen)
            throw new Error(Settings.notice || "settings are still loading");
        Settings.remember("look", false);
        Settings.setRaw(L.applyLook(Settings.raw, id, root.userLooks));
    }

    function write(path: string, look: var): void {
        writer.path = path;
        writer.setText(JSON.stringify(look, null, 2) + "\n");
    }

    function filePath(path: string): string {
        const p = S.expandHome(String(path || ""), Settings.home);
        if (!p.startsWith("/"))
            throw new Error("give a full path, like ~/my-look.json");
        return p;
    }

    function store(id: string, look: var): void {
        root.write(root.dir + "/" + id + ".json", look);
        root.remember(id, JSON.stringify(look));
        if (root.ids.indexOf(id) < 0)
            root.ids = root.ids.concat([id]).sort();
    }

    function save(name: string): string {
        const id = L.slugLook(name);
        if (id === "")
            throw new Error(String(name).trim() === "" ? "usage: look save <name>" : "pick a name that is not a built-in look");
        root.store(id, L.lookFile(name, root.values, L.lookDefaults(Settings.values.look, root.userLooks)));
        return id;
    }

    function exportTo(path: string, id: string): string {
        const p = root.filePath(path);
        if (id && root.userLooks[id] === undefined)
            throw new Error("only your own looks can be exported: " + Object.keys(root.userLooks).sort().join(", "));
        const key = id || Settings.values.look.preset;
        root.write(p, root.userLooks[key] !== undefined ? root.userLooks[key] : L.lookFile(root.values.name + " custom", root.values, L.lookDefaults(Settings.values.look, root.userLooks)));
        return p;
    }

    function importFrom(path: string): string {
        reader.path = root.filePath(path);
        reader.reload();
        const p = S.parseJson(reader.text());
        const look = p.ok ? L.validateUserLook(p.value) : null;
        if (look === null)
            throw new Error("not a look file: " + reader.path);
        const id = L.slugLook(look.name);
        if (id === "")
            throw new Error("a look cannot be named like a built-in one: " + look.name);
        if (root.userLooks[id] !== undefined)
            throw new Error("you already have a look called " + id);
        root.store(id, look);
        return id;
    }

    function follow(): void {
        if (!Settings.ready || !Settings.values.look.followTheme || Theme.currentId === "" || Theme.currentId === root.followed)
            return;
        const entry = Theme.catalog[Theme.currentId];
        if (entry === undefined)
            return;
        root.followed = Theme.currentId;
        const want = entry.look || "";
        if (want !== "" && want !== Settings.values.look.preset && (L.LOOKS[want] !== undefined || root.userLooks[want] !== undefined))
            root.set(want);
    }

    function shuffle(seed: real): var {
        const p = L.shufflePick(root.list(), Theme.ids, seed, {
            look: Settings.values.look.preset,
            theme: Theme.currentId
        });
        if (p.theme !== "") {
            root.followed = p.theme;
            Theme.apply(p.theme);
        }
        if (p.look !== "")
            root.set(p.look);
        return p;
    }

    function daily(): void {
        const day = Qt.formatDate(new Date(), "yyyy-MM-dd");
        if (day === root.shuffledDay || day === dayFile.text().trim())
            return;
        root.shuffledDay = day;
        root.shuffle(L.daySeed(day));
        dayWriter.command = ["sh", "-c", "mkdir -p \"${1%/*}\" && printf %s \"$2\" > \"$1.tmp\" && mv -f \"$1.tmp\" \"$1\"", "sh", root.dayPath, day];
        dayWriter.running = true;
    }

    function remember(id: string, text: string): void {
        const p = S.parseJson(text);
        const look = p.ok ? L.validateUserLook(p.value) : null;
        const next = Object.assign({}, root.userLooks);
        if (look === null)
            delete next[id];
        else
            next[id] = look;
        root.userLooks = next;
    }

    function refreshIds(): void {
        const out = [];
        for (let i = 0; i < folder.count; i++) {
            const id = String(folder.get(i, "fileBaseName"));
            if (/^[a-z0-9][a-z0-9-]{0,39}$/.test(id))
                out.push(id);
        }
        root.ids = out.sort();
        const next = {};
        for (const id of root.ids) {
            if (root.userLooks[id] !== undefined)
                next[id] = root.userLooks[id];
        }
        root.userLooks = next;
    }

    Connections {
        target: Theme

        function onCurrentIdChanged(): void {
            root.follow();
        }

        function onCatalogChanged(): void {
            root.follow();
        }
    }

    Connections {
        target: Settings

        function onReadyChanged(): void {
            root.follow();
        }
    }

    Timer {
        interval: 60000
        repeat: true
        triggeredOnStart: true
        running: Settings.ready && !Settings.frozen && Settings.values.look.shuffle === "daily" && Theme.ids.length > 0
        onTriggered: root.daily()
    }

    FileView {
        id: dayFile
        path: root.dayPath
        blockLoading: true
        printErrors: false
    }

    Process {
        id: dayWriter
    }

    Process {
        id: remover
    }

    FileView {
        id: writer
        preload: false
        atomicWrites: true
        printErrors: false
    }

    FileView {
        id: reader
        preload: false
        printErrors: false
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: folder.folder = "file://" + root.dir
    }

    FolderListModel {
        id: folder
        nameFilters: ["*.json"]
        showDirs: false
        onCountChanged: root.refreshIds()
    }

    Instantiator {
        model: root.ids
        delegate: FileView {
            required property string modelData
            path: root.dir + "/" + modelData + ".json"
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onLoaded: root.remember(modelData, text())
            onLoadFailed: root.remember(modelData, "")
        }
    }
}
