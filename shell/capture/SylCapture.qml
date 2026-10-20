import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.components
import "../lib/capture.mjs" as K
import "../lib/annotate.mjs" as A
import "../lib/icons.mjs" as Icons

Popup {
    id: root

    readonly property var cfg: Settings.values.capture
    readonly property string home: Quickshell.env("HOME")
    property string kind: "shot"
    property string mode: "region"
    property var rects: []
    property string last: ""
    property string problem: ""
    property real recordStart: 0
    property real tick: 0
    property bool started: false
    property real waitUntil: 0
    property string editing: ""
    property string editTarget: ""
    readonly property bool recording: recorder.running
    property bool stopping: false
    property string queued: ""

    namespace: "sylcapture"
    corner: root.local.placement.capture
    panelWidth: Tokens.captureWidth
    panelHeight: Tokens.captureHeight

    function shoot(mode: string): void {
        root.kind = "shot";
        root.start(mode);
    }

    function record(mode: string): void {
        if (root.recording) {
            if (root.stopping)
                root.queued = mode;
            return;
        }
        root.kind = "video";
        root.start(mode === "screen" ? "screen" : "region");
    }

    function start(requested: string): void {
        const mode = requested === "area" ? "region" : requested;
        if (["region", "window", "screen"].indexOf(mode) < 0)
            throw new Error("usage: capture shot <region|window|screen> or capture record <region|screen>");
        root.mode = mode;
        root.problem = "";
        root.close();
        if (mode === "window" && root.kind === "shot" && !Compositor.can("windowShot"))
            root.mode = "region";
        if (root.mode === "window" && root.kind === "shot")
            rectsProc.running = true;
        else
            later.restart();
    }

    function stop(): void {
        if (!root.recording)
            return;
        root.stopping = true;
        root.queued = "";
        recorder.signal(root.started ? 2 : 15);
    }

    function edit(file: string): void {
        const f = file || root.last;
        if (f === "")
            throw new Error("take a screenshot first, or give a file: capture edit <path>");
        const runtime = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/";
        const dir = K.expand(root.cfg.folder, root.home);
        const temporary = f.indexOf(runtime) === 0;
        if (temporary)
            Quickshell.execDetached(["mkdir", "-p", dir]);
        root.close();
        root.editing = "";
        root.editTarget = temporary ? dir + "/" + A.editedName(K.fileName("shot", new Date(), Object.assign({}, root.cfg, {
            format: "png"
        }))) : A.editedName(f);
        root.editing = f;
    }

    function state(): var {
        return {
            open: root.shown,
            recording: root.recording,
            started: root.started,
            last: root.last,
            problem: root.problem,
            editor: editorLoader.item ? editorLoader.item.state() : null
        };
    }

    function notify(title: string, file: string): void {
        if (!Demo.enabled)
            Quickshell.execDetached(["notify-send", "-a", "Sylvaris", "-i", file, title, file]);
    }

    Timer {
        id: later
        interval: 320
        onTriggered: {
            const out = Compositor.focusedName();
            const c = root.cfg;
            const dir = K.expand(root.kind === "video" ? c.videos : c.folder, root.home);
            const name = K.fileName(root.kind, new Date(), c);
            if (root.kind === "video") {
                root.started = false;
                root.waitUntil = 0;
                recorder.command = ["sh", Quickshell.shellDir + "/helpers/capture-record.sh", dir, name, root.mode, out, c.audio ? c.audioSource : "none", String(c.countdown)].concat(K.recorderArgs(c, ""));
                recorder.running = true;
            } else {
                shooter.command = ["sh", Quickshell.shellDir + "/helpers/capture-shot.sh", dir, name, root.mode, String(c.delay), c.copy ? "1" : "0", c.save ? "1" : "0", root.rects.join("\n"), out, c.format === "jpeg" ? "image/jpeg" : "image/png"].concat(K.grimArgs(c));
                shooter.running = true;
            }
        }
    }

    Process {
        id: rectsProc
        command: K.rectsCommand(Compositor.name) || ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.rects = K.parseRects(Compositor.name, text);
                } catch (e) {
                    root.rects = [];
                }
                if (root.rects.length === 0)
                    root.mode = "region";
                later.restart();
            }
        }
    }

    Process {
        id: shooter
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                if (f !== "") {
                    root.last = f;
                    if (root.cfg.after === "edit")
                        root.edit(f);
                    else if (root.cfg.after === "notify")
                        root.notify(root.cfg.save ? "Screenshot saved" : "Screenshot copied", f);
                }
            }
        }
        onExited: code => {
            if (code === 4)
                root.problem = "grim could not take the screenshot";
        }
    }

    Process {
        id: finisher
        onExited: root.notify("Recording saved", root.last)
    }

    Process {
        id: recorder
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("wait ") === 0) {
                    root.waitUntil = Date.now() + Number(line.slice(5)) * 1000;
                } else if (line.indexOf("/") === 0) {
                    root.last = line;
                    root.recordStart = Date.now();
                    root.started = true;
                }
            }
        }
        onExited: code => {
            if (root.started && code === 0) {
                finisher.command = ["sh", Quickshell.shellDir + "/helpers/capture-finish.sh", root.last, root.cfg.copy ? K.fileUri(root.last) : ""];
                finisher.running = true;
            }
            else if (root.started)
                root.problem = "the recording failed: wf-recorder stopped with code " + code;
            else if (code === 4)
                root.problem = "could not create " + root.cfg.videos;
            root.started = false;
            root.waitUntil = 0;
            root.stopping = false;
            if (root.queued !== "") {
                const next = root.queued;
                root.queued = "";
                Qt.callLater(() => root.record(next));
            }
        }
    }

    Timer {
        running: root.started && root.cfg.limit > 0
        interval: root.cfg.limit * 60000
        onTriggered: root.stop()
    }

    Timer {
        running: root.recording
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick = Date.now()
    }

    LazyLoader {
        id: editorLoader
        active: root.editing !== ""

        CaptureEditor {
            file: root.editing
            saveTo: root.editTarget
            screenInfo: Compositor.screenFor(Compositor.focusedName())
            onDone: root.editing = ""
        }
    }

    LazyLoader {
        active: root.recording && (root.started || root.waitUntil > 0) && !(Settings.values.parts.island && Settings.values.island.recording)

        PanelWindow {
            anchors.top: true
            margins.top: Tokens.edgeMargin + Tokens.barItemHeight + 10
            implicitWidth: pill.width
            implicitHeight: pill.height
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sylcapture-pill"

            Item {
                id: pill
                width: pillRow.implicitWidth + 28
                height: 40

                Glass {
                    anchors.fill: parent
                    radius: height / 2
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                Row {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        id: recDot
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.danger

                        SequentialAnimation on opacity {
                            running: root.recording && !Tokens.lite
                            loops: Animation.Infinite
                            onStopped: recDot.opacity = 1
                            NumberAnimation {
                                to: 0.3
                                duration: 700
                            }
                            NumberAnimation {
                                to: 1
                                duration: 700
                            }
                        }
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.started ? K.elapsed(root.tick - root.recordStart) : "Starts in " + Math.max(1, Math.ceil((root.waitUntil - root.tick) / 1000))
                        color: Theme.text
                        font.family: Tokens.fontMono
                        font.pixelSize: Tokens.bodySize
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26
                        radius: 13
                        color: stopArea.containsMouse ? Theme.danger : Qt.alpha(Theme.danger, 0.75)

                        Rectangle {
                            anchors.centerIn: parent
                            width: 9
                            height: 9
                            radius: 2
                            color: Theme.base
                        }

                        MouseArea {
                            id: stopArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.stop()
                        }
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 22

        Row {
            id: head
            spacing: 10

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.GLYPHS.camera
                size: 20
                color: Theme.accent
            }

            Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: "Capture"
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.titleSize
                font.weight: Font.DemiBold
            }
        }

        Item {
            id: editPill
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -6
            width: editRow.implicitWidth + 24
            height: 32
            visible: /\.(png|jpe?g)$/i.test(root.last)
            scale: editArea.pressed ? 0.95 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Tokens.stateDuration
                }
            }

            Glass {
                anchors.fill: parent
                radius: height / 2
                inner: true
                hot: editArea.containsMouse
            }

            Row {
                id: editRow
                anchors.centerIn: parent
                spacing: 6

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.GLYPHS.imageEdit
                    size: 15
                    color: Theme.accent
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Edit last"
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }
            }

            MouseArea {
                id: editArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.edit("")
            }
        }

        Segmented {
            id: kindPick
            anchors.right: parent.right
            anchors.verticalCenter: head.verticalCenter
            width: 220
            options: [
                {
                    key: "shot",
                    label: "Screenshot"
                },
                {
                    key: "video",
                    label: "Record"
                }
            ]
            current: root.kind
            onPicked: key => root.kind = key
        }

        Row {
            id: modes
            anchors.top: head.bottom
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Repeater {
                model: root.kind === "video" ? [
                    {
                        key: "region",
                        label: "Area",
                        glyph: Icons.GLYPHS.region
                    },
                    {
                        key: "screen",
                        label: "Screen",
                        glyph: Icons.GLYPHS.displays
                    }
                ] : [
                    {
                        key: "region",
                        label: "Area",
                        glyph: Icons.GLYPHS.region
                    },
                    {
                        key: "window",
                        label: "Window",
                        glyph: Icons.GLYPHS.windowPick
                    },
                    {
                        key: "screen",
                        label: "Screen",
                        glyph: Icons.GLYPHS.displays
                    }
                ].filter(t => t.key !== "window" || Compositor.can("windowShot"))

                delegate: Item {
                    id: tile
                    required property var modelData
                    width: 118
                    height: 104
                    scale: tileArea.pressed ? 0.95 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Tokens.stateDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    Glass {
                        anchors.fill: parent
                        radius: Tokens.radiusCard
                        inner: true
                        hot: tileArea.containsMouse
                        lit: tileArea.containsMouse
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Glyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.kind === "video" && tile.modelData.key !== "window" ? (tileArea.containsMouse ? Icons.GLYPHS.record : tile.modelData.glyph) : tile.modelData.glyph
                            size: 30
                            color: tileArea.containsMouse ? Theme.onAccent : root.kind === "video" ? Theme.danger : Theme.accent
                        }

                        Text {
                            textFormat: Text.PlainText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.label
                            color: tileArea.containsMouse ? Theme.onAccent : Theme.text
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.bodySize
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.kind === "video" ? root.record(tile.modelData.key) : root.shoot(tile.modelData.key)
                    }
                }
            }
        }

        Column {
            anchors.top: modes.bottom
            anchors.topMargin: 20
            width: parent.width
            spacing: 10

            Row {
                spacing: 10
                visible: root.kind === "shot"

                Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    width: 110
                    text: "Delay"
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }

                Segmented {
                    width: 260
                    options: K.DELAYS.map(d => ({
                                key: String(d),
                                label: d === 0 ? "None" : d + " s"
                            }))
                    current: String(root.cfg.delay)
                    onPicked: key => Settings.set("capture.delay", Number(key))
                }
            }

            Row {
                spacing: 10
                visible: root.kind === "video"

                Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    width: 110
                    text: "Desktop sound"
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }

                Toggle {
                    checked: root.cfg.audio
                    onToggled: v => Settings.set("capture.audio", v)
                }
            }

            Text {
                textFormat: Text.PlainText
                width: parent.width - (editPill.visible ? editPill.width + 12 : 0)
                text: root.problem !== "" ? root.problem : root.kind === "video" ? "Saves to " + root.cfg.videos : (root.cfg.copy ? "Copies to the clipboard" : "") + (root.cfg.copy && root.cfg.save ? " and saves to " : root.cfg.save ? "Saves to " : "") + (root.cfg.save ? root.cfg.folder : "")
                elide: Text.ElideMiddle
                color: root.problem !== "" ? Theme.danger : Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }
        }
    }
}
