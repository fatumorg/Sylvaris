import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/archive.mjs" as A
import "../lib/icons.mjs" as Icons

FocusScope {
    id: menu

    required property var files
    readonly property var at: menu.files.menu
    readonly property bool open: menu.at !== null
    property int lit: -1
    readonly property var entries: !menu.open ? [] : menu.files.menuOf ? menu.files.menuOf(menu.at, menu.item) : menu.build()
    readonly property var usable: menu.entries.map((e, i) => i).filter(i => !menu.entries[i].sep && menu.entries[i].enabled !== false)

    visible: panel.opacity > 0
    onOpenChanged: {
        menu.lit = -1;
        if (menu.open) {
            showAnim.restart();
            menu.forceActiveFocus();
        } else {
            showAnim.stop();
            panel.opacity = 0;
        }
    }

    function keyOf(id: string): string {
        return F.keyText((menu.files.keys.byAction[id] || [""])[0] || "");
    }

    function item(label: string, glyph: string, id: string, extra: var): var {
        return Object.assign({
            label: label,
            glyph: glyph,
            id: id,
            key: id === "" ? "" : menu.keyOf(id),
            enabled: true
        }, extra || {});
    }

    function build(): var {
        const f = menu.files;
        const sep = {
            sep: true
        };
        if (menu.at.view) {
            const radio = (label, on, run) => menu.item(label, "", "", {
                    check: on,
                    run: run
                });
            return [radio("Grid", f.cfg.view === "grid", () => f.act("grid")), radio("List", f.cfg.view === "list", () => f.act("list")), sep, radio("Sort by name", f.cfg.sort === "name", () => Settings.put("files.sort", "name")), radio("Sort by date modified", f.cfg.sort === "modified", () => Settings.put("files.sort", "modified")), radio("Sort by size", f.cfg.sort === "size", () => Settings.put("files.sort", "size")), radio("Sort by kind", f.cfg.sort === "kind", () => Settings.put("files.sort", "kind")), radio("Reversed", f.cfg.descending, () => Settings.put("files.descending", !f.cfg.descending)), radio("Folders first", f.cfg.foldersFirst, () => Settings.put("files.foldersFirst", !f.cfg.foldersFirst)), sep, Object.assign(radio("Hidden files", f.cfg.hidden, () => f.act("hidden")), {
                        key: menu.keyOf("hidden")
                    }), radio("Previews", f.cfg.thumbnails, () => Settings.put("files.thumbnails", !f.cfg.thumbnails)), Object.assign(radio("Sidebar", f.cfg.sidebar, () => f.act("sidebar")), {
                        key: menu.keyOf("sidebar")
                    }), Object.assign(radio("Details pane", f.cfg.details, () => f.act("details")), {
                        key: menu.keyOf("details")
                    }), sep, menu.item("Settings and keys…", Icons.GLYPHS.tune, "", {
                        run: () => Ipc.run(["settings", "open", "files"])
                    })];
        }
        if (menu.at.drive !== undefined) {
            const d = f.driveOf(menu.at.drive);
            if (d === null)
                return [];
            const out = d.locked ? [menu.item("Unlock…", F.GLYPH.lock, "", {
                        run: () => f.openDrive(d, false)
                    })] : [menu.item(d.mounted ? "Open" : "Mount and open", F.GLYPH.folderOpen, "", {
                        run: () => f.openDrive(d, false)
                    }), menu.item("Open in a new tab", F.GLYPH.newTab, "", {
                        run: () => f.openDrive(d, true)
                    })];
            if (!d.locked && (d.mounted || d.drive !== ""))
                out.push(sep, menu.item(d.drive !== "" ? "Safely remove" : "Unmount", F.GLYPH.eject, "", {
                    run: () => f.ejectDrive(d)
                }));
            return out;
        }
        const name = menu.at.name;
        const one = f.selected.length === 1 ? f.entryOf(f.selected[0]) : null;
        const dirOne = one !== null && one.dir;
        const anyFile = f.selected.some(n => {
            const e = f.entryOf(n);
            return e !== null && !e.dir;
        });
        if (f.inTrash) {
            if (name === "")
                return [menu.item("Empty trash", F.GLYPH.deleteForever, "", {
                        danger: true,
                        enabled: f.entries.length > 0,
                        run: () => f.dialog = "empty"
                    }), menu.item("Select all", F.GLYPH.selectAll, "selectAll")];
            return [menu.item("Restore", F.GLYPH.restore, "", {
                    run: () => f.restoreSelected()
                }), menu.item("Delete permanently", F.GLYPH.deleteForever, "delete", {
                    danger: true
                }), sep, menu.item("Details", Icons.GLYPHS.info, "details", {
                    check: f.cfg.details
                })];
        }
        if (name === "") {
            const marked = f.cfg.bookmarks.indexOf(F.pretty(f.path, f.home)) >= 0 || f.cfg.bookmarks.indexOf(f.path) >= 0;
            return [menu.item("New folder", F.GLYPH.newFolder, "newFolder", {
                    enabled: f.problem === ""
                }), menu.item("New empty file", F.GLYPH.newFile, "newFile", {
                    enabled: f.problem === ""
                }), menu.item("Paste", F.GLYPH.paste, "paste", {
                    enabled: f.problem === ""
                }), sep, menu.item("Select all", F.GLYPH.selectAll, "selectAll", {
                    enabled: f.items.length > 0
                }), menu.item("Hidden files", F.GLYPH.eyeOff, "hidden", {
                    check: f.cfg.hidden
                }), sep, menu.item(marked ? "Remove bookmark" : "Bookmark this folder", F.GLYPH.bookmark, "bookmark"), menu.item("Open a terminal here", F.GLYPH.terminal, "terminal"), menu.item("Copy path", Icons.GLYPHS.copy, "copyPath"), menu.item("Reload", Icons.GLYPHS.restart, "reload")];
        }
        const full = one !== null ? F.joinPath(f.path, one.name) : "";
        const marked = dirOne && (f.cfg.bookmarks.indexOf(F.pretty(full, f.home)) >= 0 || f.cfg.bookmarks.indexOf(full) >= 0);
        const out = [menu.item("Open", dirOne ? F.GLYPH.folderOpen : Icons.GLYPHS.open, "open")];
        if (dirOne)
            out.push(menu.item("Open in a new tab", F.GLYPH.newTab, "openTab"));
        if (anyFile)
            out.push(menu.item("Open with…", F.GLYPH.openWith, "openWith"));
        out.push(sep, menu.item("Cut", F.GLYPH.cut, "cut"), menu.item("Copy", Icons.GLYPHS.copy, "copy"));
        if (dirOne)
            out.push(menu.item("Paste into folder", F.GLYPH.paste, "", {
                run: () => f.paste(full)
            }));
        out.push(menu.item("Copy path", Icons.GLYPHS.link, "copyPath"), sep);
        const archives = f.archivesSelected();
        out.push(menu.item("Compress…", F.GLYPH.compress, "compress"));
        if (archives.length > 0)
            out.push(menu.item("Extract here", F.GLYPH.extract, "extract"), menu.item(archives.length === 1 ? "Extract to “" + A.stemOf(F.nameOf(archives[0])) + "”" : "Extract each into its own folder", F.GLYPH.folderOpen, "", {
                run: () => f.extractSelected("folder")
            }));
        if (archives.length === 1 && f.archiveOn)
            out.push(menu.item("Open in SylArchive", F.GLYPH.archive, "", {
                run: () => f.openArchive(archives[0])
            }));
        out.push(sep);
        out.push(menu.item("Rename…", Icons.GLYPHS.pencil, "rename", {
            enabled: one !== null
        }), menu.item("Move to the trash", F.GLYPH.trash, "trash"), menu.item("Delete permanently", F.GLYPH.deleteForever, "delete", {
            danger: true
        }));
        if (dirOne)
            out.push(sep, menu.item(marked ? "Remove bookmark" : "Bookmark", F.GLYPH.bookmark, "", {
                run: () => f.toggleBookmark(full)
            }), menu.item("Open a terminal here", F.GLYPH.terminal, "terminal"));
        out.push(sep, menu.item("Details", Icons.GLYPHS.info, "details", {
            check: f.cfg.details
        }));
        return out;
    }

    function fire(i: int): void {
        const e = menu.entries[i];
        if (e === undefined || e.sep || e.enabled === false)
            return;
        menu.files.menu = null;
        if (e.run)
            e.run();
        else
            menu.files.act(e.id);
        if (menu.files.dialog === "" && menu.files.renaming === "" && !menu.files.asking)
            menu.files.focusView();
    }

    function step(d: int): void {
        if (menu.usable.length === 0)
            return;
        const at = menu.usable.indexOf(menu.lit);
        menu.lit = menu.usable[at < 0 ? (d > 0 ? 0 : menu.usable.length - 1) : (at + d + menu.usable.length) % menu.usable.length];
    }

    Keys.onUpPressed: menu.step(-1)
    Keys.onDownPressed: menu.step(1)
    Keys.onReturnPressed: menu.fire(menu.lit)
    Keys.onEnterPressed: menu.fire(menu.lit)
    Keys.onEscapePressed: {
        menu.files.menu = null;
        menu.files.focusView();
    }

    MouseArea {
        anchors.fill: parent
        enabled: menu.open
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: {
            menu.files.menu = null;
            menu.files.focusView();
        }
    }

    Item {
        id: panel
        readonly property real wantX: menu.open ? menu.at.x : 0
        readonly property real wantY: menu.open ? menu.at.y : 0
        x: Math.max(8, Math.min(panel.wantX, menu.width - panel.width - 8))
        y: Math.max(8, panel.wantY + panel.height > menu.height - 8 ? panel.wantY - panel.height : panel.wantY)
        width: 260
        height: rows.height + 12
        opacity: 0
        scale: 0.94 + 0.06 * panel.opacity
        transformOrigin: panel.wantY + panel.height > menu.height - 8 ? Item.BottomLeft : Item.TopLeft

        NumberAnimation {
            id: showAnim
            target: panel
            property: "opacity"
            from: 0
            to: 1
            duration: Tokens.enterDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }

        Glass {
            anchors.fill: parent
            radius: 14
            raised: true
            offColor: Theme.surface
            offBorder: Theme.line
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: rows
            x: 6
            y: 6
            width: parent.width - 12

            Repeater {
                model: menu.entries

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool on: menu.lit === row.index
                    readonly property bool usable: !row.modelData.sep && row.modelData.enabled !== false
                    width: rows.width
                    height: row.modelData.sep ? 9 : 32

                    Rectangle {
                        visible: row.modelData.sep === true
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Qt.alpha(Theme.text, 0.1)
                    }

                    Glass {
                        visible: !row.modelData.sep
                        anchors.fill: parent
                        radius: 9
                        inner: true
                        flowing: false
                        hot: row.on
                        lit: row.on && row.modelData.danger === true
                        litColor: Theme.danger
                        opacity: row.on ? 1 : 0
                        offColor: Theme.tintMid
                    }

                    Glyph {
                        id: mark
                        visible: !row.modelData.sep
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.check === true ? Icons.GLYPHS.check : row.modelData.check === false ? "" : (row.modelData.glyph || "")
                        size: 15
                        color: row.on && row.modelData.danger ? Theme.onAccent : row.modelData.danger ? Theme.danger : Theme.accent
                    }

                    Text {
                        visible: !row.modelData.sep
                        anchors.left: parent.left
                        anchors.leftMargin: 36
                        anchors.right: hint.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: row.modelData.label || ""
                        elide: Text.ElideRight
                        color: row.on && row.modelData.danger ? Theme.onAccent : row.modelData.danger ? Theme.danger : Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                    }

                    Text {
                        id: hint
                        visible: !row.modelData.sep
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: row.modelData.key || ""
                        color: row.on && row.modelData.danger ? Theme.onAccent : Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.tinySize
                    }

                    opacity: row.modelData.sep || row.usable ? 1 : 0.38

                    MouseArea {
                        anchors.fill: parent
                        enabled: row.usable
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: menu.lit = row.index
                        onExited: {
                            if (menu.lit === row.index)
                                menu.lit = -1;
                        }
                        onClicked: menu.fire(row.index)
                    }
                }
            }
        }
    }
}
