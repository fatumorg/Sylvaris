import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import qs.settings
import "../../lib/fatest.mjs" as F
import "../../lib/icons.mjs" as Icons

Popup {
    id: root

    property var st: F.INITIAL
    property var history: []
    property bool available: false
    property bool checked: false
    property bool stopping: false
    property bool queued: false
    readonly property bool running: runner.running
    readonly property string historyPath: Stack.env("HOME") + "/.fatest_history.json"
    readonly property real headline: root.st.phase === "download" || root.st.phase === "upload" ? root.st.live : root.st.phase === "done" ? root.st.download : root.st.phase === "error" ? 0 : root.history.length > 0 ? root.history[0].download : 0

    namespace: "sylfatest"
    corner: root.local.placement.fatest
    panelWidth: Tokens.testWidth
    panelHeight: Tokens.testHeight

    function run(): void {
        if (runner.running)
            return;
        if (!root.available) {
            root.queued = true;
            checker.running = true;
            return;
        }
        root.stopping = false;
        root.st = F.reduce(F.INITIAL, {
            event: "status"
        });
        runner.running = true;
    }

    function stop(): void {
        if (!runner.running)
            return;
        root.stopping = true;
        runner.signal(15);
    }

    function state(): var {
        return {
            open: root.shown,
            available: root.available,
            running: runner.running,
            phase: root.st.phase,
            server: root.st.server,
            ping: root.st.ping,
            download: root.st.download,
            upload: root.st.upload,
            error: root.st.error,
            last: root.history.length > 0 ? root.history[0] : null
        };
    }

    onOpened: checker.running = true

    Process {
        id: checker
        running: true
        command: ["sh", "-c", "command -v fatest"]
        onExited: code => {
            root.available = code === 0;
            root.checked = true;
            if (!root.queued)
                return;
            root.queued = false;
            if (root.available)
                root.run();
            else
                root.st = F.reduce(F.INITIAL, {
                    event: "error",
                    message: "FaTest is not installed; get it from github.com/fatumorg/FaTest"
                });
        }
    }

    Process {
        id: runner
        command: ["fatest", "test", "--stream"]
        stdout: SplitParser {
            onRead: line => root.st = F.reduce(root.st, F.parseLine(line))
        }
        onExited: code => {
            if (root.stopping)
                root.st = F.INITIAL;
            else if (root.st.phase !== "done" && root.st.phase !== "error")
                root.st = F.reduce(root.st, {
                    event: "error",
                    message: code === 2 && root.st.phase === "server" ? "This FaTest is too old, update it to 2.1 or newer" : "FaTest stopped with exit code " + code
                });
            root.stopping = false;
        }
    }

    FileView {
        path: root.historyPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.history = F.parseHistory(text())
    }

    Column {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20

        Row {
            width: parent.width
            spacing: 10

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.GLYPHS.speed
                size: 20
                color: Theme.accent
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30

                Text {
                    textFormat: Text.PlainText
                    text: "FaTest"
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.titleSize
                    font.weight: Font.DemiBold
                }

                Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    elide: Text.ElideRight
                    text: !root.checked ? "" : !root.available ? "FaTest is not installed" : root.st.warning !== "" ? root.st.warning : root.st.server !== "" ? root.st.server + " · " + root.st.ping + " ms" : root.st.phase === "server" ? "Finding the best nearby server…" : root.history.length > 0 ? "Last run " + root.history[0].timestamp.replace("T", " ") : "Internet speed, measured by FaTest"
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }
            }
        }

        Column {
            width: parent.width
            spacing: 2

            Text {
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                text: F.speed(root.headline)
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.clockSize
                font.weight: Font.Light
                font.features: {
                    "tnum": 1
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.st.phase === "download" ? "Downloading" : root.st.phase === "upload" ? "Uploading" : root.st.phase === "saving" ? "Saving" : root.st.phase === "server" ? "Measuring ping" : root.st.phase === "error" ? root.st.error : "Download"
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: root.st.phase === "error" ? Theme.danger : Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }
        }

        Meter {
            label: "Download"
            glyph: Icons.GLYPHS.download
            value: root.st.phase === "download" ? root.st.live : root.st.download
            active: root.st.phase === "download"
        }

        Meter {
            label: "Upload"
            glyph: Icons.GLYPHS.upload
            value: root.st.phase === "upload" ? root.st.live : root.st.upload
            active: root.st.phase === "upload"
        }

        RowButton {
            anchors.horizontalCenter: parent.horizontalCenter
            enabled: root.available || !root.checked || root.st.phase === "error"
            opacity: enabled ? 1 : 0.4
            icon: root.running ? Icons.GLYPHS.stopCircle : Icons.GLYPHS.play
            label: root.running ? "Stop" : root.st.phase === "idle" ? "Start test" : "Test again"
            onClicked: root.running ? root.stop() : root.run()
        }

        Card {
            title: "History"
            note: root.history.length === 0 ? "Runs from FaTest and the fatest command show up here." : ""

            Repeater {
                model: root.history.slice(0, 3)

                delegate: SettingRow {
                    required property var modelData
                    required property int index
                    last: index === Math.min(root.history.length, 3) - 1
                    title: modelData.timestamp.replace("T", " ").slice(0, 16)
                    subtitle: String(modelData.server || "").slice(0, 40)

                    Text {
                        textFormat: Text.PlainText
                        text: "↓ " + F.speed(modelData.download) + "   ↑ " + F.speed(modelData.upload) + "   " + Math.round(modelData.ping) + " ms"
                        color: Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                        font.features: {
                            "tnum": 1
                        }
                    }
                }
            }
        }
    }

    component Meter: Item {
        id: meter

        property string label: ""
        property string glyph: ""
        property real value: 0
        property bool active: false

        width: parent.width
        height: 44

        Glass {
            anchors.fill: parent
            radius: Tokens.radiusRow
            inner: true
            offColor: Theme.tintMid
        }

        Item {
            width: parent.width * F.gauge(meter.value)
            height: parent.height
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: Tokens.moveDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.moveCurve
                }
            }

            Rectangle {
                width: meter.width
                height: parent.height
                radius: Tokens.radiusRow
                color: Theme.fill
            }
        }

        Row {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: meter.glyph
                size: 18
                color: Theme.accent
            }

            Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: meter.label
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.bodySize
            }
        }

        Text {
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: F.speed(meter.value)
            color: meter.active ? Theme.accentHi : Theme.text

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.stateDuration
                }
            }
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
            font.weight: Font.DemiBold
            font.features: {
                "tnum": 1
            }
        }
    }
}
