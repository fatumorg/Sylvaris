import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F

MiniScreen {
    id: root

    readonly property var cfg: Settings.shown.files
    readonly property var names: F.arrange([["Music", true, 0, 5], ["Projects", true, 0, 9], ["notes.txt", false, 300, 4], ["photo.png", false, 900000, 7], ["song.flac", false, 4000000, 2], ["report.pdf", false, 70000, 8], ["b2.md", false, 20, 3], ["b10.md", false, 90, 6], [".config", true, 0, 1]].map(e => ({
                name: e[0],
                dir: e[1],
                size: e[2],
                modified: e[3]
            })), {
        sort: root.cfg.sort,
        descending: root.cfg.descending,
        foldersFirst: root.cfg.foldersFirst,
        hidden: root.cfg.hidden,
        query: ""
    })

    Item {
        id: win
        anchors.centerIn: parent
        width: parent.width * 0.72
        height: parent.height * 0.74

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: Qt.alpha(Theme.surface, 0.92)
            border.width: 1
            border.color: Theme.line
        }

        Rectangle {
            id: side
            x: 5
            y: 5
            width: root.cfg.sidebar ? win.width * 0.2 : 0
            height: win.height - 10
            visible: width > 0
            radius: 4
            color: Qt.alpha(Theme.text, 0.08)

            Column {
                x: 5
                y: 6
                spacing: 4

                Repeater {
                    model: 6

                    delegate: Rectangle {
                        required property int index
                        width: side.width - 10
                        height: 5
                        radius: 2
                        color: index === 1 ? Theme.accent : Qt.alpha(Theme.text, 0.18)
                    }
                }
            }
        }

        Rectangle {
            id: info
            anchors.right: parent.right
            anchors.rightMargin: 5
            y: 5
            width: root.cfg.details ? win.width * 0.2 : 0
            height: win.height - 10
            visible: width > 0
            radius: 4
            color: Qt.alpha(Theme.text, 0.08)

            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8
                text: F.GLYPH.folder
                size: info.width * 0.4
                color: Theme.accent
            }
        }

        Item {
            id: main
            anchors.left: side.right
            anchors.leftMargin: 6
            anchors.right: info.left
            anchors.rightMargin: 6
            y: 6
            height: win.height - 12
            clip: true

            Rectangle {
                width: parent.width
                height: 7
                radius: 3.5
                color: Qt.alpha(Theme.text, 0.12)
            }

            Grid {
                y: 14
                visible: root.cfg.view === "grid"
                columns: Math.max(1, Math.floor(main.width / (root.cfg.iconSize * 0.42 + 14)))
                spacing: 4

                Repeater {
                    model: root.names

                    delegate: Column {
                        required property var modelData
                        spacing: 1

                        Glyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: F.glyphOf(F.kindOf(modelData.name, modelData.dir))
                            size: root.cfg.iconSize * 0.36
                            color: modelData.dir ? Theme.accent : Qt.alpha(Theme.text, 0.7)
                            opacity: modelData.name.charAt(0) === "." ? 0.5 : 1
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.cfg.iconSize * 0.36
                            height: 3
                            radius: 1.5
                            color: Qt.alpha(Theme.text, 0.3)
                        }
                    }
                }
            }

            Column {
                y: 14
                width: parent.width
                visible: root.cfg.view === "list"
                spacing: 3

                Repeater {
                    model: root.names

                    delegate: Row {
                        required property var modelData
                        spacing: 4

                        Glyph {
                            text: F.glyphOf(F.kindOf(modelData.name, modelData.dir))
                            size: 9
                            color: modelData.dir ? Theme.accent : Qt.alpha(Theme.text, 0.7)
                        }

                        Text {
                            textFormat: Text.PlainText
                            text: modelData.name
                            color: Qt.alpha(Theme.text, modelData.name.charAt(0) === "." ? 0.4 : 0.8)
                            font.family: Tokens.fontUi
                            font.pixelSize: 8
                        }
                    }
                }
            }
        }
    }
}
