import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs
import qs.services

Item {
    id: root

    property bool checked: false
    readonly property string kind: Tokens.toggleStyle
    readonly property bool track: root.kind === "pill" || root.kind === "block"

    signal toggled(bool value)

    implicitWidth: root.track ? 48 : 28
    implicitHeight: 28
    clip: ripple.visible

    Rectangle {
        visible: root.track
        anchors.fill: parent
        radius: root.kind === "block" ? 2 : height / 2
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
        visible: root.track && ripple.grow > 0 && ripple.grow < 1

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
        visible: root.track
        x: root.checked ? root.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: root.height - 6
        height: width
        radius: root.kind === "block" ? 2 : width / 2
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

    Rectangle {
        id: box
        visible: root.kind === "check"
        anchors.centerIn: parent
        width: 22
        height: 22
        radius: Math.min(5, Tokens.r(5))
        antialiasing: true
        color: root.checked ? Theme.accent : "transparent"
        border.width: root.checked ? 0 : 1.5
        border.color: Qt.alpha(Theme.text, 0.45)
        scale: toggleArea.pressed ? 0.88 : 1

        Behavior on color {
            ColorAnimation {
                duration: Tokens.stateDuration
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.stateDuration
            }
        }

        Shape {
            anchors.fill: parent
            opacity: root.checked ? 1 : 0
            preferredRendererType: Shape.CurveRenderer

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.stateDuration
                }
            }

            ShapePath {
                strokeColor: Theme.onAccent
                strokeWidth: 2.4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline {
                    path: [Qt.point(5.5, 11.5), Qt.point(9.5, 15.5), Qt.point(16.5, 7)]
                }
            }
        }
    }

    RectangularShadow {
        visible: root.kind === "led" && root.checked && !Tokens.lite
        anchors.fill: led
        radius: led.radius
        blur: 10
        spread: 1
        color: Qt.alpha(Theme.accent, 0.7)
    }

    Rectangle {
        id: led
        visible: root.kind === "led"
        anchors.centerIn: parent
        width: 14
        height: 14
        radius: height / 2
        antialiasing: true
        color: root.checked ? Theme.accent : "transparent"
        border.width: root.checked ? 0 : 1.5
        border.color: Theme.line
        scale: toggleArea.pressed ? 0.8 : 1

        Behavior on color {
            ColorAnimation {
                duration: Tokens.stateDuration
            }
        }

        Behavior on scale {
            NumberAnimation {
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
