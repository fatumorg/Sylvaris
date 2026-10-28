import QtQuick
import qs
import qs.services

MiniScreen {
    id: root

    readonly property var pad: Settings.shown.pad

    showBar: false

    Grid {
        anchors.centerIn: parent
        visible: root.pad.mode !== "list"
        columns: root.pad.columns
        spacing: Math.max(3, parent.width * 0.012)

        Repeater {
            model: root.pad.columns * root.pad.rows

            delegate: Rectangle {
                required property int index
                width: Math.min(parent.parent.width * 0.6 / root.pad.columns, parent.parent.height * 0.62 / root.pad.rows)
                height: width
                radius: width * 0.28
                color: Qt.alpha(index % 4 === 0 ? Theme.accent : Theme.text, index % 4 === 0 ? 0.7 : 0.18)
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        visible: root.pad.mode === "list"
        width: parent.width * 0.34
        height: parent.height * 0.7
        radius: Tokens.r(8)
        color: Qt.alpha(Theme.surface, 0.92)
        border.width: 1
        border.color: Theme.line

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 5

            Repeater {
                model: 6

                delegate: Rectangle {
                    required property int index
                    width: parent.width
                    height: 10
                    radius: Tokens.r(3)
                    color: index === 0 ? Theme.accent : Qt.alpha(Theme.text, 0.15)
                }
            }
        }
    }
}
