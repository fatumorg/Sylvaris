import QtQuick
import QtQuick.Effects
import qs.services

MiniScreen {
    id: root

    readonly property var paper: Settings.shown.paper

    dim: false
    showBar: false

    Rectangle {
        anchors.fill: parent
        color: Theme.base
    }

    Image {
        id: img
        anchors.fill: parent
        visible: false
        source: Theme.wallpaper === "" ? "" : "file://" + Theme.wallpaper
        sourceSize.width: 480
        fillMode: root.paper.fit === "contain" ? Image.PreserveAspectFit : root.paper.fit === "center" ? Image.Pad : root.paper.fit === "tile" ? Image.Tile : Image.PreserveAspectCrop
        asynchronous: true
    }

    MultiEffect {
        anchors.fill: img
        source: img
        blurEnabled: root.paper.blur > 0
        blur: Math.min(1, root.paper.blur)
        blurMax: 32
        brightness: -root.paper.dim * 0.8
        colorization: root.paper.tint
        colorizationColor: Theme.accentDeep
    }
}
