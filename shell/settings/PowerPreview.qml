import QtQuick
import qs
import qs.services
import qs.components
import "../lib/power.mjs" as P
import "../lib/icons.mjs" as Icons

MiniScreen {
    id: root

    showBar: false

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.base, 0.55)
    }

    Row {
        anchors.centerIn: parent
        spacing: 10

        Repeater {
            model: Settings.shown.power.actions

            delegate: Column {
                required property string modelData
                required property int index
                spacing: 4

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 34
                    height: 34
                    radius: Tokens.r(17)
                    color: index === 0 ? Theme.accent : Qt.alpha(Theme.surface, 0.9)
                    border.width: 1
                    border.color: Theme.line

                    Glyph {
                        anchors.centerIn: parent
                        text: P.ACTIONS[modelData] ? Icons.GLYPHS[P.ACTIONS[modelData].glyph] || "" : ""
                        size: 15
                        color: index === 0 ? Theme.onAccent : Theme.text
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: P.ACTIONS[modelData] ? P.ACTIONS[modelData].label : modelData
                    color: Theme.textSoft
                    font.family: Tokens.fontUi
                    font.pixelSize: 9
                }
            }
        }
    }
}
