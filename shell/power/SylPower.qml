import QtQuick
import QtQuick.Shapes
import SylStack
import qs
import qs.services
import qs.components
import "../lib/power.mjs" as P
import "../lib/icons.mjs" as Icons
import "../lib/settings.mjs" as S

Scope {
    id: root

    property bool shown: false
    property bool wanted: false
    property var screenInfo: null
    property real reveal: 0
    property real time: 0
    property int selected: 0
    property string pending: ""
    property real countdown: 0
    property string uptimeText: ""
    readonly property var cfg: Settings.values.power
    readonly property var ids: root.cfg.actions
    readonly property string current: root.ids.length > 0 ? root.ids[Math.max(0, Math.min(root.ids.length - 1, root.selected))] : ""
    readonly property var meta: root.current === "" ? null : P.ACTIONS[root.current]
    readonly property string avatar: S.expandHome(Config.values.avatar, Stack.env("HOME"))

    signal opened

    function phase(a: real, b: real): real {
        const t = Math.max(0, Math.min(1, (root.reveal - a) / (b - a)));
        return 1 - Math.pow(1 - t, 3);
    }

    function show(screen: var): void {
        root.screenInfo = screen;
        root.selected = Math.max(0, root.ids.indexOf("lock"));
        root.pending = "";
        root.shown = true;
        uptimeFile.reload();
        hideAnim.stop();
        showAnim.restart();
        root.opened();
    }

    function open(): void {
        if (root.wanted)
            return;
        root.wanted = true;
        Compositor.refresh(() => {
            if (root.wanted)
                root.show(Compositor.screenFor(Compositor.focusedName()));
        });
    }

    function toggleOn(screen: var): void {
        if (root.wanted) {
            root.close();
            return;
        }
        root.wanted = true;
        root.show(screen);
    }

    function close(): void {
        root.wanted = false;
        root.pending = "";
        if (!root.shown)
            return;
        showAnim.stop();
        hideAnim.restart();
    }

    function toggle(): void {
        if (root.wanted)
            root.close();
        else
            root.open();
    }

    function step(d: int): void {
        if (root.ids.length === 0)
            return;
        root.pending = "";
        root.selected = (root.selected + d + root.ids.length) % root.ids.length;
    }

    function choose(id: string): void {
        const i = root.ids.indexOf(id);
        if (i < 0)
            return;
        if (root.pending === id) {
            root.execute(id);
            return;
        }
        root.selected = i;
        if (P.needsConfirm(id, root.cfg)) {
            root.pending = id;
            root.countdown = 0;
            countdownAnim.restart();
        } else {
            root.execute(id);
        }
    }

    function execute(id: string): void {
        root.pending = "";
        countdownAnim.stop();
        root.close();
        run(id);
    }

    function run(id: string): void {
        if (P.ACTIONS[id] === undefined)
            throw new Error("unknown power action: " + id);
        if (Demo.enabled)
            return;
        const cmd = P.commandFor(id, root.cfg, Config.values.lockCommand);
        if (id === "logout" && cmd === "")
            Compositor.run("quit", []);
        else if (cmd !== "")
            Stack.execDetached(["sh", "-c", cmd]);
    }

    NumberAnimation {
        id: showAnim
        target: root
        property: "reveal"
        to: 1
        duration: Math.round(900 * Tokens.pace)
    }

    NumberAnimation {
        id: hideAnim
        target: root
        property: "reveal"
        to: 0
        duration: Tokens.exitDuration + 120
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.exitCurve
        onFinished: root.shown = false
    }

    NumberAnimation {
        id: countdownAnim
        target: root
        property: "countdown"
        from: 0
        to: 1
        duration: root.cfg.countdown * 1000
        onFinished: {
            if (root.pending !== "")
                root.execute(root.pending);
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.uptimeText = "up " + P.uptime(Number(text().split(" ")[0]))
    }

    onShownChanged: {
        if (!root.shown)
            keep.restart();
    }

    Timer {
        id: keep
        interval: 20000
    }

    LazyLoader {
        active: root.shown || keep.running

        PanelWindow {
            id: win
            visible: root.shown
            screen: root.screenInfo
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sylpower"
            WlrLayershell.keyboardFocus: root.wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: {
                if (visible)
                    stage.forceActiveFocus();
            }
            Component.onCompleted: {
                if (visible)
                    stage.forceActiveFocus();
            }

            FrameAnimation {
                running: win.visible && !Tokens.lite
                onTriggered: root.time += frameTime
            }

            Backdrop {
                anchors.fill: parent
                reveal: root.reveal
                tint: root.pending !== "" ? Theme.danger : Theme.accentDeep
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.pending !== "")
                        root.pending = "";
                    else
                        root.close();
                }
            }

            Item {
                id: stage
                readonly property real k: win.height > 0 ? Math.min(win.width / 2560, win.height / 1440) : 1
                readonly property real cx: 1280
                readonly property real cy: 640
                readonly property real rx: 640
                readonly property real ry: 250
                width: 2560
                height: 1440
                scale: stage.k
                transformOrigin: Item.TopLeft
                x: (win.width - 2560 * stage.k) / 2
                y: (win.height - 1440 * stage.k) / 2
                focus: true
                opacity: hideAnim.running ? root.reveal : 1

                Keys.onLeftPressed: root.step(-1)
                Keys.onRightPressed: root.step(1)
                Keys.onUpPressed: root.step(-1)
                Keys.onDownPressed: root.step(1)
                Keys.onTabPressed: root.step(1)
                Keys.onReturnPressed: root.choose(root.current)
                Keys.onEnterPressed: root.choose(root.current)
                Keys.onSpacePressed: root.choose(root.current)
                Keys.onEscapePressed: {
                    if (root.pending !== "")
                        root.pending = "";
                    else
                        root.close();
                }
                Keys.onPressed: event => {
                    const id = P.byKey(root.ids, event.text);
                    if (id !== "") {
                        root.choose(id);
                        event.accepted = true;
                    }
                }

                Shape {
                    anchors.fill: parent
                    opacity: root.phase(0.15, 0.55) * 0.8
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Qt.alpha(Theme.text, 0.14)
                        strokeWidth: 2
                        fillColor: "transparent"
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [2, 10]

                        PathAngleArc {
                            centerX: stage.cx
                            centerY: stage.cy
                            radiusX: stage.rx * (0.7 + 0.3 * root.phase(0.15, 0.55))
                            radiusY: stage.ry * (0.7 + 0.3 * root.phase(0.15, 0.55))
                            startAngle: 0
                            sweepAngle: 360
                        }
                    }
                }

                Repeater {
                    model: root.ids

                    delegate: Shape {
                        id: link
                        required property string modelData
                        required property int index
                        readonly property var p: P.ring(root.ids.length, link.index, stage.rx, stage.ry, 0)
                        readonly property bool on: root.current === link.modelData
                        anchors.fill: parent
                        opacity: root.phase(0.35, 0.8) * (link.on ? 0.9 : 0.16)
                        preferredRendererType: Shape.CurveRenderer

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Tokens.stateDuration + 60
                            }
                        }

                        ShapePath {
                            strokeWidth: link.on ? 3 : 2
                            fillColor: "transparent"
                            strokeColor: link.on && root.pending !== "" ? Theme.danger : Theme.accentHi
                            startX: stage.cx
                            startY: stage.cy
                            PathQuad {
                                controlX: stage.cx + link.p.x * 0.5 + 40 * Math.sin(root.time * 0.6 + link.index)
                                controlY: stage.cy + link.p.y * 0.5 - 30
                                x: stage.cx + link.p.x
                                y: stage.cy + link.p.y
                            }
                        }
                    }
                }

                Item {
                    id: core
                    x: stage.cx - width / 2
                    y: stage.cy - height / 2
                    width: 230
                    height: 230
                    opacity: root.phase(0.1, 0.5)
                    scale: 0.6 + 0.4 * root.phase(0.1, 0.5)

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 36 + 8 * Math.sin(root.time * 1.4)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.alpha(root.pending !== "" ? Theme.danger : Theme.accent, 0.35)

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Tokens.stateDuration
                            }
                        }
                    }

                    Glass {
                        anchors.fill: parent
                        radius: width / 2
                        raised: true
                    }

                    RoundImage {
                        id: face
                        anchors.fill: parent
                        anchors.margins: 12
                        source: root.avatar === "" ? "" : "file://" + root.avatar
                    }

                    Glyph {
                        visible: !face.ready
                        anchors.centerIn: parent
                        text: Icons.GLYPHS.power
                        size: 90
                        color: Theme.accent
                    }
                }

                Column {
                    x: stage.cx - width / 2
                    y: stage.cy + 150
                    opacity: root.phase(0.3, 0.7)
                    spacing: 4

                    Text {
                        textFormat: Text.PlainText
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Stack.env("USER") || ""
                        color: Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: 34
                        font.weight: Font.DemiBold
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.uptimeText
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: 22
                    }
                }

                Repeater {
                    model: root.ids

                    delegate: Item {
                        id: orb
                        required property string modelData
                        required property int index
                        readonly property var a: P.ACTIONS[orb.modelData]
                        readonly property var p: P.ring(root.ids.length, orb.index, stage.rx, stage.ry, 0)
                        readonly property bool on: root.current === orb.modelData
                        readonly property bool arming: root.pending === orb.modelData
                        readonly property real arrive: root.phase(0.3 + 0.35 * orb.index / Math.max(1, root.ids.length), 0.72 + 0.25 * orb.index / Math.max(1, root.ids.length))
                        readonly property real bob: Tokens.lite ? 0 : 8 * Math.sin(root.time * 0.9 + orb.index * 1.7)
                        x: stage.cx + orb.p.x * (0.4 + 0.6 * orb.arrive) - width / 2
                        y: stage.cy + orb.p.y * (0.4 + 0.6 * orb.arrive) - height / 2 + orb.bob
                        width: 170
                        height: 170
                        z: orb.on ? 2 : 1
                        opacity: orb.arrive
                        scale: (0.5 + 0.5 * orb.arrive) * (area.pressed ? 0.92 : orb.on ? 1.14 : area.containsMouse ? 1.06 : 1)

                        Behavior on scale {
                            enabled: orb.arrive >= 1
                            NumberAnimation {
                                duration: Tokens.moveDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Tokens.springCurve
                            }
                        }

                        Glass {
                            anchors.fill: parent
                            radius: width / 2
                            raised: orb.on
                            lit: orb.on
                            litColor: orb.arming ? Theme.danger : Theme.accent
                            hot: area.containsMouse
                        }

                        Shape {
                            anchors.fill: parent
                            anchors.margins: -12
                            visible: orb.arming
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeColor: Theme.danger
                                strokeWidth: 6
                                capStyle: ShapePath.RoundCap
                                fillColor: "transparent"

                                PathAngleArc {
                                    centerX: orb.width / 2 + 12
                                    centerY: orb.height / 2 + 12
                                    radiusX: orb.width / 2 + 6
                                    radiusY: orb.height / 2 + 6
                                    startAngle: -90
                                    sweepAngle: 360 * root.countdown
                                }
                            }
                        }

                        Glyph {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -10
                            text: Icons.GLYPHS[orb.a.glyph]
                            size: 58
                            color: orb.on ? Theme.onAccent : Theme.text

                            Behavior on color {
                                ColorAnimation {
                                    duration: Tokens.stateDuration
                                }
                            }
                        }

                        Text {
                            textFormat: Text.PlainText
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 26
                            text: orb.arming ? Math.max(1, Math.ceil(root.cfg.countdown * (1 - root.countdown))) + "" : orb.a.key.toUpperCase()
                            color: orb.on ? Qt.alpha(Theme.onAccent, 0.8) : Theme.textDim
                            font.family: Tokens.fontMono
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }

                        Text {
                            textFormat: Text.PlainText
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 14
                            text: orb.a.label
                            opacity: orb.on ? 1 : 0.7
                            color: orb.on ? Theme.text : Theme.textSoft
                            font.family: Tokens.fontUi
                            font.pixelSize: 24
                            font.weight: orb.on ? Font.DemiBold : Font.Medium
                        }

                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                if (root.pending === "")
                                    root.selected = orb.index;
                            }
                            onClicked: root.choose(orb.modelData)
                        }
                    }
                }

                Item {
                    x: 140
                    y: 1440 - 170 - title.height
                    width: info.width
                    height: info.height
                    opacity: root.phase(0.5, 0.9)

                    transform: Translate {
                        y: (1 - root.phase(0.5, 0.9)) * 200
                    }

                    Column {
                        id: info
                        spacing: 6

                        Text {
                            textFormat: Text.PlainText
                            id: title
                            text: root.meta === null ? "" : root.pending !== "" ? root.meta.verb + "…" : root.meta.label
                            color: Qt.alpha(root.pending !== "" ? Theme.danger : Theme.text, 0.92)
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.themeNameSize
                            font.weight: Font.ExtraBold
                            font.letterSpacing: -6
                        }

                        Text {
                            textFormat: Text.PlainText
                            text: root.meta === null ? "" : root.pending !== "" ? "Press again to do it now, Esc to stay" : root.meta.about
                            color: Theme.textDim
                            font.family: Tokens.fontUi
                            font.pixelSize: 28
                        }
                    }
                }

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 1440 - 50 - height
                    width: hint.implicitWidth + 40
                    height: hint.implicitHeight + 16
                    opacity: root.phase(0.66, 1)

                    Glass {
                        anchors.fill: parent
                        radius: height / 2
                    }

                    Text {
                        textFormat: Text.PlainText
                        id: hint
                        anchors.centerIn: parent
                        text: "◀ ▶ choose · Enter confirm · letters jump · Esc close"
                        color: Theme.textSoft
                        font.family: Tokens.fontUi
                        font.pixelSize: 20
                    }
                }
            }
        }
    }
}
