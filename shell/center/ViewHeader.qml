import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Item {
    id: root

    property string title: ""

    signal back

    width: parent ? parent.width : 0
    height: 70

    Glyph {
        id: arrow
        x: 24
        y: 22
        text: Icons.GLYPHS.back
        size: 26
        color: Theme.accent

        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: root.back()
        }
    }

    Text {
        textFormat: Text.PlainText
        anchors.left: arrow.right
        anchors.leftMargin: 16
        anchors.verticalCenter: arrow.verticalCenter
        text: root.title
        color: Theme.text
        font.family: Tokens.fontDisplay
        font.pixelSize: Tokens.titleSize
        font.weight: Tokens.titleWeight
    }
}
