import QtQuick
import QtQuick.Shapes
import qs
import qs.services
import "../lib/widgets.mjs" as Wd

Item {
    id: root

    property string face: "digital"
    property bool hours24: true
    property bool seconds: false
    property string dateFormat: "dddd d MMMM"
    property string align: "center"
    property string family: ""
    property color color: Theme.text
    property color accent: Theme.accent
    property bool paused: false
    property date now: new Date()
    readonly property string fontName: root.family !== "" ? root.family : Tokens.fontDisplay
    readonly property int hour: root.hours24 ? root.now.getHours() : (root.now.getHours() + 11) % 12 + 1
    readonly property string hh: root.hours24 ? String(root.hour).padStart(2, "0") : String(root.hour)
    readonly property string mm: String(root.now.getMinutes()).padStart(2, "0")
    readonly property string ss: String(root.now.getSeconds()).padStart(2, "0")
    readonly property string time: root.hh + ":" + root.mm + (root.seconds ? ":" + root.ss : "")
    readonly property string date: root.dateFormat === "" ? "" : Qt.formatDate(root.now, root.dateFormat)
    readonly property int hAlign: root.align === "left" ? Text.AlignLeft : root.align === "right" ? Text.AlignRight : Text.AlignHCenter
    readonly property var lit: Wd.wordClock(root.now.getHours(), root.now.getMinutes())
    readonly property var words: [[["IT", "x"], ["IS", "x"], ["HALF", "m"], ["TEN", "m"]], [["QUARTER", "m"], ["TWENTY", "m"]], [["FIVE", "m"], ["TO", "m"], ["PAST", "m"]], [["ONE", "h"], ["TWO", "h"], ["THREE", "h"], ["FOUR", "h"]], [["FIVE", "h"], ["SIX", "h"], ["SEVEN", "h"], ["EIGHT", "h"]], [["NINE", "h"], ["TEN", "h"], ["ELEVEN", "h"]], [["TWELVE", "h"], ["OCLOCK", "x"]]]

    function on(word: string, kind: string): bool {
        const l = root.lit;
        const last = l[l.length - 1] === "OCLOCK" ? l.length - 2 : l.length - 1;
        if (kind === "h")
            return l[last] === word;
        if (kind === "m")
            return l.slice(2, last).indexOf(word) >= 0;
        return l.indexOf(word) >= 0;
    }

    Timer {
        interval: root.seconds || root.face === "analog" || root.face === "orbit" ? 1000 : 5000
        running: root.visible && !root.paused
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Column {
        visible: root.face === "digital" || root.face === "flip"
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: 4

        Digits {
            visible: root.face === "digital"
            anchors.horizontalCenter: root.align === "center" ? parent.horizontalCenter : undefined
            anchors.right: root.align === "right" ? parent.right : undefined
            text: root.time
            color: root.color
            font.family: root.fontName
            font.pixelSize: Math.max(18, Math.min(root.height * 0.55, root.width / (root.time.length * 0.62)))
            font.weight: Font.DemiBold
        }

        Row {
            visible: root.face === "flip"
            anchors.horizontalCenter: root.align === "center" ? parent.horizontalCenter : undefined
            anchors.right: root.align === "right" ? parent.right : undefined
            spacing: 8

            Repeater {
                model: root.seconds ? [root.hh, root.mm, root.ss] : [root.hh, root.mm]

                delegate: Rectangle {
                    id: card

                    required property string modelData

                    width: flipText.implicitWidth + 20
                    height: flipText.implicitHeight + 8
                    radius: Tokens.radiusRow
                    color: Qt.alpha(Theme.base, 0.55)

                    Rectangle {
                        width: parent.width
                        height: 1
                        y: parent.height / 2
                        color: Qt.alpha(Theme.base, 0.8)
                    }

                    Digits {
                        id: flipText
                        anchors.centerIn: parent
                        text: card.modelData
                        color: root.color
                        font.family: root.fontName
                        font.pixelSize: Math.max(18, Math.min(root.height * 0.45, root.width / (root.seconds ? 5.4 : 3.8)))
                        font.weight: Font.Bold
                    }
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            visible: root.date !== "" && root.height > 90
            width: parent.width
            horizontalAlignment: root.hAlign
            elide: Text.ElideRight
            text: root.date
            color: Qt.alpha(root.color, 0.7)
            font.family: Tokens.fontUi
            font.pixelSize: Math.max(Tokens.smallSize, Math.min(22, root.height * 0.12))
        }
    }

    Column {
        visible: root.face === "giant"
        anchors.centerIn: parent
        spacing: -root.height * 0.08

        Repeater {
            model: [root.hh, root.mm]

            delegate: Text {
                required property string modelData
                required property int index
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData
                color: index === 0 ? root.color : root.accent
                font.family: root.fontName
                font.pixelSize: root.height * 0.5
                font.weight: Font.Black
            }
        }
    }

    Canvas {
        id: dial
        visible: root.face === "analog"
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        onVisibleChanged: dial.requestPaint()
        onWidthChanged: dial.requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            const r = width / 2;
            const t = root.now;
            ctx.reset();
            ctx.translate(r, r);
            ctx.strokeStyle = root.color;
            ctx.globalAlpha = 0.5;
            for (let i = 0; i < 12; i++) {
                const a = i * Math.PI / 6;
                ctx.lineWidth = i % 3 === 0 ? 3 : 1.5;
                ctx.beginPath();
                ctx.moveTo(Math.sin(a) * r * 0.82, -Math.cos(a) * r * 0.82);
                ctx.lineTo(Math.sin(a) * r * 0.94, -Math.cos(a) * r * 0.94);
                ctx.stroke();
            }
            ctx.globalAlpha = 1;
            ctx.lineCap = "round";
            const hand = (turn, len, w, colour) => {
                ctx.strokeStyle = colour;
                ctx.lineWidth = w;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(Math.sin(turn * 2 * Math.PI) * r * len, -Math.cos(turn * 2 * Math.PI) * r * len);
                ctx.stroke();
            };
            hand((t.getHours() % 12 + t.getMinutes() / 60) / 12, 0.5, 5, root.color);
            hand((t.getMinutes() + t.getSeconds() / 60) / 60, 0.74, 3.5, root.color);
            if (root.seconds)
                hand(t.getSeconds() / 60, 0.8, 1.5, root.accent);
            ctx.fillStyle = root.accent;
            ctx.beginPath();
            ctx.arc(0, 0, 4, 0, 2 * Math.PI);
            ctx.fill();
        }

        Connections {
            target: root
            function onNowChanged(): void {
                if (dial.visible)
                    dial.requestPaint();
            }
        }
    }

    Column {
        visible: root.face === "word"
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.words

            delegate: Row {
                id: line

                required property var modelData

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Repeater {
                    model: line.modelData

                    delegate: Text {
                        required property var modelData
                        textFormat: Text.PlainText
                        text: modelData[0]
                        color: root.on(modelData[0], modelData[1]) ? root.color : Qt.alpha(root.color, 0.16)
                        font.family: Tokens.fontUi
                        font.pixelSize: Math.max(10, Math.min(root.height / 9, root.width / 16))
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.5
                    }
                }
            }
        }
    }

    Item {
        id: orbit
        visible: root.face === "orbit"
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Qt.alpha(root.color, 0.15)
                strokeWidth: 4
                fillColor: "transparent"

                PathAngleArc {
                    centerX: orbit.width / 2
                    centerY: orbit.height / 2
                    radiusX: orbit.width / 2 - 4
                    radiusY: orbit.height / 2 - 4
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            ShapePath {
                strokeColor: root.accent
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: orbit.width / 2
                    centerY: orbit.height / 2
                    radiusX: orbit.width / 2 - 4
                    radiusY: orbit.height / 2 - 4
                    startAngle: -90
                    sweepAngle: Math.max(1, root.now.getSeconds() / 60 * 360)
                }
            }
        }

        Digits {
            anchors.centerIn: parent
            text: root.hh + ":" + root.mm
            color: root.color
            font.family: root.fontName
            font.pixelSize: orbit.width * 0.22
            font.weight: Font.DemiBold
        }
    }
}
