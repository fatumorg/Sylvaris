import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs
import qs.services
import qs.components
import "../lib/power.mjs" as Pw
import "../lib/icons.mjs" as Icons
import "../lib/version.mjs" as V
import "../lib/sections.mjs" as Sec

Scope {
    id: root

    property bool shown: false
    property bool wanted: false
    property var screenInfo: null
    property real reveal: 0
    property real dive: 0
    property real swap: 1
    property real time: 0
    property string section: ""
    property string shownSection: ""
    property int hovered: -1
    property string memory: ""
    property string uptimeText: ""
    readonly property string version: V.VERSION
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice.isLaptopBattery
    readonly property var cons: Settings.shown.constellation
    readonly property var sections: Sec.SECTIONS
    readonly property var groups: Sec.GROUPS
    property string group: "system"
    property real flip: 1
    readonly property var shownSections: Sec.sectionsIn(root.group, Settings.shown.plugins.enabled)
    readonly property var corners: [
        {
            key: "top-left",
            label: "Left"
        },
        {
            key: "top-center",
            label: "Center"
        },
        {
            key: "top-right",
            label: "Right"
        }
    ]
    readonly property var glassKeys: [
        {
            key: "opacity",
            label: "Panel opacity",
            max: 1
        },
        {
            key: "layerOpacity",
            label: "Tile opacity",
            max: 1
        },
        {
            key: "tint",
            label: "Accent tint",
            max: 1
        },
        {
            key: "sheen",
            label: "Sheen",
            max: 1
        },
        {
            key: "flow",
            label: "Sheen movement",
            max: 3
        },
        {
            key: "rim",
            label: "Rim light",
            max: 1
        }
    ]
    readonly property var binds: [
        {
            label: "Control Center",
            key: "A",
            command: "sylvaris center"
        },
        {
            label: "Clock and calendar",
            key: "D",
            command: "sylvaris clock"
        },
        {
            label: "Notifications",
            key: "N",
            command: "sylvaris notify"
        },
        {
            label: "App launcher",
            key: "Space",
            command: "sylvaris pad"
        },
        {
            label: "Media",
            key: "P",
            command: "sylvaris media open"
        },
        {
            label: "Theme picker",
            key: "T",
            command: "sylvaris theme"
        },
        {
            label: "Power menu",
            key: "Escape",
            command: "sylvaris power"
        },
        {
            label: "Wallpaper picker",
            key: "W",
            command: "sylvaris paper"
        },
        {
            label: "Settings",
            key: "comma",
            command: "sylvaris settings"
        },
        {
            label: "Play or pause",
            key: "XF86AudioPlay",
            command: "sylvaris media toggle"
        },
        {
            label: "Volume up",
            key: "XF86AudioRaiseVolume",
            command: "sylvaris audio up 5"
        },
        {
            label: "Volume down",
            key: "XF86AudioLowerVolume",
            command: "sylvaris audio down 5"
        }
    ]

    signal opened
    signal partRequested(string name, string arg)

    function phase(a: real, b: real): real {
        const t = Math.max(0, Math.min(1, (root.reveal - a) / (b - a)));
        return 1 - Math.pow(1 - t, 3);
    }

    function sectionInfo(key: string): var {
        return root.sections.filter(s => s.key === key)[0] || null;
    }

    function show(screen: var): void {
        root.screenInfo = screen;
        root.shown = true;
        statsFile.reload();
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

    function pickGroup(key: string): void {
        if (key === root.group)
            return;
        root.hovered = -1;
        root.group = key;
        flipAnim.restart();
    }

    function stepGroup(d: int): void {
        const keys = root.groups.map(g => g.key);
        root.pickGroup(keys[(keys.indexOf(root.group) + d + keys.length) % keys.length]);
    }

    function go(name: string): void {
        if (name === root.section)
            return;
        if (name !== "")
            root.pickGroup(root.sectionInfo(name).group);
        root.section = name;
        swapAnim.restart();
    }

    function back(): void {
        if (root.section !== "")
            root.go("");
        else
            root.close();
    }

    function showSection(name: string): void {
        root.go(name !== "" && root.sectionInfo(name) !== null ? name : name === "" ? root.section : "");
        root.open();
    }

    function hand(name: string, arg: string): void {
        root.close();
        root.partRequested(name, arg);
    }

    function glass(key: string): real {
        return Resin.values[key];
    }

    function node(i: int, n: int, rx: real, ry: real): var {
        const a = -Math.PI / 2 + Math.PI * 2 * i / Math.max(1, n) + root.time * 0.05;
        return {
            x: Math.cos(a) * rx,
            y: Math.sin(a) * ry,
            depth: (Math.sin(a) + 1) / 2
        };
    }

    function star(i: int): var {
        const r = n => {
            const x = Math.sin(i * 12.9898 + n * 78.233) * 43758.5453;
            return x - Math.floor(x);
        };
        return {
            x: r(1),
            y: r(2),
            size: 1 + r(3) * 2.2,
            speed: 0.4 + r(4) * 1.4,
            glow: r(5)
        };
    }

    onSectionChanged: {
        if (root.section !== "")
            diveIn.restart();
        else
            diveOut.restart();
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
        id: diveIn
        target: root
        property: "dive"
        to: 1
        duration: Tokens.moveDuration + 120
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.moveCurve
    }

    NumberAnimation {
        id: diveOut
        target: root
        property: "dive"
        to: 0
        duration: Tokens.moveDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.moveCurve
    }

    NumberAnimation {
        id: flipAnim
        target: root
        property: "flip"
        from: 0
        to: 1
        duration: Tokens.enterDuration + 80
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.enterCurve
    }

    SequentialAnimation {
        id: swapAnim

        NumberAnimation {
            target: root
            property: "swap"
            to: 0
            duration: root.shownSection === "" ? 0 : Tokens.exitDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.exitCurve
        }
        ScriptAction {
            script: {
                root.shownSection = root.section;
            }
        }
        NumberAnimation {
            target: root
            property: "swap"
            to: 1
            duration: Tokens.enterDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }
    }

    FileView {
        id: statsFile
        path: "/proc/self/status"
        printErrors: false
        onLoaded: {
            const m = /VmRSS:\s+(\d+)/.exec(text());
            root.memory = m ? Math.round(Number(m[1]) / 1024) + " MB" : "";
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.uptimeText = Pw.uptime(Number(text().split(" ")[0]))
    }

    Timer {
        interval: 5000
        running: root.shown
        repeat: true
        onTriggered: {
            statsFile.reload();
            uptimeFile.reload();
        }
    }

    onShownChanged: {
        if (!root.shown) {
            keep.restart();
            Settings.editing = "";
        }
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
            WlrLayershell.namespace: "sylsettings"
            WlrLayershell.keyboardFocus: root.wanted ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            readonly property real side: Math.min(400, Math.max(300, width * 0.17))
            readonly property real gutter: Math.max(24, width * 0.018)
            readonly property real midX: win.gutter * 2 + win.side
            readonly property real midW: win.width - (win.gutter * 2 + win.side) * 2

            onVisibleChanged: {
                if (visible)
                    keys.forceActiveFocus();
            }
            Component.onCompleted: {
                if (visible)
                    keys.forceActiveFocus();
            }

            Connections {
                target: root
                function onShownSectionChanged() {
                    content.contentY = 0;
                }
            }

            FrameAnimation {
                running: win.visible && !Tokens.lite && (root.cons.speed > 0 || root.cons.stars)
                onTriggered: root.time += frameTime * Math.max(0.2, root.cons.speed)
            }

            Backdrop {
                anchors.fill: parent
                reveal: root.reveal
            }

            Item {
                anchors.fill: parent
                visible: root.cons.stars && !Tokens.lite
                opacity: root.phase(0.1, 0.6)

                Repeater {
                    model: 90

                    delegate: Rectangle {
                        required property int index
                        readonly property var s: root.star(index)
                        x: s.x * win.width
                        y: s.y * win.height
                        width: s.size
                        height: s.size
                        radius: s.size / 2
                        color: s.glow > 0.8 ? Theme.accentHi : Theme.text
                        opacity: (0.15 + 0.35 * s.glow) * (0.6 + 0.4 * Math.sin(root.time * s.speed + index))
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.back()
            }

            Item {
                id: keys
                focus: true
                Keys.onEscapePressed: root.back()
                Keys.onLeftPressed: root.hovered = (root.hovered - 1 + root.shownSections.length) % root.shownSections.length
                Keys.onRightPressed: root.hovered = (root.hovered + 1) % root.shownSections.length
                Keys.onTabPressed: event => root.stepGroup(event.modifiers & Qt.ShiftModifier ? -1 : 1)
                Keys.onBacktabPressed: root.stepGroup(-1)
                Keys.onReturnPressed: {
                    if (root.hovered >= 0)
                        root.go(root.shownSections[root.hovered].key);
                }
            }

            Item {
                id: hub
                readonly property real cx: win.midX + win.midW / 2
                readonly property real cy: win.height * 0.5
                readonly property real rx: Math.min(win.midW * 0.42, 560)
                readonly property real ry: Math.min(win.height * 0.3, hub.rx * 0.52)
                readonly property real mini: 0.38
                readonly property real targetY: win.gutter + 20 + (hub.ry + 70) * hub.mini
                anchors.fill: parent
                opacity: root.phase(0.1, 0.5) * (1 - 0.2 * root.dive)

                transform: [
                    Scale {
                        origin.x: hub.cx
                        origin.y: hub.cy
                        xScale: 1 - (1 - hub.mini) * root.dive
                        yScale: 1 - (1 - hub.mini) * root.dive
                    },
                    Translate {
                        y: (hub.targetY - hub.cy) * root.dive
                    }
                ]

                Shape {
                    anchors.fill: parent
                    visible: root.cons.ring
                    opacity: root.phase(0.15, 0.55) * 0.8
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Qt.alpha(Theme.text, 0.14)
                        strokeWidth: 1.5
                        fillColor: "transparent"
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [2, 9]

                        PathAngleArc {
                            centerX: hub.cx
                            centerY: hub.cy
                            radiusX: hub.rx * (0.7 + 0.3 * root.phase(0.15, 0.55))
                            radiusY: hub.ry * (0.7 + 0.3 * root.phase(0.15, 0.55))
                            startAngle: 0
                            sweepAngle: 360
                        }
                    }
                }

                Repeater {
                    model: root.cons.links ? root.shownSections : []

                    delegate: Shape {
                        id: link
                        required property var modelData
                        required property int index
                        readonly property var p: root.node(link.index, root.shownSections.length, hub.rx, hub.ry)
                        readonly property bool on: root.hovered === link.index || root.section === link.modelData.key
                        anchors.fill: parent
                        opacity: root.phase(0.35, 0.8) * root.flip * (link.on ? 0.85 : 0.14)
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeWidth: link.on ? 2.5 : 1.5
                            strokeColor: link.on ? Theme.accentHi : Theme.text
                            fillColor: "transparent"
                            startX: hub.cx
                            startY: hub.cy
                            PathQuad {
                                controlX: hub.cx + link.p.x * 0.5 + 30 * Math.sin(root.time * 0.7 + link.index)
                                controlY: hub.cy + link.p.y * 0.5 - 24
                                x: hub.cx + link.p.x
                                y: hub.cy + link.p.y
                            }
                        }
                    }
                }

                Item {
                    x: hub.cx - width / 2
                    y: hub.cy - height / 2
                    width: 170
                    height: 170
                    opacity: root.phase(0.05, 0.45)
                    scale: 0.6 + 0.4 * root.phase(0.05, 0.45)

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 30 + 8 * Math.sin(root.time * 1.3)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.alpha(Theme.accent, 0.35)
                    }

                    Glass {
                        anchors.fill: parent
                        radius: width / 2
                        raised: true
                        lit: root.section !== ""
                    }

                    Glyph {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -12
                        text: root.section === "" ? Icons.GLYPHS.settings : root.sectionInfo(root.section).glyph
                        size: 54
                        color: root.section === "" ? Theme.accent : Theme.onAccent
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 30
                        text: root.section === "" ? "Settings" : "Back"
                        color: root.section === "" ? Theme.textSoft : Theme.onAccent
                        font.family: Tokens.fontUi
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.go("")
                    }
                }

                Repeater {
                    model: root.shownSections

                    delegate: Item {
                        id: star
                        required property var modelData
                        required property int index
                        readonly property var p: root.node(star.index, root.shownSections.length, hub.rx, hub.ry)
                        readonly property bool on: root.section === star.modelData.key
                        readonly property bool hot: root.hovered === star.index
                        readonly property real arrive: root.phase(0.25 + 0.4 * star.index / root.shownSections.length, 0.65 + 0.3 * star.index / root.shownSections.length) * Math.min(1, Math.max(0, root.flip * 1.6 - 0.6 * star.index / root.shownSections.length))
                        x: hub.cx + star.p.x * (0.4 + 0.6 * star.arrive) - width / 2
                        y: hub.cy + star.p.y * (0.4 + 0.6 * star.arrive) - height / 2
                        width: 104
                        height: 104
                        z: star.hot ? 3 : 1 + star.p.depth
                        opacity: star.arrive
                        scale: (0.5 + 0.5 * star.arrive) * (0.86 + 0.14 * star.p.depth) * (starArea.pressed ? 0.92 : star.hot || star.on ? 1.14 : 1)

                        Behavior on scale {
                            enabled: star.arrive >= 1
                            NumberAnimation {
                                duration: Tokens.stateDuration + 80
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Tokens.springCurve
                            }
                        }

                        Glass {
                            anchors.fill: parent
                            radius: width / 2
                            raised: star.hot || star.on
                            lit: star.on
                            hot: star.hot
                        }

                        Glyph {
                            anchors.centerIn: parent
                            text: star.modelData.glyph
                            size: 36
                            color: star.on ? Theme.onAccent : star.hot ? Theme.accentHi : Theme.text
                        }

                        Text {
                            textFormat: Text.PlainText
                            visible: root.cons.labels || star.hot
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 10
                            transformOrigin: Item.Top
                            scale: Math.max(1, 0.72 / (1 - (1 - hub.mini) * root.dive))
                            text: star.modelData.label
                            color: star.hot || star.on ? Theme.text : Theme.textSoft
                            font.family: Tokens.fontUi
                            font.pixelSize: 16
                            font.weight: star.hot || star.on ? Font.DemiBold : Font.Medium
                            style: Text.Raised
                            styleColor: Qt.alpha("#000000", 0.3)
                        }

                        MouseArea {
                            id: starArea
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.hovered = star.index
                            onExited: {
                                if (root.hovered === star.index)
                                    root.hovered = -1;
                            }
                            onClicked: root.go(star.modelData.key)
                        }
                    }
                }
            }

            Text {
                textFormat: Text.PlainText
                x: hub.cx - width / 2
                y: win.height - 120
                visible: root.dive < 0.99
                opacity: root.phase(0.6, 1) * (1 - root.dive)
                text: root.hovered >= 0 && root.hovered < root.shownSections.length ? "Open " + root.shownSections[root.hovered].label.toLowerCase() : "Pick a star · Tab switches groups"
                color: Theme.textSoft
                font.family: Tokens.fontUi
                font.pixelSize: 20
            }

            Segmented {
                x: hub.cx - width / 2
                y: win.height * 0.5 - hub.ry - 150
                width: Math.min(win.midW - 40, 760)
                visible: root.dive < 0.99
                opacity: root.phase(0.4, 0.9) * (1 - root.dive)
                options: root.groups
                current: root.group
                onPicked: key => root.pickGroup(key)
            }

            SidePanel {
                id: leftPanel
                x: win.gutter - (1 - root.phase(0.3, 0.8)) * 60
                y: win.gutter
                width: win.side
                height: win.height - win.gutter * 2
                opacity: root.phase(0.3, 0.8)
                title: "Constellation"
                glyph: Icons.GLYPHS.stars

                ConstellationControls {
                    width: parent.width
                }
            }

            SidePanel {
                id: rightPanel
                x: win.width - win.gutter - win.side + (1 - root.phase(0.35, 0.85)) * 60
                y: win.gutter
                width: win.side
                height: win.height - win.gutter * 2
                opacity: root.phase(0.35, 0.85)
                title: "Statistics"
                glyph: Icons.GLYPHS.chart

                StatsAbout {
                    width: parent.width
                    version: root.version
                    memory: root.memory
                    uptime: root.uptimeText
                    onReload: Quickshell.reload(false)
                }
            }

            Item {
                id: sheet
                readonly property real startY: win.gutter + 30 + (hub.ry + 70) * 2 * hub.mini
                x: win.midX + (win.midW - width) / 2
                y: sheet.startY + (1 - root.dive) * 80
                width: Math.min(win.midW - win.gutter, 860)
                height: win.height - sheet.startY - win.gutter
                visible: root.dive > 0.01
                opacity: root.dive

                MouseArea {
                    anchors.fill: parent
                }

                Glass {
                    anchors.fill: parent
                    radius: Tokens.radiusPanel
                    raised: true
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                Row {
                    id: sheetHead
                    x: 30
                    y: 24
                    spacing: 14
                    opacity: root.swap

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.shownSection === "" ? "" : root.sectionInfo(root.shownSection).glyph
                        size: 24
                        color: Theme.accent
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.shownSection === "" ? "" : root.sectionInfo(root.shownSection).label
                        color: Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                    }
                }

                ScreenPicker {
                    anchors.right: parent.right
                    anchors.rightMargin: 68
                    y: sheetHead.y
                    opacity: root.swap
                }

                Glyph {
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    anchors.verticalCenter: sheetHead.verticalCenter
                    text: Icons.GLYPHS.close
                    size: 20
                    color: sheetClose.containsMouse ? Theme.text : Theme.textDim

                    MouseArea {
                        id: sheetClose
                        anchors.fill: parent
                        anchors.margins: -10
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.go("")
                    }
                }

                Flickable {
                    id: content
                    x: 30
                    y: sheetHead.y + sheetHead.height + 22
                    width: parent.width - 60
                    height: parent.height - y - 20
                    clip: true
                    contentHeight: page.item ? page.item.implicitHeight + 20 : 0
                    boundsBehavior: Flickable.StopAtBounds
                    opacity: root.swap

                    Loader {
                        id: page
                        width: content.width
                        y: (1 - root.swap) * 18
                        sourceComponent: ({
                                general: generalPage,
                                appearance: appearancePage,
                                motion: motionPage,
                                wallpaper: wallpaperPage,
                                bar: barPage,
                                center: centerPage,
                                deck: deckPage,
                                launcher: launcherPage,
                                notifications: notificationsPage,
                                sound: soundPage,
                                displays: displaysPage,
                                clock: clockPage,
                                weather: weatherPage,
                                power: powerPage,
                                diver: diverPage,
                                fatest: fatestPage,
                                rgb: rgbPage,
                                switcher: switcherPage,
                                lock: lockPage,
                                polkit: polkitPage,
                                clip: clipPage,
                                viewer: viewerPage,
                                files: filesPage,
                                island: islandPage,
                                capture: capturePage,
                                access: accessPage,
                                plugins: pluginsPage,
                                sync: syncPage,
                                keybinds: keybindsPage,
                                commands: commandsPage
                            })[root.shownSection] || null
                    }
                }
            }
        }
    }

    Component {
        id: syncPage

        SyncPage {}
    }

    Component {
        id: pluginsPage

        PluginsPage {}
    }

    Component {
        id: accessPage

        AccessPage {}
    }

    Component {
        id: capturePage

        CapturePage {}
    }

    Component {
        id: islandPage

        IslandPage {}
    }

    Component {
        id: clipPage

        ClipPage {}
    }

    Component {
        id: viewerPage

        ViewerPage {}
    }

    Component {
        id: filesPage

        FilesPage {}
    }

    Component {
        id: polkitPage

        PolkitPage {
            onPreviewRequested: Ipc.run(["polkit", "preview"])
        }
    }

    Component {
        id: lockPage

        LockPage {
            onLockRequested: Ipc.run(["lock", "now"])
        }
    }

    Component {
        id: switcherPage

        SwitcherPage {}
    }

    Component {
        id: generalPage

        GeneralPage {
            host: root
        }
    }

    Component {
        id: appearancePage

        AppearancePage {
            host: root
        }
    }

    Component {
        id: centerPage

        CenterPage {
            host: root
        }
    }

    Component {
        id: barPage

        BarPage {
            host: root
        }
    }

    Component {
        id: deckPage

        DeckPage {
            host: root
        }
    }

    Component {
        id: launcherPage

        LauncherPage {
            host: root
        }
    }

    Component {
        id: notificationsPage

        NotificationsPage {
            host: root
        }
    }

    Component {
        id: soundPage

        SoundPage {
            host: root
        }
    }

    Component {
        id: displaysPage

        DisplaysPage {
            host: root
        }
    }

    Component {
        id: clockPage

        ClockPage {
            host: root
        }
    }

    Component {
        id: weatherPage

        WeatherPage {
            host: root
        }
    }

    Component {
        id: motionPage

        MotionPage {
            host: root
        }
    }

    Component {
        id: wallpaperPage

        WallpaperPage {
            host: root
        }
    }

    Component {
        id: powerPage

        PowerPage {
            host: root
        }
    }

    Component {
        id: diverPage

        Loader {
            Component.onCompleted: setSource("../plugins/diver/DiverPage.qml", {
                host: root
            })
        }
    }

    Component {
        id: fatestPage

        Loader {
            Component.onCompleted: setSource("../plugins/fatest/FaTestPage.qml", {
                host: root
            })
        }
    }

    Component {
        id: rgbPage

        Loader {
            Component.onCompleted: setSource("../plugins/rgb/RGBPage.qml", {
                host: root
            })
        }
    }

    Component {
        id: keybindsPage

        KeybindsPage {
            host: root
        }
    }

    Component {
        id: commandsPage

        CommandsPage {
            host: root
        }
    }
}
