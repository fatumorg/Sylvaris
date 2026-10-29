import QtQuick
import qs
import qs.services

Rectangle {
    id: root

    property var options: []
    property string current: ""
    readonly property string kind: Tokens.segmentedStyle
    readonly property bool pill: root.kind === "pill"
    readonly property int currentIndex: root.options.findIndex(o => o.key === root.current)

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
    radius: root.kind === "boxed" ? Math.min(6, Tokens.r(6)) : Tokens.r(16)
    color: "transparent"
    border.width: root.kind === "boxed" ? 1 : 0
    border.color: Qt.alpha(Theme.text, 0.22)

    Glass {
        visible: root.pill
        anchors.fill: parent
        z: -1
        radius: root.radius
        inner: true
        offColor: Theme.tintMid
    }


    Row {
        id: row
        anchors.fill: parent
        anchors.margins: root.pill ? 4 : 0
        spacing: root.pill ? 4 : 0

        Repeater {
            id: cells
            model: root.options
            delegate: Rectangle {
                id: cell
                required property var modelData
                required property int index
                readonly property bool on: modelData.key === root.current
                width: root.total >= root.room ? (root.naturals[cell.index] || 0) * root.room / Math.max(1, root.total) : (root.naturals[cell.index] || 0) + (root.room - root.total) / Math.max(1, root.options.length)
                height: row.height
                radius: root.pill ? Tokens.r(12) : 0
                color: !on || root.kind === "underline" ? "transparent" : root.pill ? Qt.alpha(Theme.accent, Resin.litAlpha) : Qt.alpha(Theme.accent, 0.12 + 0.18 * Tokens.accentStrength)

                Rectangle {
                    visible: root.kind === "boxed" && cell.index > 0
                    width: 1
                    height: parent.height
                    color: Qt.alpha(Theme.text, 0.22)
                }

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
                        color: on && root.pill ? Theme.onAccent : on || root.pill ? Theme.text : Theme.textDim

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
                        color: on && root.pill ? Theme.onAccent : on || root.pill ? Theme.text : Theme.textDim

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

    Rectangle {
        visible: root.kind === "underline"
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Qt.alpha(Theme.text, 0.14)
    }

    Rectangle {
        readonly property Item at: cells.count > 0 && root.currentIndex >= 0 ? cells.itemAt(root.currentIndex) : null
        visible: root.kind === "underline" && at !== null
        anchors.bottom: parent.bottom
        x: at !== null ? at.x : 0
        width: at !== null ? at.width : 0
        height: 2
        color: Theme.accent

        Behavior on x {
            NumberAnimation {
                duration: Tokens.moveDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.moveCurve
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Tokens.moveDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.moveCurve
            }
        }
    }
}
