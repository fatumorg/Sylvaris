import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

FloatingWindow {
    id: win

    required property var files
    readonly property real sideW: win.files.cfg.sidebar ? Math.min(240, Math.max(190, win.width * 0.18)) : 0
    readonly property real infoW: win.files.cfg.details ? Math.min(300, Math.max(240, win.width * 0.22)) : 0

    title: win.files.title
    implicitWidth: 1180
    implicitHeight: 740
    minimumSize: Qt.size(560, 380)
    color: "transparent"
    BackgroundEffect.blurRegion: Resin.enabled ? blur : null
    onClosed: {
        const files = win.files;
        Qt.callLater(() => files.close());
    }

    Region {
        id: blur
        width: win.width
        height: win.height
    }

    function hint(id: string, label: string): string {
        const k = F.keyText((win.files.keys.byAction[id] || [""])[0] || "");
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
            if (win.files.dialog === "" && win.files.asking === null && win.files.key(F.comboOf(event.key, event.modifiers)))
                event.accepted = true;
        }

        Sidebar {
            id: side
            x: 0
            width: win.sideW
            anchors.top: parent.top
            anchors.bottom: pickBar.top
            files: win.files
            clip: true
            visible: width > 1

            Behavior on width {
                NumberAnimation {
                    duration: Tokens.moveDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.moveCurve
                }
            }
        }

        Item {
            id: main
            anchors.left: side.right
            anchors.right: info.left
            anchors.top: parent.top
            anchors.bottom: pickBar.top

            TabStrip {
                id: tabs
                x: 12
                y: 10
                width: parent.width - 24
                height: win.files.tabs.length > 1 ? 32 : 0
                visible: height > 0
                files: win.files
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Tokens.moveDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.moveCurve
                    }
                }
            }

            Item {
                id: toolbar
                anchors.top: tabs.bottom
                anchors.topMargin: tabs.height > 0 ? 6 : 10
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
                        enabled: win.files.current.back.length > 0
                        onClicked: win.files.back()
                    }

                    ToolButton {
                        glyph: F.GLYPH.forward
                        tip: win.hint("forward", "Forward")
                        enabled: win.files.current.forward.length > 0
                        onClicked: win.files.forward()
                    }

                    ToolButton {
                        glyph: Icons.GLYPHS.up
                        tip: win.hint("up", "Parent folder")
                        enabled: win.files.path !== "/"
                        onClicked: win.files.up()
                    }
                }

                PathBar {
                    anchors.left: nav.right
                    anchors.leftMargin: 10
                    anchors.right: filter.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 34
                    files: win.files
                }

                FilterField {
                    id: filter
                    anchors.right: tools.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(220, Math.max(140, toolbar.width * 0.2))
                    height: 34
                    files: win.files
                }

                Row {
                    id: tools
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    ToolButton {
                        glyph: Icons.GLYPHS.grid
                        tip: win.hint("grid", "Grid")
                        on: win.files.cfg.view === "grid"
                        onClicked: win.files.act("grid")
                    }

                    ToolButton {
                        glyph: F.GLYPH.list
                        tip: win.hint("list", "List")
                        on: win.files.cfg.view === "list"
                        onClicked: win.files.act("list")
                    }

                    ToolButton {
                        id: more
                        glyph: F.GLYPH.more
                        tip: "View options"
                        on: win.files.menu !== null && win.files.menu.view === true
                        onClicked: {
                            const p = more.mapToItem(null, more.width, more.height + 6);
                            win.files.menu = {
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
                files: win.files
                focus: true
            }
        }

        Details {
            id: info
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: pickBar.top
            width: win.infoW
            files: win.files
            clip: true
            visible: width > 1

            Behavior on width {
                NumberAnimation {
                    duration: Tokens.moveDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.moveCurve
                }
            }
        }

        PickBar {
            id: pickBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: status.top
            height: win.files.chooser !== null ? implicitHeight : 0
            visible: height > 0
            files: win.files
        }

        StatusBar {
            id: status
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 30
            files: win.files
        }

        FilesMenu {
            anchors.fill: parent
            z: 50
            files: win.files
        }

        FilesDialog {
            anchors.fill: parent
            z: 60
            files: win.files
        }

        AskDialog {
            anchors.fill: parent
            z: 61
            files: win.files
        }

        ClashDialog {
            anchors.fill: parent
            z: 62
            files: win.files
        }
    }
}
