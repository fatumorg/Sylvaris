import QtQuick
import SylStack
import qs
import qs.services
import "../../lib/widgets.mjs" as Wd

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property color accent: root.frame !== null ? root.frame.accent : Theme.accent
    readonly property bool live: root.visible && !(root.frame !== null && root.frame.paused)
    property string stat: ""
    property string dev: ""
    property real at: 0
    property var cpu: []
    property var mem: []
    property var net: []
    property var memNow: ({
            used: 0,
            total: 0
        })
    property var rate: ({
            rx: 0,
            tx: 0
        })
    property var disk: ({
            used: 0,
            total: 0
        })
    readonly property var rows: [
        {
            key: "cpu",
            label: "CPU",
            value: root.cpu.length > 0 ? Math.round(root.cpu[root.cpu.length - 1] * 100) + "%" : "",
            trail: root.cpu
        },
        {
            key: "memory",
            label: "Memory",
            value: root.memNow.total > 0 ? Wd.usedOf(root.memNow.used, root.memNow.total) : "",
            trail: root.mem
        },
        {
            key: "disk",
            label: "Disk",
            value: root.disk.total > 0 ? Wd.usedOf(root.disk.used, root.disk.total) : "",
            share: root.disk.total > 0 ? root.disk.used / root.disk.total : 0
        },
        {
            key: "network",
            label: "Network",
            value: "↓" + Wd.rateText(root.rate.rx) + " ↑" + Wd.rateText(root.rate.tx),
            trail: root.net
        }
    ].filter(r => root.o[r.key] !== false)

    function push(list: var, v: real): var {
        return list.concat([v]).slice(-40);
    }

    function take(text: string): void {
        const cut = text.indexOf("Inter-|");
        const stat = cut < 0 ? text : text.slice(0, cut);
        const dev = cut < 0 ? "" : text.slice(cut);
        const now = Date.now();
        if (root.stat !== "") {
            root.cpu = root.push(root.cpu, Wd.cpuDelta(root.stat, stat));
            root.rate = Wd.netRate(root.dev, dev, now - root.at);
            root.net = root.push(root.net, root.rate.rx + root.rate.tx);
        }
        root.memNow = Wd.memUsed(stat);
        root.mem = root.push(root.mem, root.memNow.total > 0 ? root.memNow.used / root.memNow.total : 0);
        root.stat = stat;
        root.dev = dev;
        root.at = now;
    }

    Process {
        id: reader
        command: ["cat", "/proc/stat", "/proc/meminfo", "/proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: root.take(text)
        }
    }

    Process {
        id: df
        command: ["df", "-Pk", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n").pop().split(/\s+/);
                const total = Number(f[1]) * 1024;
                root.disk = total > 0 ? {
                    used: Number(f[2]) * 1024,
                    total: total
                } : {
                    used: 0,
                    total: 0
                };
            }
        }
    }

    Timer {
        interval: Math.max(1, root.o.every || 2) * 1000
        running: root.live
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!reader.running)
                reader.running = true;
        }
    }

    Timer {
        interval: 60000
        running: root.live && root.o.disk !== false
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!df.running)
                df.running = true;
        }
    }

    Column {
        anchors.fill: parent
        spacing: 6

        Repeater {
            model: root.rows

            delegate: Item {
                id: row

                required property var modelData

                width: parent.width
                height: (root.height - (root.rows.length - 1) * 6) / Math.max(1, root.rows.length)

                Text {
                    id: label
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.58
                    elide: Text.ElideRight
                    text: row.modelData.label + "  " + row.modelData.value
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                    font.features: {
                        "tnum": 1
                    }
                }

                Canvas {
                    id: graph
                    visible: row.modelData.trail !== undefined
                    anchors.left: label.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.min(parent.height, 28)
                    readonly property var trail: row.modelData.trail || []
                    onTrailChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        const t = graph.trail;
                        ctx.reset();
                        if (t.length < 2)
                            return;
                        const hi = row.modelData.key === "network" ? Math.max(1, Math.max.apply(null, t)) : 1;
                        ctx.beginPath();
                        for (let i = 0; i < t.length; i++) {
                            const x = (i + 40 - t.length) / 39 * width;
                            const y = height - 1 - t[i] / hi * (height - 2);
                            if (i === 0)
                                ctx.moveTo(x, y);
                            else
                                ctx.lineTo(x, y);
                        }
                        ctx.strokeStyle = root.accent;
                        ctx.lineWidth = 1.5;
                        ctx.stroke();
                        ctx.lineTo(width, height);
                        ctx.lineTo((40 - t.length) / 39 * width, height);
                        ctx.closePath();
                        ctx.fillStyle = Qt.alpha(root.accent, 0.18);
                        ctx.fill();
                    }
                }

                Rectangle {
                    visible: row.modelData.share !== undefined
                    anchors.left: label.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6
                    radius: height / 2
                    color: Qt.alpha(Theme.text, 0.12)

                    Rectangle {
                        width: parent.width * (row.modelData.share || 0)
                        height: parent.height
                        radius: height / 2
                        color: root.accent
                    }
                }
            }
        }
    }
}
