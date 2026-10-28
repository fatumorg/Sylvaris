import QtQuick
import SylStack
import qs.services
import "../lib/corners.mjs" as C

Scope {
    id: root

    readonly property var cfg: Settings.values.corners

    function fire(screen: string, corner: string): void {
        const action = C.cornerAction(root.cfg.actions, screen, corner);
        if (action === null)
            return;
        if (typeof action === "string")
            Ipc.run(action.trim().split(/\s+/));
        else
            Stack.execDetached(action.command);
    }

    Variants {
        model: {
            const out = [];
            for (const s of Stack.screens) {
                for (const c of C.cornersOn(root.cfg.actions, s.name))
                    out.push({
                        screen: s,
                        corner: c
                    });
            }
            return out;
        }

        delegate: PanelWindow {
            id: win

            required property var modelData

            screen: win.modelData.screen
            anchors {
                top: win.modelData.corner.startsWith("top")
                bottom: win.modelData.corner.startsWith("bottom")
                left: win.modelData.corner.endsWith("left")
                right: win.modelData.corner.endsWith("right")
            }
            margins {
                top: -1
                bottom: -1
                left: -1
                right: -1
            }
            implicitWidth: 3
            implicitHeight: 3
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sylcorner"

            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        dwell.restart();
                    else
                        dwell.stop();
                }
            }

            Timer {
                id: dwell
                interval: Math.max(1, root.cfg.dwell)
                onTriggered: root.fire(win.modelData.screen.name, win.modelData.corner)
            }
        }
    }
}
