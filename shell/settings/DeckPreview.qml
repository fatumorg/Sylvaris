import QtQuick
import qs
import qs.services

MiniScreen {
    id: root

    readonly property var deck: Settings.shown.deck
    readonly property int count: Math.max(3, root.deck.pinned.length + 2)
    readonly property real cell: root.deck.size * root.k * 1.6
    readonly property bool hidden: root.deck.hide !== "never"

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height - 8
        visible: root.deck.enabled && !root.hidden
        width: row.width + 10
        height: root.cell + 10
        radius: Math.min(12, height / 2)
        color: Qt.alpha(Theme.surface, 0.9)
        border.width: 1
        border.color: Theme.line

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: root.count

                delegate: Rectangle {
                    required property int index
                    width: root.cell
                    height: root.cell
                    radius: width * 0.28
                    color: index === 0 ? Theme.tintStrong : Qt.alpha(Theme.accent, 0.35 + 0.1 * (index % 3))
                }
            }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        visible: root.deck.enabled && root.hidden && root.deck.peek
        width: 60
        height: Math.max(2, root.deck.peekSize * 0.6)
        radius: height / 2
        color: Theme.accent
    }

    Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        visible: root.deck.enabled && root.hidden
        text: root.deck.hide === "windows" ? "Hidden while windows are open" : "Hidden until the pointer reaches the edge"
        color: Theme.text
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.tinySize
    }
}
