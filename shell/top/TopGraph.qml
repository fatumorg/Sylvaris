import QtQuick
import QtQuick.Shapes
import qs
import qs.services
import qs.components
import "../lib/top.mjs" as T

Item {
    id: graph

    property string title: ""
    property string value: ""
    property string sub: ""
    property var first: []
    property var second: []
    property color firstTint: Theme.accent
    property color secondTint: Theme.textDim
    property real max: 100
    readonly property real peak: graph.max > 0 ? graph.max : Math.max(1, ...graph.first, ...graph.second)
    readonly property real plotH: graph.height - plot.y - 10
    readonly property real plotW: graph.width - 20

    function points(values: var): var {
        const recent = values.slice(-T.HISTORY);
        if (recent.length === 0)
            return [];
        const step = graph.plotW / (T.HISTORY - 1);
        const right = graph.plotW;
        const out = recent.map((v, i) => Qt.point(right - (recent.length - 1 - i) * step, graph.plotH - Math.max(0, Math.min(1, v / graph.peak)) * graph.plotH));
        return out.concat([Qt.point(right, graph.plotH), Qt.point(out[0].x, graph.plotH)]);
    }

    Glass {
        anchors.fill: parent
        radius: Tokens.radiusCard
        inner: true
    }

    Text {
        textFormat: Text.PlainText
        x: 12
        y: 10
        width: parent.width - 24 - valueText.implicitWidth
        text: graph.title
        elide: Text.ElideRight
        color: Theme.text
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.bodySize
        font.weight: Font.DemiBold
    }

    Text {
        id: valueText
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 10
        text: graph.value
        color: graph.firstTint
        font.family: Tokens.fontMono
        font.pixelSize: Tokens.bodySize
        font.weight: Font.DemiBold
    }

    Text {
        id: subText
        textFormat: Text.PlainText
        x: 12
        y: 32
        width: parent.width - 24
        text: graph.sub
        elide: Text.ElideRight
        color: Theme.textDim
        font.family: Tokens.fontMono
        font.pixelSize: Tokens.tinySize
    }

    Shape {
        id: plot
        x: 10
        y: 52
        width: graph.plotW
        height: graph.plotH
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: graph.second.length > 1 ? graph.secondTint : "transparent"
            strokeWidth: 1.5
            fillColor: graph.second.length > 1 ? Qt.alpha(graph.secondTint, 0.12) : "transparent"

            PathPolyline {
                path: graph.points(graph.second)
            }
        }

        ShapePath {
            strokeColor: graph.first.length > 1 ? graph.firstTint : "transparent"
            strokeWidth: 1.5
            fillColor: graph.first.length > 1 ? Qt.alpha(graph.firstTint, 0.18) : "transparent"

            PathPolyline {
                path: graph.points(graph.first)
            }
        }
    }
}
