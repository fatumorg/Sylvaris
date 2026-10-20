import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Item {
    id: root

    required property var greet
    property real reveal: 0

    Component.onCompleted: {
        revealAnim.restart();
        card.focusInput();
    }

    NumberAnimation {
        id: revealAnim
        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: Math.round(900 * Tokens.pace)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.enterCurve
    }

    Connections {
        target: root.greet
        function onFailed() {
            card.fail();
        }
        function onUserIndexChanged() {
            card.clear();
            card.focusInput();
        }
    }

    Shortcut {
        sequence: "Up"
        onActivated: root.greet.stepUser(-1)
    }

    Shortcut {
        sequence: "Down"
        onActivated: root.greet.stepUser(1)
    }

    Shortcut {
        sequence: "F2"
        onActivated: root.picking = !root.picking
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.picking
        onActivated: root.picking = false
    }

    Backdrop {
        anchors.fill: parent
        source: root.greet.wallpaper
        reveal: root.reveal
        dim: 0.45
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.14 + (1 - root.reveal) * -30)
        opacity: root.reveal
        spacing: 4

        Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(new Date(root.greet.now), "HH:mm")
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Math.min(160, root.height * 0.14)
            font.weight: Font.Light
            font.features: {
                "tnum": 1
            }
        }

        Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(root.greet.now), "dddd, d MMMM")
            color: Theme.textSoft
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.titleSize + 4
        }
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.5 + (1 - root.reveal) * 40)
        width: 480
        height: card.implicitHeight
        opacity: root.reveal

        AuthCard {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            width: 360
            avatar: root.greet.avatar
            name: root.greet.user === null ? "No users" : root.greet.user.real
            prompt: root.greet.awaiting ? root.greet.message : "Password"
            secret: !(root.greet.awaiting && root.greet.echo)
            message: root.greet.awaiting ? "" : root.greet.message
            error: root.greet.error
            busy: root.greet.busy
            typed: root.greet.typed
            onEdited: text => root.greet.typed = text
            onSubmitted: text => root.greet.submit(text)
        }

        Repeater {
            model: root.greet.users.length > 1 ? [-1, 1] : []

            delegate: Rectangle {
                required property int modelData
                x: modelData < 0 ? 0 : parent.width - width
                y: 34
                width: 40
                height: 40
                radius: 20
                color: arrowArea.containsMouse ? Theme.tintStrong : Theme.tintSoft
                border.width: 1
                border.color: Theme.cardLine

                Glyph {
                    anchors.centerIn: parent
                    text: modelData < 0 ? Icons.GLYPHS.chevronLeft : Icons.GLYPHS.chevronRight
                    size: 18
                    color: Theme.text
                }

                MouseArea {
                    id: arrowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.greet.stepUser(parent.modelData)
                }
            }
        }
    }

    property bool picking: false

    MouseArea {
        anchors.fill: parent
        enabled: root.picking
        onClicked: root.picking = false
    }

    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 32
        opacity: root.reveal
        spacing: 10
        visible: root.greet.session !== null

        Item {
            width: 300
            height: sessionList.implicitHeight + 16
            visible: root.picking
            opacity: root.picking ? 1 : 0

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusCard
                raised: true
                offColor: Theme.surface
                offBorder: Theme.line
            }

            Column {
                id: sessionList
                x: 8
                y: 8
                width: parent.width - 16
                spacing: 2

                Repeater {
                    model: root.greet.sessions

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool chosen: index === root.greet.sessionIndex
                        width: sessionList.width
                        height: 40
                        radius: 12
                        color: chosen ? Theme.accent : pickArea.containsMouse ? Theme.tintStrong : "transparent"

                        Text {
                            textFormat: Text.PlainText
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: parent.chosen ? Theme.onAccent : Theme.text
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.bodySize
                            font.weight: parent.chosen ? Font.DemiBold : Font.Normal
                        }

                        Glyph {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            visible: parent.chosen
                            text: Icons.GLYPHS.check
                            size: 16
                            color: Theme.onAccent
                        }

                        MouseArea {
                            id: pickArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.greet.pickSession(index);
                                root.picking = false;
                                card.focusInput();
                            }
                        }
                    }
                }
            }
        }

        Row {
            spacing: 10

            RowButton {
                icon: Icons.GLYPHS.apps
                label: (root.greet.session === null ? "" : root.greet.session.name) + (root.greet.sessions.length > 1 ? "  " + (root.picking ? Icons.GLYPHS.chevronDown : Icons.GLYPHS.chevronUp) : "")
                onClicked: {
                    if (root.greet.sessions.length > 1)
                        root.picking = !root.picking;
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.greet.sessions.length > 1
                text: "Session · F2 opens the list · ↑ ↓ change the user"
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 32
        opacity: root.reveal
        spacing: 10

        RowButton {
            icon: Icons.GLYPHS.restart
            label: "Restart"
            onClicked: root.greet.power("reboot")
        }

        RowButton {
            icon: Icons.GLYPHS.power
            label: "Shut down"
            onClicked: root.greet.power("poweroff")
        }
    }
}
