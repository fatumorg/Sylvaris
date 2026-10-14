import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: root

    property string glyph: ""
    property string tip: ""
    property bool on: false
    property real size: 34

    signal clicked

    implicitWidth: root.size
    implicitHeight: root.size
    activeFocusOnTab: root.enabled
    opacity: root.enabled ? 1 : 0.32
    scale: area.pressed ? 0.9 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Tokens.stateDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Tokens.stateDuration
        }
    }

    Keys.onSpacePressed: root.clicked()
    Keys.onReturnPressed: root.clicked()

    Glass {
        anchors.fill: parent
        radius: height / 2
        inner: true
        hot: area.containsMouse
        lit: root.on
        offColor: area.containsMouse ? Theme.tintMid : Theme.tintSoft
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        visible: root.activeFocus
    }

    Glyph {
        anchors.centerIn: parent
        text: root.glyph
        size: Math.round(root.size * 0.5)
        color: root.on ? Theme.onAccent : Theme.text
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.clicked()
    }

    Timer {
        id: tipDelay
        interval: 650
        running: area.containsMouse && !area.pressed && root.tip !== ""
    }

    Item {
        z: 100
        visible: opacity > 0
        opacity: tipDelay.running || !area.containsMouse || root.tip === "" ? 0 : 1
        anchors.top: parent.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: tipText.implicitWidth + 20
        height: tipText.implicitHeight + 10

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.fadeDuration
            }
        }

        Glass {
            anchors.fill: parent
            radius: height / 2
            raised: true
            flowing: false
            offColor: Theme.surface
            offBorder: Theme.line
        }

        Text {
            id: tipText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.tip
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
        }
    }
}
