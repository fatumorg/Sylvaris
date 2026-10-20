import QtQuick
import qs
import qs.services

Rectangle {
    id: root

    property string icon: ""
    property string label: ""

    signal clicked

    implicitHeight: Tokens.rowHeight
    implicitWidth: root.label === "" ? Tokens.rowHeight : row.implicitWidth + 32
    radius: Tokens.radiusRow
    scale: area.pressed ? 0.96 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Tokens.ms(120)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }
    }
    color: "transparent"

    Glass {
        anchors.fill: parent
        z: -1
        radius: root.radius
        inner: true
        hot: hover.hovered
        offColor: hover.hovered ? Theme.tintMid : Theme.tintSoft
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        id: area
        anchors.fill: parent
        onClicked: root.clicked()
    }

    Glyph {
        anchors.centerIn: parent
        visible: root.label === ""
        text: root.icon
        size: 20
        color: Theme.accent
    }

    Row {
        id: row
        x: 16
        visible: root.label !== ""
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        Glyph {
            text: root.icon
            size: 20
            color: Theme.accent
        }

        Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
        }
    }
}
