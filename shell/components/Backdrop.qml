import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs
import qs.services

Item {
    id: root

    property string source: Theme.wallpaper
    property real blur: 1
    property real dim: 0.3
    property color tint: Theme.accentDeep
    property real reveal: 1
    readonly property bool gpu: root.GraphicsInfo.api !== GraphicsInfo.Software && root.GraphicsInfo.api !== GraphicsInfo.Unknown
    readonly property string style: !root.gpu || Tokens.lite || Settings.values.motion.reduced ? "fade" : Settings.values.motion.reveal
    readonly property bool masked: root.style !== "fade" && root.reveal < 1
    readonly property real grow: 1.42 / 0.72 * (root.style === "edges" ? 1 - root.reveal : root.reveal)

    opacity: root.style === "fade" ? Math.min(1, root.reveal * 3) : root.reveal > 0 ? 1 : 0

    onRevealChanged: {
        if (root.reveal === 0)
            keep.restart();
    }

    Timer {
        id: keep
        interval: 20000
    }

    Item {
        id: content
        anchors.fill: parent
        layer.enabled: root.masked
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskInverted: root.style === "edges"
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.base
        }

        Loader {
            anchors.fill: parent
            active: root.gpu && !Tokens.lite && (root.reveal > 0 && root.visible || keep.running)
            sourceComponent: Component {
                Item {
                    visible: root.gpu && wall.status === Image.Ready && !Tokens.lite
                    layer.enabled: visible
                    layer.smooth: true

                    Image {
                        id: wall
                        anchors.fill: parent
                        anchors.margins: -64
                        visible: false
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 1280
                        source: !root.gpu || Tokens.lite || root.source === "" ? "" : "file://" + root.source
                    }

                    MultiEffect {
                        anchors.fill: wall
                        source: wall
                        blurEnabled: root.blur > 0
                        blur: root.blur
                        blurMax: 48
                        saturation: 0.2
                        brightness: -root.dim
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.alpha(Theme.base, 0.35)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Qt.darker(root.tint, 2.4), 0.55)
                }
            }
        }

        Item {
            id: aurora
            property real t: 0
            anchors.fill: parent
            visible: Look.values.aurora && !Tokens.lite && root.reveal > 0
            opacity: Math.min(1, root.reveal * 2)

            NumberAnimation on t {
                from: 0
                to: 1
                loops: Animation.Infinite
                duration: Tokens.loopMs(48000)
                running: aurora.visible && !Tokens.paused && !Settings.values.motion.reduced
            }

            Repeater {
                model: [
                    {
                        k: 0,
                        hue: 0
                    },
                    {
                        k: 2.1,
                        hue: 1
                    },
                    {
                        k: 4.2,
                        hue: 2
                    }
                ]

                delegate: Shape {
                    required property var modelData
                    readonly property real a: aurora.t * Math.PI * 2 + modelData.k
                    readonly property real r: Math.max(aurora.width, aurora.height) * 0.42
                    readonly property real cx: aurora.width * (0.5 + 0.34 * Math.sin(a))
                    readonly property real cy: aurora.height * (0.5 + 0.28 * Math.cos(a * 2 + modelData.k))
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: -1
                        fillGradient: RadialGradient {
                            centerX: cx
                            centerY: cy
                            focalX: cx
                            focalY: cy
                            centerRadius: r
                            GradientStop {
                                position: 0
                                color: Qt.alpha([Theme.accent, Theme.accentHi, Theme.accentDeep][modelData.hue], 0.13)
                            }
                            GradientStop {
                                position: 1
                                color: "transparent"
                            }
                        }

                        PathRectangle {
                            x: 0
                            y: 0
                            width: aurora.width
                            height: aurora.height
                        }
                    }
                }
            }
        }
    }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: root.masked

        Image {
            anchors.centerIn: parent
            width: Math.max(2, root.width * root.grow)
            height: Math.max(2, root.height * root.grow)
            source: root.masked ? Qt.resolvedUrl("../assets/reveal.png") : ""
            smooth: true
        }
    }
}
