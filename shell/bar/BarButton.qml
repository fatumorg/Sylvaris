import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: root

    property string glyph: ""
    property string label: ""
    property color tint: Theme.text
    property bool lit: false
    property int badge: 0
    property bool mono: false
    property bool compact: false
    default property alias extra: row.data
    readonly property bool hovered: area.containsMouse

    signal clicked(var mouse)
    signal wheel(int steps)

    implicitWidth: root.compact ? Tokens.barItemHeight : row.implicitWidth + 20
    implicitHeight: Tokens.barItemHeight
    width: Math.max(implicitWidth, implicitHeight)
    height: implicitHeight
    scale: area.pressed ? 0.9 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Tokens.stateDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.springCurve
        }
    }

    Glass {
        anchors.fill: parent
        radius: height / 2
        inner: true
        lit: root.lit
        opacity: root.lit || root.hovered ? 1 : 0
        offBorder: "transparent"

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.stateDuration
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Glyph {
            visible: root.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            size: Tokens.barGlyph
            color: root.lit ? Theme.onAccent : root.tint

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.stateDuration
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            visible: root.label !== "" && !root.compact
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.lit ? Theme.onAccent : Theme.text
            font.family: root.mono ? Tokens.fontMono : Tokens.fontUi
            font.pixelSize: Tokens.barText
            font.weight: Font.Medium
        }
    }

    Rectangle {
        visible: scale > 0
        scale: root.badge > 0 ? 1 : 0
        x: parent.width - width + 2
        y: -1
        width: Math.max(16, badgeText.implicitWidth + 8)
        height: 16
        radius: Tokens.r(8)
        color: Theme.accent
        border.width: 2
        border.color: Qt.alpha(Theme.base, 0.6)

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.enterDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.springCurve
            }
        }

        Text {
            textFormat: Text.PlainText
            id: badgeText
            anchors.centerIn: parent
            text: root.badge > 99 ? "99+" : root.badge
            color: Theme.onAccent
            font.family: Tokens.fontUi
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => root.clicked(mouse)
        onWheel: event => {
            const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
            if (d !== 0)
                root.wheel(d > 0 ? 1 : -1);
        }
    }
}
