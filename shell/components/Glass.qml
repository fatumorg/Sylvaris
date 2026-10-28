import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs
import qs.services
import "../lib/look.mjs" as L

Item {
    id: root

    property real radius: 0
    property string role: ""
    property bool inner: false
    property bool raised: false
    property bool hot: false
    property bool lit: false
    property bool flowing: true
    property color litColor: Theme.accent
    property color offColor: root.inner ? Theme.tint : Theme.surface
    property color offBorder: "transparent"
    property real drift: 0
    property point light: root.rest

    property var preview: null
    readonly property var g: root.preview !== null ? root.preview : root.role === "" ? Resin.values : Look.glassFor(root.role)
    readonly property real r: root.role === "" || Look.radius <= 0 ? root.radius : root.radius * root.g.radius / Look.radius
    readonly property bool on: root.g.enabled
    readonly property bool panel: !root.inner
    readonly property bool gpu: root.GraphicsInfo.api !== GraphicsInfo.Software && root.GraphicsInfo.api !== GraphicsInfo.Unknown
    readonly property bool extras: root.on && !Tokens.lite
    readonly property bool shaped: root.extras && root.role !== "" && root.panel && (Look.corners === "squircle" || Look.corners === "bevel")
    readonly property string outline: root.shaped ? L.cornerPath(root.width, root.height, root.r, Look.corners) : ""
    readonly property bool shiny: root.on && root.panel && root.g.sheen > 0 && !Tokens.lite
    readonly property real bodyAlpha: root.inner ? root.g.layerOpacity : root.raised ? Math.max(root.g.opacity, 0.88) : root.g.opacity
    readonly property real rimAlpha: root.g.rim * (root.inner ? 0.22 : 0.3)
    readonly property color bodyColor: root.on ? Qt.alpha(root.inner ? Qt.lighter(Theme.pane, 1.35) : Theme.pane, root.bodyAlpha) : root.offColor
    readonly property color rimColor: root.g.glow > 0 && root.panel ? Qt.tint(Qt.alpha(Theme.text, root.rimAlpha), Qt.alpha(Theme.accent, root.g.glow * 0.6)) : Qt.alpha(Theme.text, root.rimAlpha)
    readonly property point rest: Qt.point(root.width * (0.5 + 0.32 * Math.sin(root.drift * 0.35)), root.height * (0.14 + 0.05 * Math.sin(root.drift * 0.23 + 1.3)))

    property bool chasing: false
    readonly property bool drifting: root.flowing && root.g.flow > 0

    HoverHandler {
        id: pointer
        enabled: root.shiny
        onPointChanged: root.chasing = true
        onHoveredChanged: root.chasing = true
    }

    FrameAnimation {
        running: root.visible && root.shiny && !Tokens.paused && (root.chasing || root.drifting)
        onTriggered: {
            if (root.drifting)
                root.drift += frameTime * root.g.flow;
            const target = pointer.hovered ? pointer.point.position : root.rest;
            const k = Math.min(1, frameTime * 4);
            root.light = Qt.point(root.light.x + (target.x - root.light.x) * k, root.light.y + (target.y - root.light.y) * k);
            if (!root.drifting && Math.abs(target.x - root.light.x) < 0.5 && Math.abs(target.y - root.light.y) < 0.5)
                root.chasing = false;
        }
    }

    RectangularShadow {
        visible: root.extras && root.gpu && root.inner && root.g.shadow > 0 && root.width > 8 && root.height > 8
        anchors.fill: parent
        radius: root.r
        offset.y: 2 + 4 * root.g.shadow
        blur: 10 + 14 * root.g.shadow
        color: Qt.alpha("#000000", 0.32 * root.g.shadow)
    }

    Rectangle {
        visible: !root.shaped
        anchors.fill: parent
        radius: root.r
        antialiasing: true
        color: root.bodyColor
        border.width: root.on ? 0 : 1
        border.color: root.offBorder

        Behavior on color {
            ColorAnimation {
                duration: Tokens.stateDuration
            }
        }
    }

    GlassFill {
        visible: root.shaped
        anchors.fill: parent
        path: root.outline
        fill: root.bodyColor
    }

    Rectangle {
        visible: root.on && root.panel && root.g.tint > 0 && !root.shaped
        anchors.fill: parent
        radius: root.r
        antialiasing: true
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Theme.accent, root.g.tint)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    GlassFill {
        visible: root.shaped && root.g.tint > 0
        anchors.fill: parent
        path: root.outline
        gradient: true
        from: Qt.alpha(Theme.accent, root.g.tint)
    }

    Item {
        id: grain
        visible: root.extras && root.gpu && root.panel && root.g.grain > 0 && root.width > 8 && root.height > 8
        anchors.fill: parent
        opacity: root.g.grain
        layer.enabled: grain.visible
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: grainMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Image {
            anchors.fill: parent
            source: "../assets/grain.png"
            fillMode: Image.Tile
            smooth: false
        }
    }

    Item {
        id: grainMask
        anchors.fill: parent
        visible: false
        layer.enabled: grain.visible

        Rectangle {
            visible: !root.shaped
            anchors.fill: parent
            radius: root.r
            color: "#ffffff"
        }

        GlassFill {
            visible: root.shaped
            anchors.fill: parent
            path: root.outline
            fill: "#ffffff"
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.r
        antialiasing: true
        color: Theme.tintMid
        opacity: root.on && root.hot ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.stateDuration
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.r
        antialiasing: true
        color: root.litColor
        opacity: root.lit ? Resin.litAlpha : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.stateDuration
            }
        }
    }

    Shape {
        visible: root.shiny && root.width > 2 && root.height > 2
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                readonly property real r: Math.max(root.width, root.height) * 0.55
                centerX: root.light.x
                centerY: root.light.y
                focalX: root.light.x
                focalY: root.light.y
                centerRadius: r
                GradientStop {
                    position: 0
                    color: Qt.alpha(Theme.accentHi, root.g.sheen * 0.35)
                }
                GradientStop {
                    position: 0.45
                    color: Qt.alpha(Theme.text, root.g.sheen * 0.06)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }

            PathRectangle {
                x: 0
                y: 0
                width: root.width
                height: root.height
                radius: root.r
            }
        }
    }

    Rectangle {
        visible: root.extras && root.g.highlight > 0 && !root.shaped && root.height > 8
        anchors.fill: parent
        radius: root.r
        antialiasing: true
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha("#ffffff", root.g.highlight * (root.inner ? 0.07 : 0.12))
            }
            GradientStop {
                position: Math.min(1, 28 / Math.max(1, root.height))
                color: "transparent"
            }
        }
    }

    GlassFill {
        visible: root.shaped && root.g.highlight > 0
        anchors.fill: parent
        path: root.outline
        gradient: true
        fade: Math.min(1, 28 / Math.max(1, root.height))
        from: Qt.alpha("#ffffff", root.g.highlight * 0.12)
    }

    Rectangle {
        visible: root.extras && root.panel && root.g.glow > 0 && !root.shaped
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.r - 1)
        antialiasing: true
        color: "transparent"
        border.width: 3
        border.color: Qt.alpha(Theme.accent, root.g.glow * 0.22)
    }

    GlassFill {
        visible: root.shaped && root.g.glow > 0
        anchors.fill: parent
        path: root.outline
        stroke: Qt.alpha(Theme.accent, root.g.glow * 0.22)
        strokeWidth: 6
    }

    Rectangle {
        visible: root.on && root.g.rim > 0 && !root.shaped
        anchors.fill: parent
        radius: root.r
        antialiasing: true
        color: "transparent"
        border.width: 1
        border.color: root.rimColor
    }

    GlassFill {
        visible: root.shaped && root.g.rim > 0
        anchors.fill: parent
        path: root.outline
        stroke: root.rimColor
        strokeWidth: 2
    }
}
