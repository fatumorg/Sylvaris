import QtQuick
import qs
import qs.services

Item {
    id: root

    property bool checked: false

    signal toggled(bool value)

    implicitWidth: 48
    implicitHeight: 28
    clip: ripple.visible

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        antialiasing: true
        color: root.checked ? Theme.accent : Qt.alpha(Theme.text, 0.16)
        border.width: root.checked ? 0 : 1
        border.color: Qt.alpha(Theme.text, 0.12)

        Behavior on color {
            ColorAnimation {
                duration: Tokens.stateDuration
            }
        }
    }

    Rectangle {
        id: ripple
        property real at: 0
        x: ripple.at - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.width * 1.6 * ripple.grow
        height: width
        radius: width / 2
        antialiasing: true
        property real grow: 0
        color: Qt.alpha(root.checked ? Theme.onAccent : Theme.accent, 0.35)
        opacity: 1 - ripple.grow
        visible: ripple.grow > 0 && ripple.grow < 1

        NumberAnimation on grow {
            id: spread
            running: false
            from: 0
            to: 1
            duration: Tokens.ms(420)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }
    }

    Rectangle {
        x: root.checked ? root.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: root.height - 6
        height: width
        radius: width / 2
        antialiasing: true
        color: root.checked ? Theme.onAccent : Theme.text

        scale: toggleArea.pressed ? 0.85 : 1

        Behavior on x {
            NumberAnimation {
                duration: Tokens.stateDuration + 80
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.springCurve
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.stateDuration
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Tokens.stateDuration
            }
        }
    }

    MouseArea {
        id: toggleArea
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (!Tokens.lite && Tokens.motion >= 0.05) {
                ripple.at = Math.max(0, Math.min(root.width, mouse.x - 6));
                spread.restart();
            }
            Sounds.play("toggle");
            root.toggled(!root.checked);
        }
    }
}
