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
                solid: "solid"
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
    readonly property real pad: (!root.item ? 0 : root.item.type === "terminal" ? 0 : root.item.type === "photos" || root.item.type === "sticker" ? 8 : 16) * (typeof root.style.padding === "number" ? root.style.padding : 1)
    readonly property real zoom: !root.item || root.item.type === "terminal" || typeof root.style.zoom !== "number" ? 1 : root.style.zoom
    readonly property real idle: typeof root.style.idle === "number" ? root.style.idle : 1
    readonly property string fontUi: typeof root.style.font === "string" && root.style.font !== "" ? root.style.font : Tokens.fontUi
    readonly property string fontDisplay: typeof root.style.font === "string" && root.style.font !== "" ? root.style.font : Tokens.fontDisplay

    opacity: root.idle >= 1 || hover.hovered ? 1 : root.idle

    Behavior on opacity {
        NumberAnimation {
            duration: Tokens.stateDuration
        }
    }

    HoverHandler {
        id: hover
    }

    Glass {
        anchors.fill: parent
        visible: !root.clear
        radius: root.radius
        preview: root.glass
    }

    Loader {
        id: body
        x: root.pad
        y: root.pad
        width: (root.width - 2 * root.pad) / root.zoom
        height: (root.height - 2 * root.pad) / root.zoom
        scale: root.zoom
        transformOrigin: Item.TopLeft
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
