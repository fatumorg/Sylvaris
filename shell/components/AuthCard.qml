import QtQuick
import qs
import qs.services
import "../lib/icons.mjs" as Icons

Item {
    id: root

    property string avatar: ""
    property string name: ""
    property string prompt: "Password"
    property string message: ""
    property bool error: false
    property bool busy: false
    property bool secret: true
    property real shake: 0
    property string typed: ""

    signal submitted(string text)
    signal edited(string text)

    onTypedChanged: {
        if (box.text !== root.typed)
            box.text = root.typed;
    }

    function focusInput(): void {
        box.focusInput();
    }

    function clear(): void {
        box.text = "";
    }

    function send(): void {
        if (root.busy)
            return;
        const text = box.text;
        box.text = "";
        root.submitted(text);
    }

    function fail(): void {
        box.text = "";
        shakeAnim.restart();
        box.focusInput();
    }

    implicitWidth: 340
    implicitHeight: column.implicitHeight

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation {
            target: root
            property: "shake"
            from: 0
            to: 1
            duration: Tokens.ms(420)
            easing.type: Easing.Linear
        }
        ScriptAction {
            script: root.shake = 0
        }
    }

    Column {
        id: column
        width: parent.width
        spacing: 14

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 104
            height: 104

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: root.error ? Theme.danger : Qt.alpha(Theme.accentHi, 0.7)

                Behavior on border.color {
                    ColorAnimation {
                        duration: Tokens.stateDuration
                    }
                }
            }

            RoundImage {
                id: face
                anchors.fill: parent
                anchors.margins: 6
                source: root.avatar === "" ? "" : "file://" + root.avatar
                fallbackColor: Theme.tintStrong
            }

            Glyph {
                anchors.centerIn: parent
                visible: !face.ready
                text: Icons.GLYPHS.lock
                size: 38
                color: Theme.accent
            }
        }

        Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.name !== ""
            text: root.name
            color: Theme.text
            font.family: Tokens.fontDisplay
            font.pixelSize: Tokens.titleSize + 2
            font.weight: Tokens.titleWeight
        }

        Item {
            width: parent.width
            height: 46
            x: Math.sin(root.shake * Math.PI * 6) * 14 * (1 - root.shake)

            TextBox {
                id: box
                width: parent.width - go.width - 8
                height: parent.height
                password: root.secret
                placeholder: root.prompt
                enabled: !root.busy
                onTextChanged: {
                    if (box.text !== root.typed)
                        root.edited(box.text);
                }
                onAccepted: root.send()
            }

            Rectangle {
                id: go
                anchors.right: parent.right
                width: parent.height
                height: parent.height
                radius: height / 2
                color: goArea.pressed ? Theme.accentDeep : goArea.containsMouse ? Theme.accentHi : Theme.accent
                opacity: root.busy ? 0.5 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.stateDuration
                    }
                }

                Glyph {
                    anchors.centerIn: parent
                    visible: !root.busy
                    text: Icons.GLYPHS.chevronRight
                    size: 22
                    color: Theme.onAccent
                }

                Row {
                    anchors.centerIn: parent
                    visible: root.busy
                    spacing: 4

                    Repeater {
                        model: 3

                        delegate: Rectangle {
                            required property int index
                            width: 5
                            height: 5
                            radius: 2.5
                            color: Theme.onAccent

                            SequentialAnimation on opacity {
                                running: root.busy
                                loops: Animation.Infinite
                                PauseAnimation {
                                    duration: index * 140
                                }
                                NumberAnimation {
                                    from: 0.25
                                    to: 1
                                    duration: Tokens.loopMs(300)
                                }
                                NumberAnimation {
                                    to: 0.25
                                    duration: Tokens.loopMs(300)
                                }
                                PauseAnimation {
                                    duration: (2 - index) * 140
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: goArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.send()
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            height: Math.max(implicitHeight, Tokens.smallSize + 6)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.message
            color: root.error ? Theme.danger : Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }
    }
}
