import QtQuick
import qs
import qs.services
import qs.components
import "../lib/look.mjs" as L
import "../lib/icons.mjs" as Icons

Flow {
    id: root

    signal edit(string id)
    signal entered(string id)
    signal exited(string id)

    function freeName(): string {
        let name = "My style";
        for (let n = 2; Look.userLooks[L.slugLook(name)] !== undefined; n++)
            name = "My style " + n;
        return name;
    }

    width: parent.width
    spacing: 14

    Repeater {
        model: Look.list()

        delegate: Column {
            id: card

            required property string modelData
            readonly property var resolved: L.resolveLook({
                preset: card.modelData
            }, {}, Look.userLooks)
            readonly property string origin: Look.origin(card.modelData)
            readonly property bool picked: Look.values.preset === card.modelData

            width: 196
            spacing: 6

            Item {
                width: parent.width
                height: 150
                scale: tileArea.pressed ? 0.96 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Tokens.stateDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.springCurve
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.r(16)
                    color: Theme.base
                    border.width: card.picked || tileArea.containsMouse ? 2 : 1
                    border.color: card.picked ? Theme.accent : tileArea.containsMouse ? Qt.alpha(Theme.accent, 0.5) : Theme.cardLine
                }

                MiniScreen {
                    x: 10
                    y: 10
                    width: parent.width - 20
                    height: 92
                    showBar: false
                    dim: false

                    Glass {
                        anchors.centerIn: parent
                        width: parent.width * 0.7
                        height: parent.height * 0.62
                        radius: 12 * card.resolved.radius
                        preview: card.resolved.glass

                        Row {
                            anchors.centerIn: parent
                            spacing: 10

                            Item {
                                readonly property string kind: card.resolved.controls.toggle
                                anchors.verticalCenter: parent.verticalCenter
                                width: kind === "pill" || kind === "block" ? 24 : 12
                                height: 12

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.kind === "led" ? 9 : parent.width
                                    height: parent.kind === "led" ? 9 : parent.height
                                    radius: parent.kind === "pill" || parent.kind === "led" ? height / 2 : 2
                                    color: Theme.accent
                                }

                                Rectangle {
                                    visible: parent.kind === "pill" || parent.kind === "block"
                                    x: parent.width - width - 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 8
                                    height: 8
                                    radius: parent.kind === "pill" ? height / 2 : 1
                                    color: Theme.onAccent
                                }
                            }

                            Item {
                                readonly property string kind: card.resolved.controls.slider
                                anchors.verticalCenter: parent.verticalCenter
                                width: 56
                                height: 10

                                Rectangle {
                                    visible: parent.kind === "fill"
                                    width: parent.width
                                    height: parent.height
                                    radius: Math.min(height / 2, 3 * card.resolved.radius)
                                    color: Qt.alpha(Theme.text, 0.16)

                                    Rectangle {
                                        width: parent.width * 0.6
                                        height: parent.height
                                        radius: parent.radius
                                        color: Theme.accent
                                    }
                                }

                                Rectangle {
                                    visible: parent.kind === "line"
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 2
                                    color: Qt.alpha(Theme.text, 0.25)

                                    Rectangle {
                                        width: parent.width * 0.6
                                        height: parent.height
                                        color: Theme.accent
                                    }

                                    Rectangle {
                                        x: parent.width * 0.6 - width / 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 9
                                        height: 9
                                        radius: height / 2
                                        color: Theme.text
                                    }
                                }

                                Row {
                                    visible: parent.kind === "ticks"
                                    spacing: 2

                                    Repeater {
                                        model: 8

                                        delegate: Rectangle {
                                            required property int index
                                            width: 5
                                            height: 10
                                            color: index < 5 ? Theme.accent : Qt.alpha(Theme.text, 0.16)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    x: 12
                    y: 108
                    width: parent.width - 24
                    elide: Text.ElideRight
                    text: card.resolved.name
                    color: Theme.text
                    font.family: L.pickFont(card.resolved.fonts.display, Look.families, Tokens.fontDisplay)
                    font.pixelSize: Tokens.smallSize
                    font.weight: Font.DemiBold
                }

                Caption {
                    x: 12
                    y: 127
                    width: parent.width - 24
                    text: ({
                            "built-in": "Built-in",
                            "edited": "Edited",
                            "yours": "Yours"
                        })[card.origin] + " · " + card.resolved.controls.toggle + " · " + card.resolved.controls.slider
                }

                MouseArea {
                    id: tileArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.entered(card.modelData)
                    onExited: root.exited(card.modelData)
                    onClicked: Look.set(card.modelData)
                }
            }

            Flow {
                width: parent.width
                spacing: 6

                Chip {
                    text: "Edit"
                    glyph: Icons.GLYPHS.pencil
                    onClicked: {
                        Look.set(card.modelData);
                        root.edit(card.modelData);
                    }
                }

                Chip {
                    visible: card.origin === "yours"
                    text: "Duplicate"
                    onClicked: Look.duplicate(card.modelData)
                }

                Chip {
                    visible: card.origin === "yours"
                    text: "Delete"
                    onClicked: Look.remove(card.modelData)
                }

                Chip {
                    visible: card.origin === "edited"
                    text: "Reset to original"
                    onClicked: Look.reset(card.modelData)
                }
            }
        }
    }

    Item {
        width: 196
        height: 150
        scale: newArea.pressed ? 0.96 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.stateDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.springCurve
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Tokens.r(16)
            color: "transparent"
            border.width: newArea.containsMouse ? 2 : 1
            border.color: newArea.containsMouse ? Theme.accent : Theme.cardLine
        }

        Column {
            anchors.centerIn: parent
            spacing: 8

            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Icons.GLYPHS.plus
                size: 26
                color: Theme.accent
            }

            Text {
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                text: "New style"
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: newArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const id = Look.create(root.freeName(), Look.values.preset);
                Look.set(id);
                root.edit(id);
            }
        }
    }
}
