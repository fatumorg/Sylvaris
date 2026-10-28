import QtQuick
import qs
import qs.services

Rectangle {
    id: root

    property var options: []
    property string current: ""

    signal picked(string key)

    implicitHeight: Tokens.segmentedHeight
    radius: Tokens.r(16)
    color: "transparent"

    Glass {
        anchors.fill: parent
        z: -1
        radius: root.radius
        inner: true
        offColor: Theme.tintMid
    }


    Row {
        id: row
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        Repeater {
            model: root.options
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: modelData.key === root.current
                width: (row.width - row.spacing * (root.options.length - 1)) / Math.max(1, root.options.length)
                height: row.height
                radius: Tokens.r(12)
                color: on ? Qt.alpha(Theme.accent, Resin.litAlpha) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.stateDuration
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.icon !== undefined && modelData.icon !== ""
                        text: modelData.icon === undefined ? "" : modelData.icon
                        size: 16
                        color: on ? Theme.onAccent : Theme.text

                        Behavior on color {
                            ColorAnimation {
                                duration: Tokens.stateDuration
                            }
                        }
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: on ? Theme.onAccent : Theme.text

                        Behavior on color {
                            ColorAnimation {
                                duration: Tokens.stateDuration
                            }
                        }
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.nodeSize
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(modelData.key)
                }
            }
        }
    }
}
