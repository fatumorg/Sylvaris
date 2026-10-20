import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: root

    property string glyph: ""
    property string tip: ""
    property bool lit: false
    property bool strong: false
    property bool danger: false

    signal clicked

    implicitWidth: 40
    implicitHeight: 40
    opacity: root.enabled ? 1 : 0.35
    scale: area.pressed ? 0.9 : 1
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.tip

    Behavior on scale {
        NumberAnimation {
            duration: Tokens.stateDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 13
        color: root.danger ? (area.pressed ? Qt.darker(Theme.danger, 1.2) : Theme.danger) : root.strong ? (area.pressed ? Qt.darker(Theme.accent, 1.15) : area.containsMouse ? Theme.accentHi : Theme.accent) : root.lit ? Qt.alpha(Theme.accent, area.pressed ? 0.45 : area.containsMouse ? 0.35 : 0.24) : area.pressed ? Qt.alpha(Theme.text, 0.18) : area.containsMouse || root.activeFocus ? Qt.alpha(Theme.text, 0.1) : "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.accent

        Behavior on color {
            ColorAnimation {
                duration: Tokens.stateDuration
            }
        }
    }

    Glyph {
        anchors.centerIn: parent
        text: root.glyph
        size: 20
        color: root.strong || root.danger ? Theme.onAccent : root.lit ? Theme.accent : Theme.text
    }

    Item {
        visible: area.containsMouse && root.tip !== "" && root.enabled
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 10
        width: tipText.implicitWidth + 16
        height: 26

        Glass {
            anchors.fill: parent
            radius: 8
            raised: true
            flowing: false
            offColor: Theme.surface
            offBorder: Theme.line
        }

        Text {
            id: tipText
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: root.tip
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
}
