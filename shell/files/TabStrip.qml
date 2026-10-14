import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

Item {
    id: strip

    required property var files

    ListView {
        id: list
        anchors.left: parent.left
        anchors.right: add.left
        anchors.rightMargin: 6
        height: parent.height
        orientation: ListView.Horizontal
        spacing: 6
        clip: true
        interactive: false
        model: strip.files.tabs
        currentIndex: strip.files.tab
        onCurrentIndexChanged: list.positionViewAtIndex(list.currentIndex, ListView.Contain)

        delegate: Item {
            id: tab
            required property var modelData
            required property int index
            readonly property bool on: tab.index === strip.files.tab
            width: Math.min(220, Math.max(120, (list.width - list.spacing * (strip.files.tabs.length - 1)) / strip.files.tabs.length))
            height: list.height

            Glass {
                anchors.fill: parent
                radius: height / 2
                inner: true
                flowing: false
                hot: area.containsMouse
                lit: tab.on
                offColor: area.containsMouse ? Theme.tintMid : Theme.tintSoft
            }

            Glyph {
                id: mark
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                text: tab.modelData.path === strip.files.home ? F.GLYPH.home : tab.modelData.path === strip.files.trashPath ? F.GLYPH.trash : F.GLYPH.folder
                size: 14
                color: tab.on ? Theme.onAccent : Theme.accent
            }

            Text {
                anchors.left: mark.right
                anchors.leftMargin: 8
                anchors.right: shut.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: tab.modelData.path === strip.files.home ? "Home" : tab.modelData.path === strip.files.trashPath ? "Trash" : F.nameOf(tab.modelData.path)
                elide: Text.ElideMiddle
                color: tab.on ? Theme.onAccent : Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
                font.weight: tab.on ? Font.DemiBold : Font.Normal
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton)
                        strip.files.closeTab(tab.index);
                    else
                        strip.files.selectTab(tab.index);
                }
            }

            Glyph {
                id: shut
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                opacity: tab.on || area.containsMouse || shutArea.containsMouse ? 1 : 0
                text: Icons.GLYPHS.close
                size: 12
                color: shutArea.containsMouse ? Theme.danger : tab.on ? Theme.onAccent : Theme.textDim

                MouseArea {
                    id: shutArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: strip.files.closeTab(tab.index)
                }
            }
        }
    }

    ToolButton {
        id: add
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        size: 30
        glyph: Icons.GLYPHS.plus
        tip: "New tab · " + F.keyText((strip.files.keys.byAction.newTab || [""])[0])
        onClicked: strip.files.newTab(strip.files.path)
    }
}
