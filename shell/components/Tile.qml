import QtQuick
import qs
import qs.services

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false

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

        scale: bodyArea.pressed ? 0.97 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.ms(120)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.enterCurve
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
            x: 14
            anchors.verticalCenter: parent.verticalCenter
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
            anchors.left: iconBox.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: root.title
                elide: Text.ElideRight
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.bodySize
                font.weight: Font.DemiBold
            }

            Text {
                textFormat: Text.PlainText
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
