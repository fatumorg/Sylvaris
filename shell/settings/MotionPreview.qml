import QtQuick
import qs
import qs.services
import qs.components

MiniScreen {
    id: root

    property real phase: 0

    showBar: false

    SequentialAnimation {
        running: root.visible
        loops: Animation.Infinite
        PauseAnimation {
            duration: Tokens.loopMs(500)
        }
        NumberAnimation {
            target: root
            property: "phase"
            from: 0
            to: 1
            duration: Math.max(1, Tokens.enterDuration)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }
        PauseAnimation {
            duration: Tokens.loopMs(1100)
        }
        NumberAnimation {
            target: root
            property: "phase"
            to: 0
            duration: Math.max(1, Tokens.exitDuration)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.exitCurve
        }
    }

    Backdrop {
        anchors.fill: parent
        reveal: root.phase
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.22 + (1 - root.phase) * (Settings.shown.motion.reduced ? 0 : -12)
        width: parent.width * 0.4
        height: parent.height * 0.5
        radius: 10
        opacity: root.phase
        scale: Settings.shown.motion.reduced ? 1 : 0.94 + 0.06 * root.phase
        color: Qt.alpha(Theme.surface, 0.95)
        border.width: 1
        border.color: Theme.line
    }
}
