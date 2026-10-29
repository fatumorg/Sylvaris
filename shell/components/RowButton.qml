import QtQuick
import qs
import qs.services

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    readonly property string kind: Tokens.buttonStyle
    readonly property bool flipped: root.kind === "solid" || body.inverted
    readonly property color ink: root.flipped ? Theme.onAccent : Theme.text
    readonly property color iconInk: root.flipped ? Theme.onAccent : Theme.accent

    signal clicked

    implicitHeight: Tokens.rowHeight
    implicitWidth: root.label === "" ? Tokens.rowHeight : row.implicitWidth + 32
    radius: Tokens.radiusRow
    scale: area.pressed ? 0.96 : 1
    transform: Translate {
        y: hover.hovered && !area.pressed && !Tokens.lite ? -1 : 0

        Behavior on y {
            NumberAnimation {
                duration: Tokens.stateDuration
            }
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Tokens.ms(area.pressed ? 120 : 260)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: area.pressed ? Tokens.enterCurve : Tokens.springCurve
        }
    }
    color: root.kind === "solid" ? (hover.hovered ? Theme.accentHi : Theme.accent) : "transparent"
    border.width: root.kind === "outline" ? Math.max(1, Tokens.borderWidth) : 0
    border.color: hover.hovered ? Theme.accent : Qt.alpha(Theme.text, 0.3)

    Behavior on color {
        ColorAnimation {
            duration: Tokens.stateDuration
        }
    }

    Glass {
        id: body
        visible: root.kind === "glass"
        anchors.fill: parent
        z: -1
        radius: root.radius
        inner: true
        hot: hover.hovered && root.kind === "glass"
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
        marked: true
        color: root.iconInk
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
            marked: true
            color: root.iconInk
        }

        Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            color: root.ink
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
            font.underline: root.kind === "text" && hover.hovered
        }
    }
}
