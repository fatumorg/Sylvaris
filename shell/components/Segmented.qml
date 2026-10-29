import QtQuick
import qs
import qs.services

Rectangle {
    id: root

    property var options: []
    property string current: ""

    readonly property var naturals: root.options.map(o => metrics.advanceWidth(String(o.label)) + (o.icon !== undefined && o.icon !== "" ? 24 : 0) + 20)
    readonly property real room: row.width - row.spacing * (root.options.length - 1)
    readonly property real total: root.naturals.reduce((a, b) => a + b, 0)

    signal picked(string key)

    FontMetrics {
        id: metrics
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.nodeSize
        font.weight: Font.DemiBold
    }

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
                id: cell
                required property var modelData
                required property int index
                readonly property bool on: modelData.key === root.current
                width: root.total >= root.room ? (root.naturals[cell.index] || 0) * root.room / Math.max(1, root.total) : (root.naturals[cell.index] || 0) + (root.room - root.total) / Math.max(1, root.options.length)
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
                        width: Math.min(implicitWidth, cell.width - 16)
                        elide: Text.ElideRight
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
