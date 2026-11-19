import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: root

    property string label: ""
    property bool lit: false
    property bool focused: false
    property bool repeats: false
    readonly property bool down: area.pressed

    signal hit

    opacity: root.enabled ? 1 : 0.4
    scale: area.pressed ? 0.94 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Tokens.ms(area.pressed ? 90 : 220)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: area.pressed ? Tokens.enterCurve : Tokens.springCurve
        }
    }

    Glass {
        anchors.fill: parent
        radius: Tokens.radiusRow
        inner: true
        lit: root.lit
        hot: hover.hovered || root.focused
        offColor: area.pressed ? Theme.tintMid : hover.hovered || root.focused ? Theme.tintMid : Theme.tintSoft
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: Tokens.radiusRow + 3
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        opacity: root.focused ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.stateDuration
            }
        }
    }

    Text {
        anchors.centerIn: parent
        width: parent.width - 8
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.label
        color: root.lit ? Theme.onAccent : Theme.text
        font.family: Tokens.fontUi
        font.pixelSize: root.label.length > 1 ? Tokens.bodySize : Tokens.titleSize + 4
    }

    HoverHandler {
        id: hover
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        onPressed: {
            root.hit();
            if (root.repeats)
                hold.start();
        }
        onReleased: hold.stop()
        onCanceled: hold.stop()
    }

    Timer {
        id: hold
        interval: Tokens.ms(420)
        repeat: true
        onTriggered: {
            hold.interval = 60;
            root.hit();
        }
        onRunningChanged: {
            if (!running)
                hold.interval = Tokens.ms(420);
        }
    }
}
