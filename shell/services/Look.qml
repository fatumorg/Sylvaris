pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import SylStack
import "../lib/look.mjs" as L
import "../lib/settings.mjs" as S

Singleton {
    id: root

    readonly property string dir: Settings.dir + "/looks"
    property var userLooks: ({})
    property var ids: []
    readonly property var families: Qt.fontFamilies()
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
    readonly property int weight: root.values.weight === "light" ? Font.Normal : root.values.weight === "medium" ? Font.Bold : Font.DemiBold
    readonly property string notice: {
        const errors = root.glassResult.errors.concat(root.lookErrors);
        return errors.length === 0 ? "" : "Look: " + errors.join("; ");
    }

    onNoticeChanged: {
        if (root.notice !== "")
            console.warn("sylvaris: " + root.notice);
    }

    function glassFor(role: string): var {
        return L.glassFor(root.values, role);
    }

    function remember(id: string, text: string): void {
        const p = S.parseJson(text);
        const look = p.ok ? L.validateUserLook(p.value) : null;
        const next = Object.assign({}, root.userLooks);
        if (look === null || L.LOOKS[id] !== undefined)
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

    FolderListModel {
        id: folder
        folder: "file://" + root.dir
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
