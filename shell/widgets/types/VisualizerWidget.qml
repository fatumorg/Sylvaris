import QtQuick
import SylStack
import qs
import qs.services
import "../../lib/widgets.mjs" as Wd

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property int count: root.o.bars || 32
    readonly property bool live: root.visible && !(root.frame !== null && root.frame.paused) && !Tokens.paused
    readonly property string conf: (Stack.env("XDG_RUNTIME_DIR") || "/tmp") + "/sylvaris/cava-" + (root.frame !== null && root.frame.item !== null ? root.frame.item.id : "x") + ".conf"
    readonly property bool ready: root.frame !== null && root.frame.item !== null
    readonly property string setup: root.ready ? cava.command.join("\n") : ""
    property bool restarting: false
    property var bars: []
    property string error: ""
    readonly property color tone: root.frame !== null ? root.frame.accent : Theme.accent

    function colourAt(i: int): color {
        if (root.o.colour === "rainbow")
            return Qt.hsla(i / Math.max(1, root.count), 0.75, 0.6, 1);
        if (root.o.colour === "theme")
            return Theme.text;
        return root.tone;
    }

    onCountChanged: root.bars = []
    onSetupChanged: {
        if (cava.running)
            root.restarting = true;
    }

    Process {
        id: cava
        running: root.ready && root.live && root.error === "" && !root.restarting
        command: ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && printf '%s' \"$1\" > \"$2\" && exec cava -p \"$2\"", "sh", Wd.cavaConfig({
                bars: root.count,
                fps: root.o.fps || 60,
                smoothing: root.o.smoothing === undefined ? 0.5 : root.o.smoothing
            }), root.conf]
        stdout: SplitParser {
            onRead: line => {
                const b = Wd.parseBars(line, root.count);
                if (b !== null)
                    root.bars = b;
            }
        }
        stderr: StdioCollector {
            id: cavaErr
        }
        onExited: code => {
            if (root.restarting)
                root.restarting = false;
            else if (code !== 0 && root.live)
                root.error = cavaErr.text.indexOf("not found") >= 0 ? "Install cava to see the visualizer" : "cava stopped (" + code + ")";
        }
    }

    Text {
        textFormat: Text.PlainText
        visible: root.error !== ""
        anchors.centerIn: parent
        text: root.error
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    Row {
        visible: root.error === "" && (root.o.style === "bars" || root.o.style === "mirror" || root.o.style === "dots" || root.o.style === undefined)
        anchors.fill: parent
        spacing: 2

        Repeater {
            model: root.count

            delegate: Item {
                id: bar

                required property int index
                readonly property real level: root.bars.length > bar.index ? root.bars[bar.index] : 0

                width: (root.width - (root.count - 1) * 2) / root.count
                height: root.height

                Rectangle {
                    visible: root.o.style !== "dots"
                    width: parent.width
                    height: Math.max(2, bar.level * (root.o.style === "mirror" ? parent.height / 2 : parent.height))
                    y: root.o.style === "mirror" ? parent.height / 2 - height / 2 : parent.height - height
                    radius: Math.min(width / 2, Tokens.r(3))
                    color: root.colourAt(bar.index)
                    opacity: root.o.glow === false ? 0.9 : 0.75 + 0.25 * bar.level
                }

                Rectangle {
                    visible: root.o.style === "dots"
                    width: parent.width
                    height: width
                    radius: width / 2
                    y: (parent.height - height) * (1 - bar.level)
                    color: root.colourAt(bar.index)
                }
            }
        }
    }

    Canvas {
        id: wave
        visible: root.error === "" && (root.o.style === "wave" || root.o.style === "radial")
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            const b = root.bars;
            ctx.reset();
            if (b.length === 0)
                return;
            ctx.strokeStyle = root.tone;
            ctx.lineWidth = 2;
            ctx.beginPath();
            if (root.o.style === "wave") {
                for (let i = 0; i < b.length; i++) {
                    const x = i / (b.length - 1) * width;
                    const y = height / 2 + (i % 2 === 0 ? -1 : 1) * b[i] * height / 2;
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
            } else {
                const r = Math.min(width, height) / 4;
                for (let i = 0; i <= b.length; i++) {
                    const a = i / b.length * 2 * Math.PI;
                    const len = r + b[i % b.length] * r;
                    const x = width / 2 + Math.cos(a) * len;
                    const y = height / 2 + Math.sin(a) * len;
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
            }
            ctx.stroke();
        }

        Connections {
            target: root
            function onBarsChanged(): void {
                if (wave.visible)
                    wave.requestPaint();
            }
        }
    }
}
