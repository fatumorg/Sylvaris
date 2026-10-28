import QtQuick
import SylStack
import qs
import qs.services
import "../../lib/temp.mjs" as T

Scope {
    id: root

    readonly property var cfg: Temps.cfg.overlay
    property bool toggled: false
    readonly property var front: Compositor.activeWindow
    readonly property bool shown: Temps.enabled && root.cfg.show !== "off" && (root.toggled || T.overlayShown(root.cfg, root.front === null ? {} : {
            class: root.front.appId,
            fullscreen: root.front.fullscreen === true
        }, root.toggled))
    readonly property var target: Compositor.screenFor(Compositor.focusedName())

    function set(mode: string): void {
        if (mode !== "on" && mode !== "off" && mode !== "toggle")
            throw new Error("usage: temp overlay <on|off|toggle>");
        const on = mode === "on" || mode === "toggle" && !root.shown;
        if (on && root.cfg.show === "off")
            Settings.set("temp.overlay.show", "toggle");
        root.toggled = on;
    }

    onShownChanged: Temps.want("overlay", root.shown)
    Component.onDestruction: Temps.want("overlay", false)

    LazyLoader {
        active: root.shown && root.target !== null

        PanelWindow {
            screen: root.target
            anchors {
                top: root.cfg.corner.indexOf("top") === 0
                bottom: root.cfg.corner.indexOf("bottom") === 0
                left: root.cfg.corner.indexOf("left") > 0
                right: root.cfg.corner.indexOf("right") > 0
            }
            margins {
                top: root.cfg.y
                bottom: root.cfg.y
                left: root.cfg.x
                right: root.cfg.x
            }
            implicitWidth: Math.ceil(card.width * root.cfg.scale)
            implicitHeight: Math.ceil(card.height * root.cfg.scale)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "syltemp-overlay"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            Item {
                id: card
                width: rows.implicitWidth + 24
                height: rows.implicitHeight + 16
                scale: root.cfg.scale
                transformOrigin: Item.TopLeft

                Rectangle {
                    anchors.fill: parent
                    radius: root.cfg.style === "compact" ? height / 2 : Tokens.radiusRow
                    color: Qt.alpha(Theme.base, root.cfg.opacity)
                    border.width: 1
                    border.color: Qt.alpha(Theme.line, root.cfg.opacity)
                }

                TempRows {
                    id: rows
                    x: 12
                    y: 8
                    sensors: Temps.shown
                    style: root.cfg.style
                    rowWidth: 180
                }
            }
        }
    }
}
