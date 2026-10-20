import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: root

    property string label: ""
    property string glyph: ""
    property bool danger: false
    property bool primary: false

    signal clicked

    implicitWidth: row.implicitWidth + 28
    implicitHeight: 32
    activeFocusOnTab: root.enabled
    opacity: root.enabled ? 1 : 0.35
    scale: area.pressed ? 0.95 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Tokens.stateDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }
    }

    Keys.onSpacePressed: root.clicked()
    Keys.onReturnPressed: root.clicked()

    Glass {
        anchors.fill: parent
        radius: height / 2
        inner: true
        flowing: false
        hot: area.containsMouse
        lit: root.primary || root.danger && area.containsMouse
        litColor: root.danger ? Theme.danger : Theme.accent
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

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Glyph {
            visible: root.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            size: 15
            color: root.primary ? Theme.onAccent : root.danger ? (area.containsMouse ? Theme.onAccent : Theme.danger) : Theme.accent
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.label
            color: root.primary || root.danger && area.containsMouse ? Theme.onAccent : root.danger ? Theme.danger : Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
