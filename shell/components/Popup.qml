import QtQuick
import SylStack
import qs
import qs.services
import "../lib/motion.mjs" as M
import "../lib/bar.mjs" as B
import "../lib/screens.mjs" as Sc

Scope {
    id: root

    property string namespace: "sylpopup"
    property string role: root.namespace.replace(/^syl/, "").replace(/-.*$/, "")
    property string corner: "top-center"
    property string from: ""
    property real fromInset: 0
    readonly property var local: Settings.at(root.screenInfo ? root.screenInfo.name : Compositor.focusedName())
    readonly property string placed: root.from !== "" ? root.from : B.placeCorner(root.corner, root.local.parts.bar ? root.local.bar.position : "top")
    property int panelWidth: Tokens.centerCompactWidth
    property int panelHeight: Tokens.centerHeight
    readonly property int room: root.screenInfo ? Math.max(1, Sc.roomHeight(root.screenInfo.height, root.local.parts.bar ? root.local.bar : null, Tokens.barHeight, Tokens.barMargin, Tokens.edgeMargin) - Math.round(root.fromInset)) : root.panelHeight
    property real radius: Tokens.radiusPanel
    property bool keyboard: true
    property real dim: 0
    property bool shown: false
    property bool wanted: false
    property var screenInfo: null
    property real phase: 0
    property var focusTarget: null
    default property alias content: body.data
    readonly property bool live: root.shown || root.phase > 0
    readonly property real grow: M.grow(root.phase, root.from !== "")

    signal opened
    signal closed

    function originItem(): int {
        const o = M.origin(root.placed);
        const table = [[Item.TopLeft, Item.Top, Item.TopRight], [Item.Left, Item.Center, Item.Right], [Item.BottomLeft, Item.Bottom, Item.BottomRight]];
        return table[o.v * 2][o.h * 2];
    }

    function reveal(): void {
        root.shown = true;
        exitAnim.stop();
        enterAnim.restart();
        root.opened();
    }

    function open(): void {
        if (root.wanted)
            return;
        root.wanted = true;
        root.from = "";
        root.fromInset = 0;
        Compositor.refresh(() => {
            if (!root.wanted)
                return;
            root.screenInfo = Compositor.screenFor(Compositor.focusedName());
            root.reveal();
        });
    }

    function close(): void {
        const was = root.wanted;
        root.wanted = false;
        if (root.shown) {
            root.shown = false;
            enterAnim.stop();
            exitAnim.restart();
        }
        if (was)
            root.closed();
    }

    function toggleOn(screen: var): void {
        if (root.wanted) {
            root.close();
            return;
        }
        root.wanted = true;
        if (root.phase > 0 && root.screenInfo !== screen)
            root.phase = 0;
        root.from = "";
        root.fromInset = 0;
        root.screenInfo = screen;
        root.reveal();
    }

    function toggleFrom(screen: var, from: string, inset: real): void {
        root.toggleOn(screen);
        if (root.wanted) {
            root.from = from;
            root.fromInset = inset;
        }
    }

    function toggle(): void {
        if (root.wanted)
            root.close();
        else
            root.open();
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
    }

    Item {
        id: body
        anchors.fill: parent
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
        active: root.shown || keep.running

        PanelWindow {
            visible: root.shown
            screen: root.screenInfo
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: Qt.alpha("#000000", root.dim * root.phase)
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
                top: root.placed.indexOf("top") === 0
                bottom: root.placed.indexOf("bottom") === 0
                left: root.placed.indexOf("left") > 0
                right: root.placed.indexOf("right") > 0
            }
            margins {
                top: Tokens.edgeMargin + (root.placed.indexOf("top") === 0 ? root.fromInset : 0)
                bottom: Tokens.edgeMargin + (root.placed.indexOf("bottom") === 0 ? root.fromInset : 0)
                left: Tokens.edgeMargin
                right: Tokens.edgeMargin
            }
            implicitWidth: root.panelWidth
            implicitHeight: Math.min(root.panelHeight, root.room)
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: root.namespace
            WlrLayershell.keyboardFocus: root.shown && root.keyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            mask: Region {
                width: root.shown ? win.width : 0
                height: root.shown ? win.height : 0
            }
            BackgroundEffect.blurRegion: Resin.enabled && root.phase > 0.02 ? blur : null
            readonly property var visual: M.scaledRect(0, 0, win.width, win.height, root.placed, root.grow, (1 - root.phase) * 10 * M.rise(root.placed))

            Region {
                id: blur
                x: Math.round(win.visual.x) + 1
                y: Math.round(win.visual.y) + 1
                width: Math.round(win.visual.w) - 2
                height: Math.round(win.visual.h) - 2
                radius: Tokens.blur(root.radius) * root.grow - 1
            }

            function focusIn(): void {
                panel.forceActiveFocus();
                if (root.focusTarget !== null)
                    root.focusTarget.focusInput();
            }

            onVisibleChanged: {
                if (visible)
                    win.focusIn();
            }
            Component.onCompleted: {
                if (visible)
                    win.focusIn();
            }

            Item {
                id: panel

                anchors.fill: parent
                opacity: Math.min(1, root.phase * 1.6)
                scale: root.grow
                transformOrigin: root.originItem()
                focus: true
                Keys.onEscapePressed: root.close()

                transform: Translate {
                    y: (1 - root.phase) * 10 * M.rise(root.placed)
                }

                Glass {
                    role: root.role
                    anchors.fill: parent
                    radius: root.radius
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                Flickable {
                    id: slot
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: Math.max(height, root.panelHeight)
                    interactive: contentHeight > height + 0.5
                    boundsBehavior: Flickable.StopAtBounds
                    clip: interactive
                    Component.onCompleted: body.parent = slot.contentItem
                }
            }
        }
    }
}
