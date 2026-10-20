import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.components
import "../lib/switch.mjs" as W

Scope {
    id: root

    readonly property var cfg: Settings.values.switcher
    property bool shown: false
    property bool wanted: false
    property var screenInfo: null
    property real phase: 0
    property int selected: -1
    property var order: []
    property var list: []
    property var pending: null
    readonly property bool previews: root.cfg.previews && Compositor.can("previews") && !Demo.enabled
    readonly property bool live: root.shown || root.phase > 0

    signal opened

    function entry(appId: string): var {
        if (Demo.enabled)
            return Apps.byId(appId);
        return Apps.entry(appId);
    }

    function nameOf(w: var): string {
        const e = root.entry(w.appId);
        return e ? e.name : w.appId;
    }

    function begin(delta: int): void {
        root.list = W.ordered(Compositor.windows, root.order, W.keyOf);
        if (root.list.length === 0)
            return;
        root.wanted = true;
        root.screenInfo = Compositor.screenFor(Compositor.focusedName());
        const base = root.list[0].activated ? 0 : delta > 0 ? -1 : 0;
        root.selected = W.wrap(base, delta, root.list.length);
        root.shown = true;
        outAnim.stop();
        inAnim.restart();
        root.opened();
    }

    function step(delta: int): void {
        if (!root.shown)
            root.begin(delta);
        else
            root.selected = W.wrap(root.selected, delta, root.list.length);
    }

    function commit(): void {
        if (!root.shown)
            return;
        root.pending = root.list[root.selected] || null;
        root.wanted = false;
        root.shown = false;
        inAnim.stop();
        outAnim.stop();
        root.phase = 0;
        focusLater.restart();
    }

    function open(): void {
        root.step(1);
    }

    function close(): void {
        root.wanted = false;
        if (!root.shown)
            return;
        root.shown = false;
        inAnim.stop();
        outAnim.restart();
    }

    function toggle(): void {
        if (root.shown)
            root.close();
        else
            root.step(1);
    }

    function toggleOn(screen: var): void {
        root.toggle();
    }

    function state(): var {
        return {
            open: root.shown,
            selected: root.selected,
            items: root.list.map(w => ({
                        appId: w.appId,
                        title: w.title
                    }))
        };
    }

    Connections {
        target: Compositor
        function onActiveWindowChanged() {
            const a = Compositor.activeWindow;
            root.order = W.touch(root.order, a === null ? null : W.keyOf(a), Compositor.windows.map(W.keyOf));
        }
    }

    NumberAnimation {
        id: inAnim
        target: root
        property: "phase"
        to: 1
        duration: Math.round(220 * Tokens.pace)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.enterCurve
    }

    NumberAnimation {
        id: outAnim
        target: root
        property: "phase"
        to: 0
        duration: Math.round(140 * Tokens.pace)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.exitCurve
    }

    onLiveChanged: {
        if (!root.live)
            keep.restart();
    }

    Timer {
        id: keep
        interval: 20000
    }

    Timer {
        id: focusLater
        interval: 40
        onTriggered: {
            if (root.pending !== null)
                Compositor.activate(root.pending);
            root.pending = null;
        }
    }

    LazyLoader {
        active: root.live || keep.running

        PanelWindow {
            id: win
            visible: root.live
            screen: root.screenInfo
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: Qt.alpha("#000000", 0.25 * root.phase)
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sylswitch"
            WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: {
                if (visible)
                    keys.forceActiveFocus();
            }
            Component.onCompleted: {
                if (visible)
                    keys.forceActiveFocus();
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            Item {
                id: keys
                focus: true
                Keys.onPressed: event => {
                    const back = event.key === Qt.Key_Backtab || event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Left || event.key === Qt.Key_Up;
                    const fwd = event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_Down;
                    if (back)
                        root.step(-1);
                    else if (fwd)
                        root.step(1);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                        root.commit();
                    else if (event.key === Qt.Key_Escape)
                        root.close();
                    else
                        return;
                    event.accepted = true;
                }
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) {
                        root.commit();
                        event.accepted = true;
                    }
                }
            }

            Item {
                id: panel
                readonly property int cardW: root.cfg.previews ? Tokens.switchCardWidth : Tokens.switchIconCard
                readonly property int cardH: root.cfg.previews ? Math.round(Tokens.switchCardWidth * 0.62) + 58 : Tokens.switchIconCard + (root.cfg.titles ? 30 : 0)
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, strip.contentWidth + 36)
                height: panel.cardH + 36
                opacity: root.phase
                scale: 0.96 + 0.04 * root.phase

                Glass {
                    anchors.fill: parent
                    radius: Tokens.radiusPanel
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                ListView {
                    id: strip
                    anchors.fill: parent
                    anchors.margins: 18
                    clip: true
                    orientation: ListView.Horizontal
                    spacing: 12
                    interactive: false
                    model: root.list
                    currentIndex: root.selected
                    highlightFollowsCurrentItem: false
                    preferredHighlightBegin: width / 2 - panel.cardW / 2
                    preferredHighlightEnd: width / 2 + panel.cardW / 2
                    highlightRangeMode: ListView.ApplyRange
                    highlightMoveDuration: Tokens.moveDuration

                    delegate: Item {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool picked: card.index === root.selected
                        readonly property var app: root.entry(card.modelData.appId)
                        width: panel.cardW
                        height: panel.cardH

                        Glass {
                            anchors.fill: parent
                            radius: Tokens.radiusCard
                            inner: true
                            lit: card.picked
                            hot: cardArea.containsMouse
                        }

                        Item {
                            id: face
                            x: 10
                            y: 10
                            width: parent.width - 20
                            height: root.cfg.previews ? Math.round((parent.width - 20) * 0.62) : parent.width - 20

                            ScreencopyView {
                                id: shot
                                anchors.fill: parent
                                visible: root.previews && card.modelData.handle !== null && shot.hasContent
                                captureSource: root.previews && root.shown ? card.modelData.handle : null
                                live: root.shown
                                constraintSize: Qt.size(face.width, face.height)
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                visible: !shot.visible && appIcon.status !== Image.Ready
                                width: appIcon.width
                                height: width
                                radius: width * 0.28
                                color: card.picked ? Qt.alpha(Theme.onAccent, 0.18) : Theme.accent

                                Text {
                                    textFormat: Text.PlainText
                                    anchors.centerIn: parent
                                    text: root.nameOf(card.modelData).charAt(0).toUpperCase()
                                    color: card.picked ? Theme.onAccent : Theme.base
                                    font.family: Tokens.fontUi
                                    font.pixelSize: parent.height * 0.46
                                    font.weight: Font.DemiBold
                                }
                            }

                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                visible: !shot.visible && status === Image.Ready
                                width: Math.min(parent.width, parent.height) * (root.cfg.previews ? 0.5 : 0.72)
                                height: width
                                source: Apps.icon(card.app)
                                sourceSize.width: width * 2
                                layer.enabled: Tokens.iconTint
                                layer.effect: IconTint {}
                                sourceSize.height: height * 2
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }

                        Image {
                            x: face.x + face.width - width + 6
                            y: face.y + face.height - height + 6
                            visible: shot.visible
                            width: 30
                            height: 30
                            source: Apps.icon(card.app)
                            sourceSize.width: 60
                            layer.enabled: Tokens.iconTint
                            layer.effect: IconTint {}
                            sourceSize.height: 60
                        }

                        Text {
                            textFormat: Text.PlainText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            visible: root.cfg.titles
                            horizontalAlignment: Text.AlignHCenter
                            text: card.modelData.title || root.nameOf(card.modelData)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: card.picked ? Theme.onAccent : Theme.text
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.smallSize
                            font.weight: card.picked ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: root.selected = card.index
                            onClicked: {
                                root.selected = card.index;
                                root.commit();
                            }
                        }
                    }
                }
            }
        }
    }
}
