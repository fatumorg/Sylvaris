import QtQuick
import QtQuick.Shapes
import qs
import qs.services
import qs.components
import qs.plugins.temp
import "../../lib/temp.mjs" as T

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property var list: {
        const mine = (root.o.sensors || []).map(id => Temps.sensors.find(s => T.sensorId(s) === id)).filter(s => s !== undefined);
        return mine.length > 0 ? mine : Temps.shown;
    }
    readonly property bool active: root.visible && (root.frame === null || !root.frame.paused)
    readonly property string me: "widget" + root
    readonly property real size: Math.min(root.height - 22, (root.width - (root.list.length - 1) * 12) / Math.max(1, root.list.length))

    onActiveChanged: Temps.want(root.me, root.active)
    Component.onCompleted: Temps.want(root.me, root.active)
    Component.onDestruction: Temps.want(root.me, false)

    Text {
        textFormat: Text.PlainText
        visible: root.list.length === 0
        anchors.centerIn: parent
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: Temps.error !== "" ? Temps.error : "Waiting for TempInfoCLI"
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    Row {
        visible: root.o.style === "rings" || root.o.style === undefined
        anchors.centerIn: parent
        spacing: 12

        Repeater {
            model: root.list

            delegate: Column {
                id: ring

                required property var modelData

                spacing: 4

                Item {
                    width: root.size
                    height: root.size

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: Qt.alpha(Theme.text, 0.12)
                            strokeWidth: 6
                            fillColor: "transparent"

                            PathAngleArc {
                                centerX: root.size / 2
                                centerY: root.size / 2
                                radiusX: root.size / 2 - 3
                                radiusY: root.size / 2 - 3
                                startAngle: 0
                                sweepAngle: 360
                            }
                        }

                        ShapePath {
                            strokeColor: Temps.tone(ring.modelData)
                            strokeWidth: 6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathAngleArc {
                                centerX: root.size / 2
                                centerY: root.size / 2
                                radiusX: root.size / 2 - 3
                                radiusY: root.size / 2 - 3
                                startAngle: -90
                                sweepAngle: Math.max(1, T.headroom(ring.modelData) * 360)
                            }
                        }
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: Math.round(ring.modelData.value) + (ring.modelData.unit === "°C" ? "°" : "")
                        color: Theme.text
                        font.family: Tokens.fontDisplay
                        font.pixelSize: root.size * 0.28
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.size
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: T.short(ring.modelData).replace(/ \S+$/, "")
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }
            }
        }
    }

    TempRows {
        visible: root.o.style === "list" || root.o.style === "graph"
        anchors.verticalCenter: parent.verticalCenter
        sensors: root.list
        style: root.o.style === "graph" ? "graph" : "bars"
        rowWidth: root.width
    }
}
