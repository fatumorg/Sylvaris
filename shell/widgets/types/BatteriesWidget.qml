import QtQuick
import QtQuick.Shapes
import qs
import qs.services
import qs.components
import "../../lib/widgets.mjs" as Wd
import "../../lib/icons.mjs" as Icons

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property var devices: (Battery.present ? [
            {
                name: "Laptop",
                level: Battery.percent,
                charging: !Battery.discharging,
                kind: "battery"
            }
        ] : []).concat(Headphones.devices)
    readonly property var rings: Wd.batteryRings(root.devices, root.o)
    readonly property real size: Math.min(root.height - 22, (root.width - (root.rings.length - 1) * 12) / Math.max(1, root.rings.length))
    readonly property var glyphs: ({
            "bud-left": "headphones",
            "bud-right": "headphones",
            "case": "headphones",
            headphones: "headphones",
            mouse: "mouse",
            keyboard: "keyboard",
            laptop: "computer",
            generic: "battery"
        })

    Text {
        textFormat: Text.PlainText
        visible: root.rings.length === 0
        anchors.centerIn: parent
        text: "No batteries to show"
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    Row {
        anchors.centerIn: parent
        spacing: 12

        Repeater {
            model: root.rings

            delegate: Column {
                id: ring

                required property var modelData
                readonly property color tone: ring.modelData.level <= 15 && !ring.modelData.charging ? Theme.danger : root.frame !== null ? root.frame.accent : Theme.accent

                spacing: 4

                Item {
                    width: root.size
                    height: root.size

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: Qt.alpha(Theme.text, 0.12)
                            strokeWidth: root.o.ring || 6
                            fillColor: "transparent"

                            PathAngleArc {
                                centerX: root.size / 2
                                centerY: root.size / 2
                                radiusX: root.size / 2 - (root.o.ring || 6) / 2
                                radiusY: root.size / 2 - (root.o.ring || 6) / 2
                                startAngle: 0
                                sweepAngle: 360
                            }
                        }

                        ShapePath {
                            strokeColor: ring.tone
                            strokeWidth: root.o.ring || 6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathAngleArc {
                                centerX: root.size / 2
                                centerY: root.size / 2
                                radiusX: root.size / 2 - (root.o.ring || 6) / 2
                                radiusY: root.size / 2 - (root.o.ring || 6) / 2
                                startAngle: -90
                                sweepAngle: Math.max(1, ring.modelData.level * 3.6)
                            }
                        }
                    }

                    Glyph {
                        anchors.centerIn: parent
                        text: Icons.GLYPHS[ring.modelData.charging ? "bolt" : root.glyphs[ring.modelData.kind]] || ""
                        color: Theme.text
                        size: root.size * 0.34
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.size
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: ring.modelData.level + "%" + (root.size > 70 ? " " + ring.modelData.label : "")
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }
            }
        }
    }
}
