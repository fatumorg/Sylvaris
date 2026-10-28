import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.components
import "../lib/look.mjs" as L

Item {
    id: root

    required property var item
    required property var cfg
    property bool paused: false
    property var host: null
    property var rect: null
    property string screenName: ""
    readonly property var style: Object.assign({}, root.cfg ? root.cfg.style : {}, root.item ? root.item.style : {})
    readonly property bool clear: root.style.clear === true || root.style.material === "clear"
    readonly property real radius: Tokens.radiusCard * root.style.radius
    readonly property color accent: root.style.accent !== "" ? root.style.accent : Theme.accent
    readonly property var glass: {
        const pick = ({
                glass: "lumen",
                frosted: "frost",
                solid: "ink"
            })[root.style.material];
        const g = pick === undefined ? Look.glassFor("widgets") : Object.assign({
            enabled: Look.glass.enabled
        }, L.MATERIALS[pick]);
        return Object.assign({}, g, {
            opacity: g.opacity * root.style.opacity,
            shadow: root.style.shadow ? g.shadow : 0
        });
    }
    readonly property string file: !root.item ? "" : root.item.type.charAt(0).toUpperCase() + root.item.type.slice(1) + "Widget.qml"
    readonly property real pad: !root.item ? 0 : root.item.type === "terminal" ? 0 : root.item.type === "photos" ? 8 : 16

    Glass {
        anchors.fill: parent
        visible: !root.clear
        radius: root.radius
        preview: root.glass
    }

    Loader {
        id: body
        anchors.fill: parent
        anchors.margins: root.pad
        source: root.file === "" ? "" : Qt.resolvedUrl("types/" + root.file)
        layer.enabled: root.clear && body.GraphicsInfo.api !== GraphicsInfo.Software && body.GraphicsInfo.api !== GraphicsInfo.Unknown
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.6
            shadowColor: Qt.rgba(0, 0, 0, 0.6)
            shadowVerticalOffset: 1
        }
        onLoaded: body.item.frame = root
    }
}
