import QtQuick
import QtQuick.Effects
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
    property var tapAt: null
    readonly property var frame: M.openFrame(Tokens.openStyle, root.phase, root.placed, {
        origin: root.tapAt,
        emerging: root.from !== "",
        reduced: Tokens.motion < 0.05
    })

    signal opened
    signal closed

    function reveal(): void {
        const s = root.screenInfo;
        root.tapAt = s ? M.tapOrigin(Tokens.tap, {
            name: s.name,
            w: s.width,
            h: s.height
        }, M.placedRect(root.placed, s.width, s.height, root.panelWidth, Math.min(root.panelHeight, root.room), Tokens.edgeMargin), Date.now()) : null;
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

    onShownChanged: Sounds.play(root.shown ? "open" : "close")

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
            readonly property var visual: M.frameRect(0, 0, win.width, win.height, root.frame)

            Region {
                id: blur
                x: Math.round(win.visual.x) + 1
                y: Math.round(win.visual.y) + 1
                width: Math.round(win.visual.w) - 2
                height: Math.round(win.visual.h) - 2
                radius: Tokens.blur(root.radius) * root.frame.sx - 1
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
                opacity: root.frame.opacity
                focus: true
                Keys.onEscapePressed: root.close()
                layer.enabled: root.frame.blur > 0.01 && panel.GraphicsInfo.api !== GraphicsInfo.Software && panel.GraphicsInfo.api !== GraphicsInfo.Unknown
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: root.frame.blur
                    blurMax: 48
                }

                transform: [
                    Translate {
                        x: root.frame.dx
                        y: root.frame.dy
                    },
                    Scale {
                        origin.x: panel.width * root.frame.ox
                        origin.y: panel.height * root.frame.oy
                        xScale: root.frame.sx
                        yScale: root.frame.sy
                    },
                    Rotation {
                        origin.x: panel.width * root.frame.ox
                        origin.y: panel.height * root.frame.oy
                        axis.x: 1
                        axis.y: 0
                        axis.z: 0
                        angle: root.frame.angle
                    }
                ]

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
