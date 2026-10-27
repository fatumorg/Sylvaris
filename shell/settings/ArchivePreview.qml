import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F

MiniScreen {
    id: root

    readonly property var cfg: Settings.shown.archive
    readonly property var shared: Settings.shown.files
    readonly property string name: "photos." + root.cfg.format
    readonly property var names: F.arrange([["2024", true, 0, 5], ["raw", true, 0, 9], ["beach.jpg", false, 900000, 4], ["notes.txt", false, 300, 7], ["trip.mp4", false, 40000000, 2], ["map.pdf", false, 70000, 8]].map(e => ({
                name: e[0],
                dir: e[1],
                size: e[2],
                modified: e[3]
            })), {
        sort: root.shared.sort,
        descending: root.shared.descending,
        foldersFirst: root.shared.foldersFirst,
        hidden: true,
        query: ""
    })

    Item {
        id: win
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -8
        width: parent.width * 0.72
        height: parent.height * 0.66

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
            width: win.width * 0.24
            height: win.height - 10
            radius: 4
            color: Qt.alpha(Theme.text, 0.08)

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8
                spacing: 4

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: F.GLYPH.archive
                    size: side.width * 0.36
                    color: Theme.accent
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: root.name
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: 8
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: side.width - 14
                    height: 8
                    radius: 4
                    color: Theme.accent
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: side.width - 14
                    height: 8
                    radius: 4
                    color: Qt.alpha(Theme.text, 0.16)
                }
            }
        }

        Item {
            id: main
            anchors.left: side.right
            anchors.leftMargin: 6
            anchors.right: parent.right
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
                columns: Math.max(1, Math.floor(main.width / (root.shared.iconSize * 0.42 + 14)))
                spacing: 4

                Repeater {
                    model: root.names

                    delegate: Column {
                        required property var modelData
                        spacing: 1

                        Glyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: F.glyphOf(F.kindOf(modelData.name, modelData.dir))
                            size: root.shared.iconSize * 0.36
                            color: modelData.dir ? Theme.accent : Qt.alpha(Theme.text, 0.7)
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.shared.iconSize * 0.36
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

                    delegate: Item {
                        required property var modelData
                        width: parent.width
                        height: 11

                        Glyph {
                            id: kind
                            anchors.verticalCenter: parent.verticalCenter
                            text: F.glyphOf(F.kindOf(modelData.name, modelData.dir))
                            size: 9
                            color: modelData.dir ? Theme.accent : Qt.alpha(Theme.text, 0.7)
                        }

                        Text {
                            anchors.left: kind.right
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            textFormat: Text.PlainText
                            text: modelData.name
                            color: Qt.alpha(Theme.text, 0.8)
                            font.family: Tokens.fontUi
                            font.pixelSize: 8
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            textFormat: Text.PlainText
                            text: modelData.dir ? "" : F.sizeText(modelData.size)
                            color: Qt.alpha(Theme.text, 0.5)
                            font.family: Tokens.fontUi
                            font.pixelSize: 7
                        }
                    }
                }
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: win.bottom
        anchors.topMargin: 6
        spacing: 6

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: F.GLYPH.extract
            size: 10
            color: Theme.accent
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.cfg.extract === "smart" ? "Extract here: loose files go into photos/, a single folder stays as it is" : "Extract here: always into a new photos/ folder"
            color: Theme.textSoft
            font.family: Tokens.fontUi
            font.pixelSize: 9
        }
    }
}
