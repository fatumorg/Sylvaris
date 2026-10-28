import QtQuick
import qs
import qs.services
import "../lib/bar.mjs" as B

MiniScreen {
    id: root

    readonly property string corner: B.placeCorner(Settings.shown.notifications.corner, Settings.shown.parts.bar ? Settings.shown.bar.position : "top")

    Repeater {
        model: 2

        delegate: Rectangle {
            required property int index
            readonly property var at: root.spot(root.corner, 380 * root.k, (2 * 96 + 10) * root.k)
            x: at.x
            y: at.y + (root.corner.indexOf("bottom") === 0 ? (1 - index) : index) * 106 * root.k
            width: 380 * root.k
            height: 96 * root.k
            radius: Tokens.r(6)
            opacity: Settings.shown.notifications.dnd ? 0.25 : 1
            color: Qt.alpha(Theme.surface, 0.92)
            border.width: 1
            border.color: Theme.line

            Rectangle {
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height * 0.4
                height: width
                radius: width / 2
                color: Theme.accent
            }

            Column {
                x: parent.height * 0.4 + 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Rectangle {
                    width: 60
                    height: 4
                    radius: Tokens.r(2)
                    color: Theme.text
                }

                Rectangle {
                    width: 40
                    height: 3
                    radius: 1.5
                    color: Theme.textDim
                }
            }
        }
    }
}
