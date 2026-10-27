import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../../lib/diver.mjs" as D
import "../../lib/plan.mjs" as P
import "../../lib/icons.mjs" as Icons

Item {
    id: root

    required property var task
    property string when: ""
    property string path: ""
    property bool showPath: false
    readonly property var rule: D.ruleOf(JSON.parse(JSON.stringify(root.task)))
    readonly property string meta: [root.when, root.rule ? "↻ " + P.ruleText(root.rule) : "", root.task.alarm ? "alarm" : "", P.chipsOf(root.task), root.showPath ? root.path : ""].filter(Boolean).join("  ·  ")

    signal open
    signal focusRequested

    implicitHeight: root.meta === "" ? 44 : 56
    opacity: root.task.done ? 0.55 : 1

    Glass {
        anchors.fill: parent
        radius: Tokens.radiusRow
        inner: true
        hot: rowArea.containsMouse
        offBorder: rowArea.activeFocus ? Theme.accent : "transparent"
    }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        onClicked: root.open()
        Keys.onReturnPressed: root.open()
        Keys.onSpacePressed: Diver.setDone(root.task.id, !root.task.done)
    }

    Glyph {
        id: box
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.task.done ? Icons.GLYPHS.boxChecked : Icons.GLYPHS.boxEmpty
        size: 20
        color: boxArea.containsMouse ? Theme.accentHi : root.task.alarm ? Theme.danger : Theme.accent
        scale: boxArea.pressed ? 0.85 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.stateDuration
            }
        }

        MouseArea {
            id: boxArea
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Diver.setDone(root.task.id, !root.task.done)
        }
    }

    Column {
        anchors.left: box.right
        anchors.leftMargin: 12
        anchors.right: actions.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            textFormat: Text.PlainText
            width: parent.width
            text: D.plain(root.task.text)
            elide: Text.ElideRight
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
            font.strikeout: root.task.done
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: root.meta !== ""
            text: root.meta
            elide: Text.ElideRight
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        opacity: rowArea.containsMouse || focusArea.containsMouse || copyArea.containsMouse ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.stateDuration
            }
        }

        Glyph {
            text: Icons.GLYPHS.copy
            size: 16
            color: copyArea.containsMouse ? Theme.accent : Theme.textDim
            scale: copyArea.pressed ? 0.85 : 1

            MouseArea {
                id: copyArea
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Stack.execDetached(["wl-copy", "--", root.task.text])
            }
        }

        Glyph {
            text: Icons.GLYPHS.target
            size: 16
            color: focusArea.containsMouse ? Theme.accent : Theme.textDim

            MouseArea {
                id: focusArea
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.focusRequested()
            }
        }
    }
}
