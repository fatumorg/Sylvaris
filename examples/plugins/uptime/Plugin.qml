import QtQuick
import SylStack
import qs
import qs.services
import qs.components

Item {
    id: root

    property var api: null
    property real seconds: 0

    implicitWidth: row.implicitWidth + 20
    implicitHeight: Tokens.barItemHeight

    FileView {
        id: file
        path: "/proc/uptime"
        onLoaded: root.seconds = Number(text().split(" ")[0])
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: file.reload()
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xF051B)
            size: Tokens.barGlyph
            color: Theme.accent
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: Math.floor(root.seconds / 3600) + "h " + Math.floor(root.seconds % 3600 / 60) + "m"
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.barText
        }
    }
}
