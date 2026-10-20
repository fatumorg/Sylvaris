import QtQuick
import QtQuick.Shapes
import qs
import qs.services

Item {
    id: root

    property real radius: 0
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

    readonly property bool on: Resin.enabled
    readonly property bool panel: !root.inner
    readonly property bool shiny: root.on && root.panel && Resin.sheen > 0 && !Tokens.lite
    readonly property real bodyAlpha: root.inner ? Resin.layerOpacity : root.raised ? Math.max(Resin.opacity, 0.88) : Resin.opacity
    readonly property real rimAlpha: Resin.rim * (root.inner ? 0.22 : 0.3)
    readonly property point rest: Qt.point(root.width * (0.5 + 0.32 * Math.sin(root.drift * 0.35)), root.height * (0.14 + 0.05 * Math.sin(root.drift * 0.23 + 1.3)))

    property bool chasing: false
    readonly property bool drifting: root.flowing && Resin.flow > 0

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
                root.drift += frameTime * Resin.flow;
            const target = pointer.hovered ? pointer.point.position : root.rest;
            const k = Math.min(1, frameTime * 4);
            root.light = Qt.point(root.light.x + (target.x - root.light.x) * k, root.light.y + (target.y - root.light.y) * k);
            if (!root.drifting && Math.abs(target.x - root.light.x) < 0.5 && Math.abs(target.y - root.light.y) < 0.5)
                root.chasing = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        color: root.on ? Qt.alpha(root.inner ? Qt.lighter(Theme.pane, 1.35) : Theme.pane, root.bodyAlpha) : root.offColor
        border.width: root.on ? 0 : 1
        border.color: root.offBorder

        Behavior on color {
            ColorAnimation {
                duration: Tokens.stateDuration
            }
        }
    }

    Rectangle {
        visible: root.on && root.panel && Resin.tint > 0
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Theme.accent, Resin.tint)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
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
        radius: root.radius
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
                    color: Qt.alpha(Theme.accentHi, Resin.sheen * 0.35)
                }
                GradientStop {
                    position: 0.45
                    color: Qt.alpha(Theme.text, Resin.sheen * 0.06)
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
                radius: root.radius
            }
        }
    }

    Rectangle {
        visible: root.on && Resin.rim > 0
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.text, root.rimAlpha)
    }
}
