import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import "../lib/notify.mjs" as N
import "../lib/bar.mjs" as B

Scope {
    id: root

    readonly property var local: Settings.at(root.screenInfo ? root.screenInfo.name : Compositor.focusedName())
    readonly property string corner: B.placeCorner(root.local.notifications.corner, root.local.parts.bar ? root.local.bar.position : "top")
    property var screenInfo: null
    property var avoid: null
    readonly property var shift: N.toastShift(root.corner, root.screenInfo ? root.screenInfo.name : "", root.avoid, Tokens.toastGap)
    property var regions: []
    readonly property bool active: Notifications.toasts.length > 0

    function refreshRegions(): void {
        const out = [];
        for (let i = 0; i < cards.count; i++) {
            const item = cards.itemAt(i);
            if (item !== null)
                out.push(item.blur);
        }
        root.regions = out;
    }

    function sync(): void {
        const ids = Notifications.toasts;
        for (let i = toastModel.count - 1; i >= 0; i--) {
            if (ids.indexOf(toastModel.get(i).nid) < 0)
                toastModel.remove(i);
        }
        for (const id of ids) {
            let found = false;
            for (let i = 0; i < toastModel.count; i++) {
                if (toastModel.get(i).nid === id)
                    found = true;
            }
            if (!found)
                toastModel.insert(0, {
                    nid: id
                });
        }
    }

    ListModel {
        id: toastModel
    }

    Connections {
        target: Notifications

        function onToastsChanged() {
            root.sync();
        }
    }

    onActiveChanged: {
        if (root.active)
            root.screenInfo = Compositor.screenFor(Compositor.focusedName());
    }

    PanelWindow {
        visible: root.active
        screen: root.screenInfo
        anchors {
            top: root.corner.indexOf("top") === 0
            bottom: root.corner.indexOf("bottom") === 0
            left: root.corner.indexOf("left") > 0
            right: root.corner.indexOf("right") > 0
        }
        margins {
            top: Tokens.edgeMargin + root.shift.y
            bottom: Tokens.edgeMargin + root.shift.y
            left: Tokens.edgeMargin + root.shift.x
            right: Tokens.edgeMargin + root.shift.x
        }
        implicitWidth: Tokens.toastWidth
        implicitHeight: Math.max(1, stack.implicitHeight)
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sylnotify"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            regions: root.regions
        }
        BackgroundEffect.blurRegion: Resin.enabled ? blurAll : null

        Region {
            id: blurAll
            regions: root.regions
        }

        Column {
            id: stack
            width: parent.width
            spacing: Tokens.toastGap

            move: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: Tokens.stateDuration + 80
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.enterCurve
                }
            }

            Repeater {
                id: cards
                model: toastModel
                onItemAdded: root.refreshRegions()
                onItemRemoved: root.refreshRegions()

                delegate: NotificationCard {
                    id: card
                    required property int nid
                    readonly property Region blur: Region {
                        item: card
                        radius: Tokens.radiusPanel
                    }
                    property real enter: 0

                    width: stack.width
                    height: implicitHeight
                    entry: Notifications.entry(card.nid) || {
                        id: card.nid,
                        time: 0,
                        n: {
                            appName: "",
                            appIcon: "",
                            image: "",
                            summary: "",
                            body: "",
                            actions: [],
                            urgency: 1
                        }
                    }
                    toast: true
                    duration: N.timeoutFor(card.n.urgency, card.n.expireTimeout, Notifications.timeout)
                    scale: 0.96 + 0.04 * card.enter
                    opacity: card.enter * (1 - card.leave)

                    Component.onCompleted: enterAnim.start()

                    NumberAnimation {
                        id: enterAnim
                        target: card
                        property: "enter"
                        from: 0
                        to: 1
                        duration: Tokens.openDuration + 80
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.enterCurve
                    }
                }
            }
        }
    }
}
