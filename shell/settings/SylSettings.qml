import QtQuick
import QtQuick.Shapes
import SylStack
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
    readonly property var shownSections: Sec.HUBS.map(h => ({
                key: h.key,
                label: h.label,
                glyph: h.icon,
                tabs: Sec.tabsIn(h.key, Settings.shown.plugins.enabled)
            })).filter(h => h.tabs.length > 0)
    readonly property string hub: {
        const w = Sec.resolveSection(root.section);
        return w === null ? "" : w.hub;
    }
    readonly property var hubInfo: {
        const w = Sec.resolveSection(root.shownSection);
        return w === null ? null : root.shownSections.find(h => h.key === w.hub) || null;
    }
    property string group: ""
    property var lastTab: ({})
    property string query: ""
    property string pending: ""
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
    signal revealRequested
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

    function step(d: int): void {
        const n = root.shownSections.length;
        root.hovered = root.hovered < 0 ? (d > 0 ? 0 : n - 1) : (root.hovered + d + n) % n;
    }

    function go(name: string): void {
        if (name === root.section)
            return;
        const w = Sec.resolveSection(name);
        if (w !== null) {
            root.group = w.hub;
            const t = Object.assign({}, root.lastTab);
            t[w.hub] = name;
            root.lastTab = t;
        }
        Settings.more = false;
        root.section = name;
        swapAnim.restart();
    }

    function openHub(key: string): void {
        const h = root.shownSections.find(x => x.key === key);
        if (h === undefined)
            return;
        const last = root.lastTab[key];
        root.go(h.tabs.some(t => t.key === last) ? last : h.tabs[0].key);
    }

    function pickSetting(entry: var): void {
        root.query = "";
        root.pending = entry.key;
        const same = root.shownSection === entry.tab && root.section === entry.tab;
        root.go(entry.tab);
        if (entry.advanced && Settings.values.settings.detail === "simple")
            Settings.more = true;
        if (same)
            root.revealRequested();
    }

    function state(): var {
        return {
            open: root.wanted,
            hub: root.hub,
            tab: root.section,
            query: root.query,
            detail: Settings.values.settings.detail,
            undo: Settings.undoStack.length
        };
    }

    function back(): void {
        if (root.section !== "")
            root.go("");
        else
            root.close();
    }

    function showSection(name: string): void {
        if (name !== "" && root.sectionInfo(name) === null && root.shownSections.some(h => h.key === name))
            root.openHub(name);
        else
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

            readonly property bool roomy: win.width >= 1200
            readonly property real side: win.roomy ? Math.min(400, Math.max(300, width * 0.17)) : 0
            readonly property real gutter: Math.max(24, width * 0.018)
            readonly property real midX: win.roomy ? win.gutter * 2 + win.side : win.gutter
            readonly property real midW: win.roomy ? win.width - (win.gutter * 2 + win.side) * 2 : win.width - win.gutter * 2

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
                    if (root.pending !== "")
                        revealTimer.restart();
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
                Keys.onTabPressed: event => root.step(event.modifiers & Qt.ShiftModifier ? -1 : 1)
                Keys.onBacktabPressed: root.step(-1)
                Keys.onReturnPressed: {
                    if (root.hovered >= 0 && root.hovered < root.shownSections.length)
                        root.openHub(root.shownSections[root.hovered].key);
                }
                Keys.onPressed: event => {
                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
                        Settings.undo();
                        event.accepted = true;
                        return;
                    }
                    if (event.text.length !== 1 || event.text.charCodeAt(0) <= 32 || event.text.charCodeAt(0) === 127 || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
                        return;
                    if (root.section !== "")
                        root.go("");
                    search.text = search.text + event.text;
                    search.focusInput();
                    event.accepted = true;
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
                property real hush: root.query.trim() !== "" ? 1 : 0
                anchors.fill: parent
                opacity: root.phase(0.1, 0.5) * (1 - 0.2 * root.dive) * (1 - 0.88 * hub.hush)
                enabled: hub.hush < 0.5

                Behavior on hush {
                    NumberAnimation {
                        duration: Tokens.stateDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.enterCurve
                    }
                }

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
                        readonly property bool on: root.hovered === link.index || root.hub === link.modelData.key
                        anchors.fill: parent
                        opacity: root.phase(0.35, 0.8) * (link.on ? 0.85 : 0.14)
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
                        readonly property bool on: root.hub === star.modelData.key
                        readonly property bool hot: root.hovered === star.index
                        readonly property real arrive: root.phase(0.25 + 0.4 * star.index / root.shownSections.length, 0.65 + 0.3 * star.index / root.shownSections.length)
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
                            onClicked: root.openHub(star.modelData.key)
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
                text: root.hovered >= 0 && root.hovered < root.shownSections.length ? "Open " + root.shownSections[root.hovered].label.toLowerCase() : "Pick a star, or start typing to search"
                color: Theme.textSoft
                font.family: Tokens.fontUi
                font.pixelSize: 20
            }

            TextBox {
                id: search
                x: hub.cx - width / 2
                y: win.height * 0.5 - hub.ry - 150
                width: Math.min(win.midW - 40, 560)
                visible: root.dive < 0.99
                opacity: root.phase(0.4, 0.9) * (1 - root.dive)
                placeholder: "Search settings"
                onTextChanged: root.query = text
                onAccepted: results.accept()
                Keys.onUpPressed: results.step(-1)
                Keys.onDownPressed: results.step(1)
                Keys.onEscapePressed: {
                    if (search.text !== "")
                        search.text = "";
                    else
                        root.back();
                    keys.forceActiveFocus();
                }

                Connections {
                    target: root
                    function onQueryChanged(): void {
                        if (search.text !== root.query)
                            search.text = root.query;
                        if (root.query === "" && !keys.activeFocus)
                            keys.forceActiveFocus();
                    }
                }
            }

            SearchResults {
                id: results
                x: search.x
                y: search.y + search.height + 14
                width: search.width
                visible: root.query.trim() !== "" && root.dive < 0.99
                opacity: hub.hush
                query: root.query
                onPicked: entry => root.pickSetting(entry)
            }

            SidePanel {
                id: leftPanel
                visible: win.roomy
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
                visible: win.roomy
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
                    onReload: Stack.reload(false)
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
                    role: "settings"
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
                    opacity: root.hubInfo === null ? root.swap : 1

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.hubInfo !== null ? root.hubInfo.glyph : root.shownSection === "" ? "" : root.sectionInfo(root.shownSection).glyph
                        size: 24
                        color: Theme.accent
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.hubInfo !== null ? root.hubInfo.label : root.shownSection === "" ? "" : root.sectionInfo(root.shownSection).label
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

                Segmented {
                    id: tabs
                    x: 30
                    y: sheetHead.y + sheetHead.height + 18
                    width: Math.min(parent.width - 60 - detail.width - 16, 128 * Math.max(1, tabs.options.length))
                    options: root.hubInfo === null ? [] : root.hubInfo.tabs.map(t => ({
                                key: t.key,
                                label: t.label
                            }))
                    current: root.section
                    onPicked: key => root.go(key)
                }

                Chip {
                    id: detail
                    anchors.right: parent.right
                    anchors.rightMargin: 30
                    y: tabs.y + (tabs.height - height) / 2
                    text: "All options"
                    lit: Settings.values.settings.detail === "full"
                    onClicked: Settings.set("settings.detail", Settings.values.settings.detail === "full" ? "simple" : "full")
                }

                Flickable {
                    id: content
                    x: 30
                    y: tabs.y + tabs.height + 22
                    width: parent.width - 60
                    height: parent.height - y - 20
                    clip: true
                    contentHeight: pageColumn.implicitHeight + 20
                    boundsBehavior: Flickable.StopAtBounds
                    opacity: root.swap

                    Column {
                        id: pageColumn
                        width: content.width
                        y: (1 - root.swap) * 18

                        Loader {
                            id: page
                            width: content.width
                            sourceComponent: ({
                                    general: generalPage,
                                    look: lookPage,
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
                                    archive: archivePage,
                                    island: islandPage,
                                    capture: capturePage,
                                    access: accessPage,
                                    plugins: pluginsPage,
                                    sync: syncPage,
                                    keybinds: keybindsPage,
                                    commands: commandsPage
                                })[root.shownSection] || null
                        }

                        MoreOptions {
                            tab: root.shownSection
                        }
                    }
                }
            }

            UndoToast {
                x: (win.width - width) / 2
                y: win.height - height - win.gutter - 8
            }

            Timer {
                id: revealTimer
                interval: Tokens.enterDuration + 60
                onTriggered: win.revealPending()
            }

            Connections {
                target: root
                function onRevealRequested(): void {
                    revealTimer.restart();
                }
            }

            function findRow(item: var, key: string): var {
                if (!item)
                    return null;
                if (item.key === key && item.modified !== undefined && item.visible)
                    return item;
                for (let i = 0; i < item.children.length; i++) {
                    const r = win.findRow(item.children[i], key);
                    if (r !== null)
                        return r;
                }
                return null;
            }

            function revealPending(): void {
                if (root.pending === "")
                    return;
                const row = win.findRow(page.item, root.pending);
                if (row !== null) {
                    const p = row.mapToItem(pageColumn, 0, 0);
                    content.contentY = Math.max(0, Math.min(Math.max(0, content.contentHeight - content.height), p.y - content.height / 3));
                }
                Settings.focusKey = "";
                Settings.focusKey = root.pending;
                root.pending = "";
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
        id: archivePage

        ArchivePage {}
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
        id: lookPage

        LookPage {
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
