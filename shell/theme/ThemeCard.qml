import QtQuick
import QtQuick.Shapes
import qs
import qs.services
import qs.components

Item {
    id: root

    required property string modelData
    required property int index
    property real time: 0
    property real enter: 1
    property point pointer: Qt.point(-1, -1)
    readonly property var entry: Theme.catalog[root.modelData] === undefined ? null : Theme.catalog[root.modelData]
    readonly property real depth: PathView.depth === undefined ? 1 : PathView.depth
    readonly property real turn: PathView.turn === undefined ? 0 : PathView.turn
    readonly property bool front: PathView.isCurrentItem === true
    readonly property bool tracking: root.front && root.pointer.x >= 0
    readonly property real bob: root.front ? 6 * Math.sin(root.time * 1.57) : 0
    property real leanX: root.tracking ? Math.max(-1, Math.min(1, (root.pointer.x - root.x - root.width / 2) / 900)) * 4 : 0
    property real leanY: root.tracking ? Math.max(-1, Math.min(1, (root.pointer.y - root.y - root.height / 2) / 700)) * -3 : 0

    signal picked(int index)

    width: Tokens.themeCardWidth
    height: Tokens.themeCardHeight
    scale: root.depth
    z: root.depth * 100
    opacity: (0.35 + 0.65 * Math.max(0, (root.depth - 0.55) / 0.45)) * root.enter

    Behavior on leanX {
        NumberAnimation {
            duration: Tokens.ms(260)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }
    }

    Behavior on leanY {
        NumberAnimation {
            duration: Tokens.ms(260)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }
    }

    transform: [
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis {
                x: 0
                y: 1
                z: 0
            }
            angle: root.turn + root.leanX
        },
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis {
                x: 1
                y: 0
                z: 0
            }
            angle: root.leanY
        },
        Translate {
            y: root.bob + (1 - root.enter) * 320
        }
    ]

    Glass {
        anchors.fill: parent
        radius: Tokens.themeRadius
        preview: root.entry !== null && root.entry.look !== "" ? Look.previewFor(root.entry.look) : null
        raised: true
        offColor: Theme.node
        offBorder: Theme.lineStrong
    }

    Rectangle {
        id: fallback
        anchors.fill: parent
        anchors.margins: 14
        radius: Tokens.themeRadius - 10
        antialiasing: true
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.entry === null ? Theme.base : root.entry.colors.base
            }
            GradientStop {
                position: 1
                color: root.entry === null ? Theme.accent : root.entry.colors.accent
            }
        }
    }

    Image {
        id: wall
        x: fallback.x
        y: fallback.y
        width: fallback.width
        height: fallback.height
        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        sourceSize.width: Tokens.themeCardWidth * 2
        source: root.entry === null || root.entry.wallpaper === "" ? "" : "file://" + root.entry.wallpaper
    }

    ShaderEffectSource {
        id: wallTexture
        x: fallback.x
        y: fallback.y
        width: fallback.width
        height: fallback.height
        visible: false
        sourceItem: wall
        hideSource: true
        mipmap: true
        smooth: true
    }

    Shape {
        x: fallback.x
        y: fallback.y
        width: fallback.width
        height: fallback.height
        visible: wall.status === Image.Ready
        layer.enabled: true
        layer.samples: 8
        layer.smooth: true

        ShapePath {
            strokeWidth: -1
            fillItem: wallTexture

            PathRectangle {
                x: 0
                y: 0
                width: fallback.width
                height: fallback.height
                radius: fallback.radius
            }
        }
    }

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 34
        spacing: 10

        Repeater {
            model: root.entry === null ? [] : [root.entry.colors.accent, root.entry.colors.surface, root.entry.colors.text]
            delegate: Rectangle {
                required property string modelData
                width: 34
                height: 34
                radius: Tokens.r(17)
                antialiasing: true
                color: modelData
                border.width: 2
                border.color: Qt.alpha("#ffffff", 0.35)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.picked(root.index)
    }
}
