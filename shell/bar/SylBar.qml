import QtQuick
import SylStack
import qs
import qs.services
import qs.plugins.diver
import qs.plugins.temp
import qs.components
import "../lib/icons.mjs" as Icons
import "../lib/bar.mjs" as B

Scope {
    id: root

    property var screens: Stack.screens
    readonly property var cfg: Settings.at(root.screens.length === 1 ? root.screens[0].name : "").bar
    readonly property string position: root.cfg.position
    readonly property bool vertical: B.vertical(root.position)
    readonly property string style: root.cfg.style
    readonly property bool islands: root.style === "islands"
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice.isLaptopBattery
    property var open: ({})
    property date now: new Date()

    signal request(string part, string arg, var screen)

    function moduleFor(name: string): var {
        return ({
                pad: padModule,
                workspaces: workspacesModule,
                window: windowModule,
                clock: clockModule,
                media: mediaModule,
                tray: trayModule,
                audio: audioModule,
                network: networkModule,
                bluetooth: bluetoothModule,
                battery: batteryModule,
                notifications: notificationsModule,
                center: centerModule,
                power: powerModule,
                diver: diverModule,
                temp: tempModule
            })[name] || (name.indexOf("plugin:") === 0 ? pluginModule : null);
    }

    function isOpen(part: string, screen: var): bool {
        const s = root.open[part];
        return s !== undefined && s !== null && screen !== null && s === screen.name;
    }

    Timer {
        interval: 1000
        running: root.cfg.enabled
        repeat: true
        onTriggered: root.now = new Date()
    }

    Variants {
        model: root.cfg.enabled ? root.screens : []

        delegate: PanelWindow {
            id: bar

            required property var modelData
            readonly property bool floating: root.cfg.floating || root.style === "float"
            readonly property real inset: root.style === "float" ? Tokens.barHeight / 4 : 0
            readonly property int gap: bar.floating ? Tokens.barMargin : 0
            readonly property var groups: [startGroup, middleGroup, endGroup]

            screen: modelData
            anchors {
                top: root.position !== "bottom"
                bottom: root.position !== "top"
                left: root.position !== "right"
                right: root.position !== "left"
            }
            margins {
                top: root.position === "bottom" ? 0 : bar.gap
                bottom: root.position === "top" ? 0 : bar.gap
                left: root.position === "right" ? 0 : bar.gap
                right: root.position === "left" ? 0 : bar.gap
            }
            implicitHeight: Tokens.barHeight
            implicitWidth: Tokens.barHeight
            color: "transparent"
            exclusionMode: ExclusionMode.Auto
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "sylbar"
            BackgroundEffect.blurRegion: Resin.enabled ? blur : null

            Region {
                id: blur
                regions: root.islands ? bar.groups.filter(g => g.visible).map(g => g.blur) : root.style === "minimal" ? [] : [slabBlur]
            }

            Region {
                id: slabBlur
                x: bar.floating ? 1 : 0
                y: bar.floating ? 1 : 0
                width: slab.width - (bar.floating ? 2 : 0)
                height: slab.height - (bar.floating ? 2 : 0)
                radius: bar.floating ? Tokens.blur(slab.radius) - 1 : 0
            }

            Glass {
                role: "bar"
                id: slab
                anchors.fill: parent
                visible: root.style === "slab" || root.style === "float"
                flowing: false
                radius: root.style === "float" ? Math.min(width, height) / 2 : bar.floating ? Tokens.barRadius : 0
                offColor: Theme.surface
                offBorder: Theme.line
            }

            Rectangle {
                visible: root.style === "minimal"
                x: root.position === "left" ? parent.width - 1 : 0
                y: root.position === "top" ? parent.height - 1 : 0
                width: root.vertical ? 1 : parent.width
                height: root.vertical ? parent.height : 1
                color: Theme.line
            }

            BarGroup {
                id: startGroup
                list: root.cfg.left
                side: "left"
                islands: root.islands
                vertical: root.vertical
                barWindow: bar
                x: root.vertical ? (parent.width - width) / 2 : root.islands ? 0 : Tokens.barPadding + bar.inset
                y: root.vertical ? (root.islands ? 0 : Tokens.barPadding + bar.inset) : (parent.height - height) / 2
                moduleFor: root.moduleFor
            }

            BarGroup {
                id: middleGroup
                readonly property real slot: root.vertical
                    ? B.middleSlot(parent.height, startGroup.visible ? startGroup.y + startGroup.height : 0, height, endGroup.visible ? parent.height - endGroup.y : 0, Tokens.gap)
                    : B.middleSlot(parent.width, startGroup.visible ? startGroup.x + startGroup.width : 0, width, endGroup.visible ? parent.width - endGroup.x : 0, Tokens.gap)
                list: root.cfg.center
                side: "center"
                islands: root.islands
                vertical: root.vertical
                barWindow: bar
                room: slot >= 0
                x: root.vertical ? (parent.width - width) / 2 : Math.max(0, slot)
                y: root.vertical ? Math.max(0, slot) : (parent.height - height) / 2
                moduleFor: root.moduleFor
            }

            BarGroup {
                id: endGroup
                list: root.cfg.right
                side: "right"
                islands: root.islands
                vertical: root.vertical
                barWindow: bar
                x: root.vertical ? (parent.width - width) / 2 : parent.width - width - (root.islands ? 0 : Tokens.barPadding + bar.inset)
                y: root.vertical ? parent.height - height - (root.islands ? 0 : Tokens.barPadding + bar.inset) : (parent.height - height) / 2
                moduleFor: root.moduleFor
            }
        }
    }

    Component {
        id: padModule

        BarButton {
            property var screenRef: null
            property var win: null
            glyph: Icons.GLYPHS.apps
            lit: root.isOpen("pad", screenRef)
            onClicked: root.request("pad", "", screenRef)
        }
    }

    Component {
        id: pluginModule

        Item {
            id: pm
            property var screenRef: null
            property var win: null
            property string moduleName: ""
            readonly property var plugin: pm.moduleName === "" ? null : Plugins.byId(pm.moduleName.slice(7))
            property bool wanted: pm.plugin !== null && pm.plugin.manifest.kind === "bar" && Plugins.isEnabled(pm.plugin.id)
            implicitWidth: slot.item ? slot.item.implicitWidth : 0
            implicitHeight: Tokens.barItemHeight

            Loader {
                id: slot
                anchors.centerIn: parent
                active: pm.wanted
                source: pm.wanted ? Plugins.url(pm.plugin) : ""
                onLoaded: {
                    if (item.hasOwnProperty("api"))
                        item.api = Plugins.api(pm.plugin.id);
                }
            }
        }
    }

    Component {
        id: workspacesModule

        Item {
            id: ws
            property var screenRef: null
            property var win: null
            readonly property var list: Compositor.workspaces.filter(w => ws.screenRef !== null && w.output === ws.screenRef.name)
            readonly property var look: B.workspaceLook(root.cfg.workspaceIcons, Theme.theme.workspaceIcon || "")
            readonly property string shape: root.cfg.workspaceStyle
            implicitWidth: root.vertical ? Tokens.barItemHeight : pills.implicitWidth + 12
            implicitHeight: root.vertical ? pills.implicitHeight + 12 : Tokens.barItemHeight
            property bool wanted: ws.list.length > 0

            MouseArea {
                anchors.fill: parent
                onWheel: event => {
                    const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    if (d !== 0)
                        Compositor.run("workspace", [d > 0 ? "prev" : "next"]);
                }
            }

            Grid {
                id: pills
                anchors.centerIn: parent
                rows: root.vertical ? -1 : 1
                columns: root.vertical ? 1 : -1
                spacing: 5
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter

                Repeater {
                    model: ws.list.length

                    delegate: Item {
                        id: pill
                        required property int index
                        readonly property var modelData: ws.list[pill.index] || ({
                                name: "",
                                index: 0,
                                focused: false,
                                active: false,
                                urgent: false,
                                windows: 0,
                                apps: []
                            })
                        readonly property bool on: modelData.focused
                        readonly property var apps: pill.on && ws.shape === "pills" || ws.shape === "icons" ? B.workspaceApps(modelData.apps, 3) : ({
                                shown: [],
                                more: 0
                            })
                        readonly property int ticks: pill.on || ws.shape === "dots" || ws.shape === "icons" ? 0 : B.workspaceTicks(modelData.windows)
                        readonly property bool busy: modelData.windows !== 0 || modelData.active
                        width: ws.shape === "dots" ? (pill.on && !root.vertical ? 22 : 8) : Math.max(26, inner.implicitWidth + (pill.on ? 18 : 10))
                        height: ws.shape === "dots" ? (pill.on && root.vertical ? 22 : 8) : root.vertical ? Math.max(26, inner.implicitHeight + (pill.on ? 18 : 10)) : 26

                        Behavior on width {
                            NumberAnimation {
                                duration: Tokens.moveDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Tokens.springCurve
                            }
                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: Tokens.moveDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Tokens.springCurve
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.min(width, height) / 2
                            antialiasing: true
                            color: ws.shape === "dots" ? (pill.on ? Theme.accent : Qt.alpha(Theme.text, pillArea.containsMouse ? 0.7 : pill.busy ? 0.5 : 0.22)) : pill.on && ws.shape !== "numbers" ? Theme.accent : pillArea.containsMouse ? Qt.alpha(Theme.text, 0.12) : "transparent"
                            border.width: modelData.urgent ? 2 : 0
                            border.color: Theme.danger

                            Behavior on color {
                                ColorAnimation {
                                    duration: Tokens.stateDuration
                                }
                            }
                        }

                        Grid {
                            id: inner
                            visible: ws.shape !== "dots"
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: pill.ticks > 0 && !root.vertical ? -2 : 0
                            rows: root.vertical ? -1 : 1
                            columns: root.vertical ? 1 : -1
                            spacing: 6
                            horizontalItemAlignment: Grid.AlignHCenter
                            verticalItemAlignment: Grid.AlignVCenter

                            Glyph {
                                visible: ws.look.mode === "glyph" && pill.on && ws.shape === "pills"
                                text: ws.look.glyph
                                size: 15
                                color: Theme.onAccent
                            }

                            Rectangle {
                                visible: ws.look.mode === "dots" && !pill.on && ws.shape === "pills"
                                width: 8
                                height: 8
                                radius: Tokens.r(4)
                                color: modelData.active ? Theme.accentHi : Theme.text
                                opacity: pill.busy ? 1 : 0.35
                            }

                            Text {
                                textFormat: Text.PlainText
                                id: num
                                visible: ws.shape === "numbers" || (ws.shape === "icons" ? pill.apps.shown.length === 0 : ws.look.mode !== "dots" || pill.on)
                                text: modelData.name.length <= 3 && modelData.name !== "" ? modelData.name : modelData.index
                                color: pill.on ? (ws.shape === "numbers" ? Theme.accent : Theme.onAccent) : modelData.active ? Theme.accentHi : Theme.text
                                opacity: pill.on || pill.busy ? 1 : 0.4
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.smallSize
                                font.weight: pill.on ? Font.Bold : Font.DemiBold
                                transform: Translate {
                                    x: numInk.advanceWidth / 2 - numInk.tightBoundingRect.x - numInk.tightBoundingRect.width / 2
                                }

                                TextMetrics {
                                    id: numInk
                                    font: num.font
                                    text: num.text
                                }
                            }

                            Repeater {
                                model: pill.apps.shown

                                delegate: Item {
                                    id: appIcon
                                    required property string modelData
                                    readonly property var entry: Apps.entry(modelData)
                                    readonly property string icon: entry !== null && entry.icon ? Stack.iconPath(entry.icon, true) : ""
                                    visible: icon !== ""
                                    width: 20
                                    height: 20

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: Tokens.iconTint
                                        radius: width / 2
                                        antialiasing: true
                                        color: Qt.alpha(Theme.onAccent, 0.85)
                                    }

                                    IconImage {
                                        anchors.centerIn: parent
                                        implicitSize: Tokens.iconTint ? 13 : 18
                                        source: appIcon.icon
                                        layer.enabled: Tokens.iconTint
                                        layer.effect: IconTint {}
                                    }
                                }
                            }

                            Text {
                                textFormat: Text.PlainText
                                visible: pill.apps.more > 0
                                text: "+" + pill.apps.more
                                color: pill.on ? Theme.onAccent : Theme.text
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.tinySize
                                font.weight: Font.Bold
                            }
                        }

                        Row {
                            anchors.horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                            anchors.bottom: root.vertical ? undefined : parent.bottom
                            anchors.bottomMargin: 3
                            anchors.verticalCenter: root.vertical ? parent.verticalCenter : undefined
                            anchors.right: root.vertical ? parent.right : undefined
                            anchors.rightMargin: 2
                            spacing: 2
                            visible: pill.ticks > 0

                            Repeater {
                                model: pill.ticks

                                delegate: Rectangle {
                                    width: 3
                                    height: 3
                                    radius: 1.5
                                    color: pill.modelData.active ? Theme.accentHi : Theme.accent
                                }
                            }
                        }

                        MouseArea {
                            id: pillArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Compositor.focusWorkspace(pill.modelData)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: windowModule

        Item {
            id: wm
            property var screenRef: null
            property var win: null
            property var active: null
            property var parked: null
            property string title: ""
            readonly property bool parkedAlive: wm.parked !== null && Compositor.windows.some(w => w.handle === wm.parked.handle)
            readonly property bool resting: wm.active !== null && wm.parked !== null && wm.active.handle === wm.parked.handle && Compositor.activeWindow === null
            readonly property var entry: wm.active === null ? null : Apps.entry(wm.active.appId)
            implicitWidth: wm.active === null ? 0 : Math.ceil((Math.min(titleRow.implicitWidth, Tokens.barTitleMax) + 12) / 24) * 24
            implicitHeight: Tokens.barItemHeight
            property bool wanted: !root.vertical && wm.active !== null && wm.title !== ""

            function settle(force: bool): void {
                const next = Compositor.activeWindow !== null ? Compositor.activeWindow : wm.parkedAlive ? wm.parked : null;
                if (next === null && wm.active !== null && !force) {
                    holdTimer.restart();
                    return;
                }
                holdTimer.stop();
                wm.active = next;
                wm.title = next === null ? "" : next.title;
            }

            Component.onCompleted: wm.settle(true)

            Connections {
                target: Compositor
                function onActiveWindowChanged() {
                    settleTimer.restart();
                }
            }

            Timer {
                id: settleTimer
                interval: 120
                onTriggered: wm.settle(false)
            }

            Timer {
                id: holdTimer
                interval: 450
                onTriggered: wm.settle(true)
            }

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Tokens.moveDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.morphCurve
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (wm.resting) {
                        Compositor.restore(wm.parked);
                        wm.parked = null;
                    } else if (wm.active !== null) {
                        wm.parked = wm.active;
                        Compositor.minimize(wm.active);
                    }
                    settleTimer.restart();
                }
            }

            Row {
                id: titleRow
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                opacity: wm.resting ? 0.5 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.stateDuration
                    }
                }

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 18
                    source: wm.entry !== null && wm.entry.icon ? Stack.iconPath(wm.entry.icon, true) : ""
                    visible: source !== ""
                    layer.enabled: Tokens.iconTint
                    layer.effect: IconTint {}
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, Tokens.barTitleMax - 26)
                    text: wm.title
                    elide: Text.ElideRight
                    color: Theme.textSoft
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.barText
                }
            }
        }
    }

    Component {
        id: clockModule

        BarButton {
            id: clockButton
            property var screenRef: null
            property var win: null
            label: root.vertical ? "" : Qt.formatDate(root.now, "ddd d MMM")
            implicitHeight: root.vertical ? stack.implicitHeight + 16 : Tokens.barItemHeight
            width: root.vertical ? Tokens.barItemHeight : Math.max(implicitWidth, implicitHeight)

            Digits {
                visible: !root.vertical
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatTime(root.now, "HH:mm")
                color: clockButton.lit ? Theme.onAccent : Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.barText
                font.weight: Font.Medium
                font.features: {
                    "tnum": 1
                }
            }

            Column {
                id: stack
                visible: root.vertical
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Digits {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(root.now, "HH")
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.barText + 3
                    font.weight: Font.Bold
                    font.features: {
                        "tnum": 1
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 12
                    height: 2
                    radius: Tokens.r(1)
                    color: Theme.accent
                }

                Digits {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(root.now, "mm")
                    color: Theme.textSoft
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.barText + 1
                    font.weight: Font.Medium
                    font.features: {
                        "tnum": 1
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 2
                    text: Qt.formatDate(root.now, "ddd").slice(0, 2) + "\n" + Qt.formatDate(root.now, "d")
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 0.9
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }
            }
            lit: root.isOpen("clock", screenRef)
            onClicked: root.request("clock", "", screenRef)
        }
    }

    Component {
        id: mediaModule

        BarButton {
            property var screenRef: null
            property var win: null
            property bool wanted: Media.available && Media.title !== ""
            compact: root.vertical
            glyph: Media.playing ? Icons.GLYPHS.pause : Icons.GLYPHS.play
            tint: Theme.accent

            Text {
                textFormat: Text.PlainText
                visible: !root.vertical
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Tokens.barMediaMax)
                text: Media.title + (Media.artist !== "" ? "  ·  " + Media.artist : "")
                elide: Text.ElideRight
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.barText
            }

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    root.request("media", "", screenRef);
                else if (mouse.button === Qt.MiddleButton)
                    Media.next();
                else
                    Media.toggle();
            }
            onWheel: steps => steps > 0 ? Media.previous() : Media.next()
        }
    }

    Component {
        id: trayModule

        BarButton {
            id: trayButton
            property var screenRef: null
            property var win: null
            readonly property int count: SystemTray.items.values.length
            property bool wanted: trayButton.count > 0
            glyph: Icons.GLYPHS[{
                    down: "chevronDown",
                    up: "chevronUp",
                    left: "chevronLeft",
                    right: "chevronRight"
                }[B.drawerArrow(root.position)]]
            lit: drawer.visible
            onClicked: drawer.visible = !drawer.visible

            PopupWindow {
                id: drawer

                property real phase: 0
                readonly property int columns: Math.min(5, Math.max(1, trayButton.count))

                anchor.item: trayButton
                anchor.rect.x: root.position === "left" ? trayButton.width + 12 : root.position === "right" ? -12 : 0
                anchor.rect.y: root.position === "top" ? trayButton.height + 12 : root.position === "bottom" ? -12 : 0
                anchor.rect.width: root.vertical ? 1 : trayButton.width
                anchor.rect.height: root.vertical ? trayButton.height : 1
                anchor.edges: root.position === "top" ? Edges.Top : root.position === "bottom" ? Edges.Bottom : root.position === "left" ? Edges.Left : Edges.Right
                anchor.gravity: root.position === "top" ? Edges.Bottom : root.position === "bottom" ? Edges.Top : root.position === "left" ? Edges.Right : Edges.Left
                implicitWidth: trayGrid.implicitWidth + 20
                implicitHeight: trayGrid.implicitHeight + 20
                color: "transparent"
                grabFocus: true
                onVisibleChanged: {
                    if (visible) {
                        drawer.phase = 0;
                        drawerIn.restart();
                    }
                }

                TrayMenu {
                    id: trayMenu
                    anchor.window: drawer
                    onDone: drawer.visible = false
                }

                NumberAnimation {
                    id: drawerIn
                    target: drawer
                    property: "phase"
                    to: 1
                    duration: Tokens.enterDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.enterCurve
                }

                Item {
                    anchors.fill: parent
                    opacity: drawer.phase
                    scale: 0.9 + 0.1 * drawer.phase
                    transformOrigin: root.position === "top" ? Item.Top : root.position === "bottom" ? Item.Bottom : root.position === "left" ? Item.Left : Item.Right

                    Glass {
                        anchors.fill: parent
                        radius: Tokens.radiusCard
                        raised: true
                        offColor: Theme.surface
                        offBorder: Theme.line
                    }

                    Grid {
                        id: trayGrid
                        anchors.centerIn: parent
                        columns: drawer.columns
                        spacing: 4

                        Repeater {
                            model: SystemTray.items

                            delegate: Item {
                                id: trayItem
                                required property var modelData
                                required property int index
                                width: Tokens.barItemHeight + 4
                                height: Tokens.barItemHeight + 4
                                opacity: Math.max(0, Math.min(1, drawer.phase * 3 - trayItem.index * 0.25))

                                Glass {
                                    anchors.fill: parent
                                    radius: Tokens.radiusRow - 2
                                    inner: true
                                    opacity: trayArea.containsMouse ? 1 : 0
                                    offBorder: "transparent"

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Tokens.stateDuration
                                        }
                                    }
                                }

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: 20
                                    source: trayItem.modelData.icon
                                    layer.enabled: Tokens.iconTint
                                    layer.effect: IconTint {}
                                    scale: trayArea.pressed ? 0.85 : trayArea.containsMouse ? 1.1 : 1

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Tokens.stateDuration
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: Tokens.springCurve
                                        }
                                    }
                                }

                                MouseArea {
                                    id: trayArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        const item = trayItem.modelData;
                                        if (mouse.button === Qt.MiddleButton) {
                                            item.secondaryActivate();
                                        } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                                            trayMenu.show(item, trayItem);
                                        } else {
                                            item.activate();
                                            drawer.visible = false;
                                        }
                                    }
                                    onWheel: event => trayItem.modelData.scroll(event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x, event.angleDelta.y === 0)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: audioModule

        BarButton {
            property var screenRef: null
            property var win: null
            property bool wanted: Audio.available
            compact: root.vertical
            glyph: Audio.muted ? Icons.GLYPHS.volumeMute : Icons.GLYPHS.volume
            label: Math.round(Audio.volume * 100) + "%"
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    root.request("center", "outputs", screenRef);
                else
                    Audio.toggleMute();
            }
            onWheel: steps => Audio.setVolume(Audio.volume + steps * 0.05)
        }
    }

    Component {
        id: networkModule

        BarButton {
            property var screenRef: null
            property var win: null
            readonly property var connected: NetworkService.items.filter(i => i.connected)[0] || null
            property bool wanted: NetworkService.available || NetworkService.wiredConnected
            glyph: NetworkService.wiredConnected && connected === null ? Icons.GLYPHS.ethernet : !NetworkService.enabled ? Icons.GLYPHS.wifiOff : connected !== null ? connected.icon : Icons.wifiIcon(0)
            onClicked: root.request("center", "orbit-wifi", screenRef)
        }
    }

    Component {
        id: bluetoothModule

        BarButton {
            property var screenRef: null
            property var win: null
            property bool wanted: BluetoothService.available
            glyph: BluetoothService.enabled ? Icons.GLYPHS.bluetooth : Icons.GLYPHS.bluetoothOff
            tint: BluetoothService.enabled ? Theme.text : Theme.textDim
            onClicked: root.request("center", "orbit-bluetooth", screenRef)
        }
    }

    Component {
        id: batteryModule

        BarButton {
            property var screenRef: null
            property var win: null
            readonly property var device: UPower.displayDevice
            readonly property real percent: device === null ? 0 : device.percentage > 1 ? device.percentage : device.percentage * 100
            property bool wanted: device !== null && device.ready && device.isLaptopBattery
            compact: root.vertical
            glyph: Icons.batteryIcon(percent)
            tint: percent < 15 ? Theme.danger : Theme.text
            label: Math.round(percent) + "%"
        }
    }

    Component {
        id: notificationsModule

        BarButton {
            property var screenRef: null
            property var win: null
            glyph: Dnd.enabled ? Icons.GLYPHS.dnd : Icons.GLYPHS.bell
            badge: Notifications.count
            lit: root.isOpen("notify", screenRef)
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    Dnd.setEnabled(!Dnd.enabled);
                else
                    root.request("notify", "", screenRef);
            }
        }
    }

    Component {
        id: centerModule

        BarButton {
            property var screenRef: null
            property var win: null
            glyph: Icons.GLYPHS.tune
            lit: root.isOpen("center", screenRef)
            onClicked: root.request("center", "", screenRef)
        }
    }

    Component {
        id: powerModule

        BarButton {
            property var screenRef: null
            property var win: null
            glyph: Icons.GLYPHS.power
            lit: root.isOpen("power", screenRef)
            onClicked: root.request("power", "", screenRef)
        }
    }

    Component {
        id: diverModule

        BarButton {
            property var screenRef: null
            property var win: null
            readonly property var n: Diver.next
            readonly property int mins: n === null ? 0 : Math.round((n.start - Diver.now) / 60000)
            property bool wanted: Diver.active
            compact: root.vertical || n === null
            glyph: Diver.alarm !== null ? Icons.GLYPHS.alarm : Icons.GLYPHS.planner
            tint: Diver.alarm !== null || (n !== null && mins <= 10) ? Theme.danger : Theme.text
            label: n === null ? "" : Diver.plain(n.task.text).slice(0, 26) + "  " + (mins <= 0 ? "now" : mins < 60 ? mins + "m" : Qt.formatTime(new Date(n.start), "HH:mm"))
            lit: root.isOpen("clock", screenRef)
            onClicked: root.request("clock", "", screenRef)
        }
    }

    Component {
        id: tempModule

        BarButton {
            id: tempChip
            property var screenRef: null
            property var win: null
            readonly property var hot: Temps.top
            readonly property string me: "bar" + tempChip
            property bool wanted: Temps.enabled
            compact: root.vertical || tempChip.hot === null
            glyph: Icons.GLYPHS.thermometer
            tint: Temps.tone(tempChip.hot)
            label: tempChip.hot === null ? "" : Math.round(tempChip.hot.value) + (tempChip.hot.unit === "°C" ? "°" : "")
            lit: root.isOpen("temp", screenRef)
            onClicked: root.request("temp", "", screenRef)
            onWantedChanged: Temps.want(tempChip.me, tempChip.wanted)
            Component.onCompleted: Temps.want(tempChip.me, tempChip.wanted)
            Component.onDestruction: Temps.want(tempChip.me, false)
        }
    }
}
