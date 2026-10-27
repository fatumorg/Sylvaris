import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../lib/motion.mjs" as M
import "../lib/bar.mjs" as B
import "../lib/screens.mjs" as Sc

Scope {
    id: root

    property bool shown: false
    property bool wanted: false
    property string view: "compact"
    property string focusKey: ""
    property var screenInfo: null
    property string from: ""
    property real fromInset: 0
    property real phase: 0
    property bool settled: true
    readonly property bool live: root.shown || root.phase > 0
    property var detailItem: null
    readonly property string placed: root.corner
    readonly property int panelWidth: root.expanded ? Tokens.centerExpandedWidth : Tokens.centerCompactWidth
    readonly property int room: root.screenInfo ? Math.max(1, Sc.roomHeight(root.screenInfo.height, root.local.parts.bar ? root.local.bar : null, Tokens.barHeight, Tokens.barMargin, Tokens.edgeMargin) - Math.round(root.fromInset)) : Tokens.centerHeight
    readonly property int panelHeight: Math.min(Tokens.centerHeight, root.room)
    readonly property real grow: M.grow(root.phase, root.from !== "")
    readonly property var local: Settings.at(root.screenInfo ? root.screenInfo.name : Compositor.focusedName())
    readonly property string corner: root.from !== "" ? root.from : B.placeCorner(root.local.center.corner, root.local.parts.bar ? root.local.bar.position : "top")
    readonly property var origin: M.origin(root.corner)
    readonly property bool expanded: root.view !== "compact"
    signal partRequested(string name)

    property var peers: ({})

    readonly property var views: ["compact", "orbit-bluetooth", "orbit-wifi", "calendar", "outputs", "displays", "hotspot"]

    function applyView(name: string): void {
        const i = name.indexOf(":");
        const v = i < 0 ? name : name.slice(0, i);
        root.view = root.views.indexOf(v) >= 0 ? v : "compact";
        root.focusKey = i < 0 ? "" : name.slice(i + 1);
    }

    function showOn(screen: var, initial: string): void {
        if (!root.shown) {
            root.settled = false;
            if (root.screenInfo !== screen)
                root.phase = 0;
        }
        root.screenInfo = screen;
        root.applyView(initial);
        if (!root.shown) {
            root.shown = true;
            exitAnim.stop();
            enterAnim.restart();
            Qt.callLater(() => root.settled = true);
        }
        Dnd.refresh();
        Toggles.refresh();
        Hotspot.refresh();
        BluetoothService.refreshProfiles();
        Displays.refresh();
        VirtualDisplay.refresh();
    }

    function show(initial: string): void {
        root.wanted = true;
        root.from = "";
        root.fromInset = 0;
        Compositor.refresh(() => {
            if (root.wanted)
                root.showOn(Compositor.screenFor(Compositor.focusedName()), initial);
        });
    }

    function toggleOn(screen: var, initial: string): void {
        if (root.wanted && (initial === "" || root.view === initial.split(":")[0])) {
            root.close();
            return;
        }
        root.wanted = true;
        root.from = "";
        root.fromInset = 0;
        root.showOn(screen, initial === "" ? "compact" : initial);
    }

    function toggleFrom(screen: var, from: string, inset: real): void {
        root.toggleOn(screen, "");
        if (root.wanted) {
            root.from = from;
            root.fromInset = inset;
        }
    }

    function open(): void {
        if (!root.wanted)
            root.show("compact");
    }

    function close(): void {
        root.wanted = false;
        if (!root.shown)
            return;
        root.shown = false;
        enterAnim.stop();
        exitAnim.restart();
    }

    function handOff(name: string): void {
        root.close();
        root.partRequested(name);
    }

    function toggle(): void {
        if (root.wanted)
            root.close();
        else
            root.open();
    }

    function setView(name: string): void {
        if (root.wanted && root.shown)
            root.applyView(name);
        else
            root.show(name);
    }

    function back(): void {
        if (root.detailItem !== null && typeof root.detailItem.back === "function" && root.detailItem.back())
            return;
        if (root.expanded)
            root.applyView("compact");
        else
            root.close();
    }

    function componentFor(v: string): var {
        if (v === "orbit-bluetooth" || v === "orbit-wifi")
            return orbitView;
        if (v === "calendar")
            return calendarView;
        if (v === "outputs")
            return outputsView;
        if (v === "hotspot")
            return hotspotView;
        if (v === "displays")
            return displaysView;
        return null;
    }

    NumberAnimation {
        id: enterAnim
        target: root
        property: "phase"
        to: 1
        duration: Tokens.enterDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.enterCurve
    }

    NumberAnimation {
        id: exitAnim
        target: root
        property: "phase"
        to: 0
        duration: Tokens.exitDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.exitCurve
        onFinished: {
            if (!root.shown) {
                root.settled = false;
                root.view = "compact";
                root.focusKey = "";
                Qt.callLater(() => root.settled = true);
            }
        }
    }

    Component {
        id: orbitView

        OrbitView {
            mode: root.view === "orbit-wifi" ? "wifi" : "bluetooth"
            initialFocus: root.focusKey
            onModeRequested: m => root.applyView("orbit-" + m)
            onCloseRequested: root.applyView("compact")
        }
    }

    Component {
        id: calendarView

        CalendarView {
            onCloseRequested: root.applyView("compact")
        }
    }

    Component {
        id: outputsView

        OutputsView {
            onCloseRequested: root.applyView("compact")
        }
    }

    Component {
        id: hotspotView

        HotspotView {
            onCloseRequested: root.applyView("compact")
        }
    }

    Component {
        id: displaysView

        DisplaysView {
            onCloseRequested: root.applyView("compact")
        }
    }

    onLiveChanged: {
        if (!root.live)
            keep.restart();
    }

    Timer {
        id: keep
        interval: 20000
    }

    LazyLoader {
        active: root.live || keep.running

        PanelWindow {
            id: catcher
            visible: root.shown
            screen: root.screenInfo
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "sylcatcher"

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }
    }

    LazyLoader {
        active: root.live || keep.running

        PanelWindow {
            id: win
            visible: root.live
            screen: root.screenInfo
            anchors {
                top: root.origin.v === 0
                bottom: root.origin.v === 1
                left: root.origin.h === 0
                right: root.origin.h === 1
            }
            margins {
                top: Tokens.edgeMargin + (root.origin.v === 0 ? root.fromInset : 0)
                bottom: Tokens.edgeMargin + (root.origin.v === 1 ? root.fromInset : 0)
                left: Tokens.edgeMargin
                right: Tokens.edgeMargin
            }
            implicitWidth: Tokens.centerExpandedWidth
            implicitHeight: Math.min(Math.max(Tokens.centerHeight, compact.implicitHeight), root.room)
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sylcenter"
            WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            mask: Region {
                width: root.shown ? win.width : 0
                height: root.shown ? win.height : 0
            }
            BackgroundEffect.blurRegion: Resin.enabled && root.phase > 0.02 ? blur : null

            Region {
                id: blur
                readonly property var r: M.scaledRect(panel.x, panel.y, panel.width, panel.height, root.corner, root.grow, (1 - root.phase) * 10 * M.rise(root.corner))
                x: Math.round(blur.r.x) + 1
                y: Math.round(blur.r.y) + 1
                width: Math.round(blur.r.w) - 2
                height: Math.round(blur.r.h) - 2
                radius: Tokens.radiusPanel * root.grow - 1
            }

            onVisibleChanged: {
                if (!visible)
                    return;
                panel.forceActiveFocus();
                if (Stack.env("SYLVARIS_TRACE") === "1")
                    console.log("SYLVARIS_SHOWN " + Date.now());
            }
            Component.onCompleted: {
                if (!visible)
                    return;
                panel.forceActiveFocus();
                if (Stack.env("SYLVARIS_TRACE") === "1")
                    console.log("SYLVARIS_SHOWN " + Date.now());
            }

            Item {
                id: panel

                width: root.expanded ? Tokens.centerExpandedWidth : Tokens.centerCompactWidth
                height: Math.min(root.expanded ? Tokens.centerHeight : compact.implicitHeight, root.room)
                x: (win.width - width) * root.origin.h
                y: (win.height - height) * root.origin.v
                opacity: Math.min(1, root.phase * 1.6)
                scale: root.grow
                transformOrigin: [[Item.TopLeft, Item.Top, Item.TopRight], [Item.Left, Item.Center, Item.Right], [Item.BottomLeft, Item.Bottom, Item.BottomRight]][root.origin.v * 2][root.origin.h * 2]
                focus: true
                clip: true
                Keys.onEscapePressed: root.back()

                transform: Translate {
                    y: (1 - root.phase) * 10 * M.rise(root.corner)
                }

                Behavior on width {
                    enabled: root.settled
                    NumberAnimation {
                        duration: Tokens.morphDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.morphCurve
                    }
                }

                Behavior on height {
                    enabled: root.settled
                    NumberAnimation {
                        duration: Tokens.morphDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.morphCurve
                    }
                }

                Glass {
                    anchors.fill: parent
                    radius: Tokens.radiusPanel
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                Flickable {
                    width: Tokens.centerCompactWidth
                    height: panel.height
                    x: (panel.width - width) * root.origin.h
                    contentHeight: compact.implicitHeight
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    opacity: root.expanded ? 0 : 1
                    visible: opacity > 0
                    enabled: !root.expanded

                    Behavior on opacity {
                        enabled: root.settled
                        NumberAnimation {
                            duration: Tokens.fadeDuration
                        }
                    }

                    CompactView {
                        id: compact
                        width: Tokens.centerCompactWidth
                        peers: root.peers
                        onOpenView: name => name === "theme" || name === "media" || name === "settings" ? root.handOff(name) : root.applyView(name)
                        onDismiss: root.close()
                    }
                }

                Loader {
                    id: detail
                    anchors.fill: parent
                    active: root.expanded
                    onItemChanged: root.detailItem = item
                    Component.onDestruction: root.detailItem = null
                    opacity: root.expanded ? 1 : 0
                    sourceComponent: root.componentFor(root.view)

                    Behavior on opacity {
                        enabled: root.settled
                        NumberAnimation {
                            duration: Tokens.fadeDuration
                        }
                    }
                }
            }
        }
    }
}
