import QtQuick
import QtQuick.Shapes
import qs
import qs.services
import qs.components

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property bool moon: root.o.moon !== false
    readonly property real moonSide: root.moon ? Math.min(root.height * 0.55, 72) : 0

    function hhmm(t: var): string {
        return t === null || t === undefined ? "–" : Qt.formatTime(new Date(t), "hh:mm");
    }

    Text {
        textFormat: Text.PlainText
        visible: !Sky.available
        anchors.fill: parent
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: "Set a location in SylSettings › Desktop › Sky"
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    Item {
        id: arc
        visible: Sky.available
        width: parent.width - (root.moon ? root.moonSide + 16 : 0)
        height: parent.height - (root.o.times !== false ? 20 : 0)

        readonly property real h0: height * 0.72
        readonly property real peak: Math.max(20, Math.max.apply(null, Sky.sunCurve.map(s => s.altitude))) + 6

        function xOf(t: real): real {
            return (t - Sky.day) / 86400000 * width;
        }

        function yOf(a: real): real {
            return a >= 0 ? h0 - a / peak * (h0 - 8) : h0 + (-a) / 90 * (height - h0);
        }

        function points(past: bool): var {
            const out = [];
            for (const s of Sky.sunCurve) {
                if ((s.t <= Sky.now) === past)
                    out.push(Qt.point(xOf(s.t), yOf(s.altitude)));
            }
            const p = Qt.point(xOf(Sky.now), yOf(Sky.sun.altitude));
            return past ? out.concat([p]) : [p].concat(out);
        }

        Rectangle {
            y: arc.h0
            width: arc.width
            height: 1
            color: Qt.alpha(Theme.text, 0.25)
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha("#ffd08a", 0.45)
                strokeWidth: 1.5
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 4]

                PathPolyline {
                    path: arc.points(false)
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha("#ffc070", 0.9)
                strokeWidth: 2

                PathPolyline {
                    path: arc.points(true)
                }
            }
        }

        Rectangle {
            width: 14
            height: 14
            radius: width / 2
            x: arc.xOf(Sky.now) - 7
            y: arc.yOf(Sky.sun.altitude) - 7
            color: Sky.sun.altitude > 0 ? "#ffd27a" : "#ff8e4f"
            opacity: Sky.sun.altitude < 0 ? 0.5 : 1
        }
    }

    Row {
        visible: Sky.available && root.o.times !== false
        anchors.bottom: parent.bottom
        width: arc.width
        spacing: 0

        Text {
            textFormat: Text.PlainText
            width: parent.width / 2
            text: "↑ " + root.hhmm(Sky.sunTimes.rise)
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width / 2
            horizontalAlignment: Text.AlignRight
            text: "↓ " + root.hhmm(Sky.sunTimes.set)
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
        }
    }

    Column {
        visible: Sky.available && root.moon
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.moonSide
        spacing: 6

        MoonDisc {
            width: root.moonSide
            height: root.moonSide
            fraction: Sky.illumination.fraction
            phase: Sky.illumination.phase
            south: Sky.latitude < 0
            shade: Theme.base
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width + 16
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: Sky.phaseName
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
        }
    }
}
