import QtQuick
import qs
import qs.services
import "../lib/controls.mjs" as C

Rectangle {
    id: root

    property real value: 0
    property string icon: ""
    property string label: ""
    property string trailing: ""

    readonly property string kind: Tokens.sliderStyle
    readonly property bool filled: root.kind === "fill"
    property real live: 0
    property real sent: -1
    property bool holding: false
    readonly property real level: Math.max(0, Math.min(1, root.holding ? root.live : root.value))
    readonly property real trackX: root.filled ? 0 : lead.x + lead.width + 14
    readonly property real trackW: root.filled ? root.width : Math.max(24, trailingText.x - 14 - root.trackX)

    signal moved(real v)

    function send(v: real): void {
        root.live = v;
        root.holding = true;
        if (pace.running)
            return;
        root.sent = v;
        root.moved(v);
        pace.start();
    }

    function release(): void {
        pace.stop();
        if (root.holding && root.sent !== root.live)
            root.moved(root.live);
        root.holding = false;
        root.sent = -1;
    }

    Timer {
        id: pace
        interval: 40
        onTriggered: {
            if (root.sent === root.live)
                return;
            root.sent = root.live;
            root.moved(root.live);
            pace.start();
        }
    }
    signal iconClicked
    signal trailingClicked

    implicitHeight: Tokens.sliderHeight
    radius: Tokens.radiusRow
    color: "transparent"

    Glass {
        anchors.fill: parent
        z: -1
        radius: root.radius
        inner: true
        offColor: Theme.tintMid
    }


    Item {
        visible: root.filled
        width: parent.width * root.level
        height: parent.height
        clip: true

        Behavior on width {
            enabled: !drag.pressed
            NumberAnimation {
                duration: Tokens.moveDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.moveCurve
            }
        }

        Rectangle {
            width: root.width + root.radius
            height: parent.height
            radius: root.radius
            color: Theme.fill
        }
    }

    Rectangle {
        x: Math.max(4, Math.min(root.width - 8, root.width * root.level - 6))
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: root.height * (drag.pressed ? 0.62 : 0.3)
        radius: width / 2
        color: Theme.accentHi
        opacity: root.filled && drag.pressed && !Tokens.lite ? 0.9 : 0
        visible: opacity > 0

        Behavior on height {
            NumberAnimation {
                duration: Tokens.ms(220)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.springCurve
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.stateDuration
            }
        }
    }

    Item {
        visible: root.kind === "line"
        x: root.trackX
        width: root.trackW
        height: root.height

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: height / 2
            color: Qt.alpha(Theme.text, 0.16)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * root.level
            height: 4
            radius: height / 2
            color: Theme.accent
        }

        Rectangle {
            x: parent.width * root.level - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: height / 2
            antialiasing: true
            color: Theme.text
            border.width: 2
            border.color: Theme.accent
            scale: drag.pressed ? 1.15 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Tokens.stateDuration
                }
            }
        }
    }

    Row {
        id: ticks
        visible: root.kind === "ticks"
        x: root.trackX
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Repeater {
            model: C.TICKS
            delegate: Rectangle {
                required property int index
                width: Math.max(2, (root.trackW - ticks.spacing * (C.TICKS - 1)) / C.TICKS)
                height: Math.round(root.height * 0.36)
                radius: Math.min(2, Tokens.r(2))
                color: index < C.ticksLit(root.level, C.TICKS) ? Theme.accent : Qt.alpha(Theme.text, 0.14)

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.stateDuration
                    }
                }
            }
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function pick(mx: real): void {
            root.send(Math.max(0, Math.min(1, (mx - root.trackX) / root.trackW)));
        }
        onPressed: mouse => {
            if (!root.filled && mouse.x < root.trackX - 9)
                mouse.accepted = false;
            else if (root.kind === "ticks")
                root.send(C.tickValue(Math.max(0, Math.min(C.TICKS - 1, Math.floor((mouse.x - root.trackX) / root.trackW * C.TICKS))), C.TICKS));
            else
                pick(mouse.x);
        }
        onPositionChanged: mouse => {
            if (pressed)
                pick(mouse.x);
        }
        onReleased: root.release()
        onCanceled: root.release()
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }

    Row {
        id: lead
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Glyph {
            id: leadIcon
            text: root.icon
            size: 20
            color: Theme.text

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }

        Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(implicitWidth, root.filled ? trailingText.x - 12 - lead.x - leadIcon.width - lead.spacing : root.width * 0.3))
            text: root.label
            elide: Text.ElideRight
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
            font.weight: Font.DemiBold
        }
    }

    Text {
        id: trailingText
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width * 0.55)
        horizontalAlignment: Text.AlignRight
        text: root.trailing
        elide: Text.ElideRight
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize

        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: root.trailingClicked()
        }
    }
}
