import QtQuick
import SylStack
import qs.services
import qs.components
import qs.files
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

FloatingWindow {
    id: win

    required property var archive
    readonly property real sideW: Math.min(260, Math.max(210, win.width * 0.22))

    title: win.archive.title
    implicitWidth: 1040
    implicitHeight: 680
    minimumSize: Qt.size(560, 380)
    color: "transparent"
    BackgroundEffect.blurRegion: Resin.enabled ? blur : null
    onClosed: {
        const archive = win.archive;
        Qt.callLater(() => archive.close());
    }

    Region {
        id: blur
        width: win.width
        height: win.height
    }

    function hint(id: string, label: string): string {
        const k = F.keyText((win.archive.keys.byAction[id] || [""])[0] || "");
        return k === "" ? label : label + " · " + k;
    }

    Glass {
        anchors.fill: parent
        raised: true
        offColor: Theme.surface
    }

    FocusScope {
        id: body
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (win.archive.dialog === "" && win.archive.asking === null && win.archive.key(F.comboOf(event.key, event.modifiers)))
                event.accepted = true;
        }

        ArchiveInfo {
            id: side
            x: 0
            width: win.sideW
            anchors.top: parent.top
            anchors.bottom: status.top
            archive: win.archive
        }

        Item {
            id: main
            anchors.left: side.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: status.top

            Item {
                id: toolbar
                y: 10
                x: 12
                width: parent.width - 24
                height: 38

                Row {
                    id: nav
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    ToolButton {
                        glyph: Icons.GLYPHS.back
                        tip: win.hint("back", "Back")
                        enabled: win.archive.current.back.length > 0
                        onClicked: win.archive.back()
                    }

                    ToolButton {
                        glyph: F.GLYPH.forward
                        tip: win.hint("forward", "Forward")
                        enabled: win.archive.current.forward.length > 0
                        onClicked: win.archive.forward()
                    }

                    ToolButton {
                        glyph: Icons.GLYPHS.up
                        tip: win.hint("up", "Parent folder")
                        enabled: win.archive.path !== win.archive.archive
                        onClicked: win.archive.up()
                    }
                }

                PathBar {
                    anchors.left: nav.right
                    anchors.leftMargin: 10
                    anchors.right: filter.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 34
                    files: win.archive
                }

                FilterField {
                    id: filter
                    anchors.right: tools.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(220, Math.max(140, toolbar.width * 0.2))
                    height: 34
                    files: win.archive
                }

                Row {
                    id: tools
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    ToolButton {
                        glyph: F.GLYPH.extract
                        tip: win.hint(win.archive.selected.length > 0 ? "extract" : "extractAll", win.archive.selected.length > 0 ? "Extract the selection" : "Extract everything")
                        enabled: win.archive.problem === ""
                        onClicked: win.archive.act(win.archive.selected.length > 0 ? "extract" : "extractAll")
                    }

                    ToolButton {
                        glyph: Icons.GLYPHS.grid
                        tip: win.hint("grid", "Grid")
                        on: win.archive.cfg.view === "grid"
                        onClicked: win.archive.act("grid")
                    }

                    ToolButton {
                        glyph: F.GLYPH.list
                        tip: win.hint("list", "List")
                        on: win.archive.cfg.view === "list"
                        onClicked: win.archive.act("list")
                    }

                    ToolButton {
                        id: more
                        glyph: F.GLYPH.more
                        tip: "View options"
                        on: win.archive.menu !== null && win.archive.menu.view === true
                        onClicked: {
                            const p = more.mapToItem(null, more.width, more.height + 6);
                            win.archive.menu = {
                                x: p.x - 260,
                                y: p.y,
                                name: "",
                                view: true
                            };
                        }
                    }
                }
            }

            Pane {
                id: pane
                anchors.top: toolbar.bottom
                anchors.topMargin: 10
                anchors.bottom: parent.bottom
                x: 6
                width: parent.width - 12
                files: win.archive
                focus: true
            }
        }

        StatusBar {
            id: status
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 30
            files: win.archive
        }

        FilesMenu {
            anchors.fill: parent
            z: 50
            files: win.archive
        }

        FilesDialog {
            anchors.fill: parent
            z: 60
            files: win.archive
        }

        AskDialog {
            anchors.fill: parent
            z: 61
            files: win.archive
        }

        ClashDialog {
            anchors.fill: parent
            z: 62
            files: win.archive
        }
    }
}
