pragma Singleton

import QtQuick
import SylStack

Singleton {
    id: root

    readonly property var values: Look.glass
    readonly property bool enabled: root.values.enabled
    readonly property real opacity: root.values.opacity
    readonly property real layerOpacity: root.values.layerOpacity
    readonly property real tint: root.values.tint
    readonly property real sheen: root.values.sheen
    readonly property real flow: root.values.flow
    readonly property real rim: root.values.rim
    readonly property real grain: root.values.grain
    readonly property real highlight: root.values.highlight
    readonly property real glow: root.values.glow
    readonly property real shadow: root.values.shadow
    readonly property real litAlpha: root.enabled ? 0.85 : 1
}
