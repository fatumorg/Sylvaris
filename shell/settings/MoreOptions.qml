import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons
import "../lib/settingsIndex.mjs" as X

Item {
    id: root

    property string tab: ""
    readonly property int hidden: X.INDEX.filter(e => e.tab === root.tab && e.advanced).length

    width: parent ? parent.width : 0
    implicitHeight: root.visible ? 52 : 0
    visible: root.hidden > 0 && Settings.values.settings.detail === "simple"

    Row {
        anchors.centerIn: parent
        spacing: 10

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Settings.more ? Icons.GLYPHS.chevronUp : Icons.GLYPHS.chevronDown
            size: 16
            color: area.containsMouse ? Theme.accentHi : Theme.textDim
        }

        Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: Settings.more ? "Fewer options" : root.hidden === 1 ? "1 more option" : root.hidden + " more options"
            color: area.containsMouse ? Theme.text : Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Settings.more = !Settings.more
    }
}
