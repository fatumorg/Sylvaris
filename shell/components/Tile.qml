import QtQuick
import QtQuick.Effects
import qs
import qs.services

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool small: false
    property bool split: true
    property bool more: false

    signal iconClicked
    signal bodyClicked
    signal moreClicked

    implicitHeight: Tokens.tileHeight

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radiusTile
        color: "transparent"

        Glass {
            id: body
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
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (root.more)
                        root.moreClicked();
                    return;
                }
                if (!root.split)
                    Sounds.play("toggle");
                root.bodyClicked();
            }
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

            RectangularShadow {
                visible: root.active && !Tokens.lite
                anchors.fill: plate
                radius: plate.radius
                offset.y: 3
                blur: 14
                color: Qt.alpha(Theme.accent, 0.2 + 0.3 * Tokens.accentStrength)
            }

            Rectangle {
                id: plate
                anchors.fill: parent
                radius: parent.radius
                antialiasing: true
                color: root.active ? (plateHover.hovered && root.split ? Theme.accentHi : Theme.accent) : Qt.alpha(Theme.text, plateHover.hovered && root.split ? 0.13 : 0.07)
                border.width: root.active ? 0 : 1
                border.color: Qt.alpha(Theme.text, 0.09)

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.stateDuration
                    }
                }

                Rectangle {
                    visible: root.active && !Tokens.lite
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.alpha("#ffffff", 0.22)
                        }
                        GradientStop {
                            position: 0.55
                            color: "transparent"
                        }
                    }
                }
            }

            HoverHandler {
                id: plateHover
                enabled: root.split
            }

            Glyph {
                anchors.centerIn: parent
                text: root.icon
                size: Tokens.tileIconFont
                color: root.active ? Theme.onAccent : body.inverted ? Theme.onAccent : Theme.text

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.stateDuration
                    }
                }
            }

            MouseArea {
                id: iconArea
                enabled: root.split
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Sounds.play("toggle");
                    root.iconClicked();
                }
            }
        }

        Column {
            anchors.left: root.small ? parent.left : iconBox.right
            anchors.leftMargin: root.small ? 6 : 14
            anchors.right: chevron.visible ? chevron.left : parent.right
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
                color: body.inverted ? Theme.onAccent : Theme.text
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
                color: body.inverted ? Theme.onAccent : Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }
        }

        Text {
            id: chevron
            visible: root.more && !root.split && !root.small
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "›"
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.titleSize
        }
    }
}
