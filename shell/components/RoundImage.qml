import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string source: ""
    property real radius: width / 2
    property color fallbackColor: "transparent"
    property real zoom: 1
    readonly property bool ready: img.status === Image.Ready
    readonly property bool gpu: root.GraphicsInfo.api !== GraphicsInfo.Software && root.GraphicsInfo.api !== GraphicsInfo.Unknown

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.fallbackColor
        visible: !root.ready
    }

    Item {
        id: box
        anchors.fill: parent
        clip: true
        visible: root.ready && !root.gpu

        Image {
            id: img
            anchors.fill: parent
            scale: root.zoom
            source: root.source
            sourceSize.width: Math.ceil(root.width * 2)
            sourceSize.height: Math.ceil(root.height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: root.gpu
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.ready && root.gpu
        source: box
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
