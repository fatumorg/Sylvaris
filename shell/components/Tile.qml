import QtQuick
import qs
import qs.services

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool small: false

    signal iconClicked
    signal bodyClicked

    implicitHeight: Tokens.tileHeight

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radiusTile
        color: "transparent"

        Glass {
            anchors.fill: parent
            z: -1
            radius: parent.radius
            inner: true
            hot: hover.hovered
            offColor: hover.hovered ? Theme.tintMid : Theme.tint
            offBorder: Theme.cardLine
        }

        scale: bodyArea.pressed ? 0.96 : 1
        transform: Translate {
            y: hover.hovered && !bodyArea.pressed && !Tokens.lite ? -1 : 0

            Behavior on y {
                NumberAnimation {
                    duration: Tokens.stateDuration
                }
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.ms(bodyArea.pressed ? 120 : 260)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: bodyArea.pressed ? Tokens.enterCurve : Tokens.springCurve
            }
        }

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            id: bodyArea
            anchors.fill: parent
            onClicked: root.bodyClicked()
        }

        Rectangle {
            id: iconBox
            x: root.small ? (parent.width - width) / 2 : 14
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.small ? -Tokens.smallSize * 0.6 : 0
            width: Tokens.tileIcon
            height: Tokens.tileIcon
            radius: Tokens.tileIconRadius
            scale: iconArea.pressed ? 0.88 : 1

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
                radius: parent.radius
                inner: true
                lit: root.active
                offColor: Theme.tintStrong
            }

            Glyph {
                anchors.centerIn: parent
                text: root.icon
                size: Tokens.tileIconFont
                color: root.active ? Theme.onAccent : Theme.text

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.stateDuration
                    }
                }
            }

            MouseArea {
                id: iconArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }

        Column {
            anchors.left: root.small ? parent.left : iconBox.right
            anchors.leftMargin: root.small ? 6 : 14
            anchors.right: parent.right
            anchors.rightMargin: root.small ? 6 : 10
            anchors.verticalCenter: root.small ? undefined : parent.verticalCenter
            anchors.top: root.small ? iconBox.bottom : undefined
            anchors.topMargin: 4

            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: root.title
                elide: Text.ElideRight
                horizontalAlignment: root.small ? Text.AlignHCenter : Text.AlignLeft
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: root.small ? Tokens.smallSize : Tokens.bodySize
                font.weight: Font.DemiBold
            }

            Text {
                textFormat: Text.PlainText
                visible: !root.small
                width: parent.width
                text: root.subtitle
                elide: Text.ElideRight
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }
        }
    }
}
