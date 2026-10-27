pragma Singleton

import QtQuick
import SylStack

Singleton {
    id: root

    readonly property bool plugged: Settings.values.plugins.enabled.awake === true
    property bool wanted: false
    readonly property bool on: root.wanted && root.plugged
    readonly property bool holding: loader.item !== null && loader.item.holding

    function set(on: bool): void {
        if (!root.plugged)
            throw new Error("Keep Awake is off; turn it on in SylSettings › Plugins or with: sylvaris plugins enable awake");
        root.wanted = on;
    }

    function state(): var {
        return {
            plugged: root.plugged,
            on: root.on,
            holding: root.holding
        };
    }

    LazyLoader {
        id: loader
        active: root.on

        PanelWindow {
            id: win
            readonly property bool holding: inhibitor.active
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                left: true
            }
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sylawake"

            IdleInhibitor {
                id: inhibitor
                window: win
            }
        }
    }
}
