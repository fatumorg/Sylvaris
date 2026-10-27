pragma Singleton

import QtQuick
import SylStack
import "../lib/settings.mjs" as S

Singleton {
    id: root

    readonly property var result: S.resolveGlass(Config.values.glass, Settings.values.glass)
    readonly property var values: root.result.values
    readonly property string notice: root.result.errors.length === 0 ? "" : "Glass: " + root.result.errors.join("; ")
    readonly property bool enabled: root.values.enabled
    readonly property real opacity: root.values.opacity
    readonly property real layerOpacity: root.values.layerOpacity
    readonly property real tint: root.values.tint
    readonly property real sheen: root.values.sheen
    readonly property real flow: root.values.flow
    readonly property real rim: root.values.rim
    readonly property real litAlpha: root.enabled ? 0.85 : 1

    onNoticeChanged: {
        if (root.notice !== "")
            console.warn("sylvaris: " + root.notice);
    }
}
