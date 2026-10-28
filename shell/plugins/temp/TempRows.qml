import QtQuick
import qs
import qs.services
import "../../lib/temp.mjs" as T

Column {
    id: root

    property var sensors: []
    property string style: "card"
    property real rowWidth: 200

    spacing: 6

    Text {
        textFormat: Text.PlainText
        visible: root.style === "compact"
        text: root.sensors.length === 0 ? "No readings yet" : root.sensors.map(T.short).join(" · ")
        color: Theme.text
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.bodySize
        font.weight: Font.DemiBold
    }

    Repeater {
        model: root.style === "compact" ? [] : root.sensors

        delegate: Column {
            id: row

            required property var modelData
            readonly property var trail: Temps.history[T.sensorId(row.modelData)] || []

            width: root.rowWidth
            spacing: 3

            Item {
                width: parent.width
                height: value.implicitHeight

                Text {
                    textFormat: Text.PlainText
                    width: parent.width - value.implicitWidth - 8
                    text: row.modelData.kind === "cpu" ? "CPU" : row.modelData.kind === "gpu" ? "GPU" : row.modelData.kind === "storage" ? "Drive" : row.modelData.label
                    elide: Text.ElideRight
                    color: Theme.textSoft
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }

                Text {
                    id: value
                    textFormat: Text.PlainText
                    anchors.right: parent.right
                    text: T.short(row.modelData).replace(/^\S+ /, "")
                    color: Temps.tone(row.modelData)
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                visible: root.style === "bars" && T.level(row.modelData) !== "none"
                width: parent.width
                height: 4
                radius: height / 2
                color: Qt.alpha(Theme.text, 0.1)

                Rectangle {
                    width: parent.width * T.headroom(row.modelData)
                    height: parent.height
                    radius: height / 2
                    color: Temps.tone(row.modelData)
                }
            }

            Canvas {
                id: spark
                visible: root.style === "graph"
                width: parent.width
                height: 22
                onPaint: {
                    const ctx = getContext("2d");
                    const t = row.trail;
                    ctx.reset();
                    if (t.length < 2)
                        return;
                    const lo = Math.min.apply(null, t) - 1;
                    const hi = Math.max.apply(null, t) + 1;
                    ctx.strokeStyle = Temps.tone(row.modelData);
                    ctx.lineWidth = 1.5;
                    ctx.beginPath();
                    for (let i = 0; i < t.length; i++) {
                        const x = i / (t.length - 1) * width;
                        const y = height - (t[i] - lo) / (hi - lo) * height;
                        if (i === 0)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }
                    ctx.stroke();
                }

                Connections {
                    target: row
                    function onTrailChanged(): void {
                        if (spark.visible)
                            spark.requestPaint();
                    }
                }
            }
        }
    }
}
