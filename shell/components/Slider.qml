import QtQuick
import qs
import qs.services

Rectangle {
    id: root

    property real value: 0
    property string icon: ""
    property string label: ""
    property string trailing: ""

    signal moved(real v)
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
        width: parent.width * Math.max(0, Math.min(1, root.value))
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

    MouseArea {
        id: drag
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function pick(mx: real): void {
            root.moved(Math.max(0, Math.min(1, mx / width)));
        }
        onPressed: mouse => pick(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                pick(mouse.x);
        }
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
            width: Math.max(0, Math.min(implicitWidth, trailingText.x - 12 - lead.x - leadIcon.width - lead.spacing))
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
