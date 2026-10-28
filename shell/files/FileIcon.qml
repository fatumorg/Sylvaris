import QtQuick
import qs
import SylStack
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/viewer.mjs" as V

Item {
    id: root

    required property var files
    property var entry: null
    property string folder: root.files.path
    property real size: 64
    property bool chosen: false
    readonly property string kind: root.entry === null ? "folder" : F.kindOf(root.entry.name, root.entry.dir)
    readonly property string full: root.entry === null ? root.folder : F.joinPath(root.folder, root.entry.name)
    readonly property bool previewable: root.files.cfg.thumbnails && ["image", "video", "pdf", "document", "sheet", "slides", "font"].indexOf(root.kind) >= 0
    readonly property string hash: root.previewable ? Qt.md5(V.uriOf(root.full)) : ""
    readonly property var sources: !root.previewable ? [] : (root.size > 96 ? ["x-large/", "large/", "normal/"] : ["large/", "normal/", "x-large/"]).filter(d => root.files.thumbs[d + root.hash + ".png"] === true).map(d => "file://" + root.files.cacheHome + "/thumbnails/" + d + root.hash + ".png").concat(root.kind === "image" && V.kindOf(root.full) === "image" ? [V.uriOf(root.full)] : [])
    property int attempt: 0
    readonly property bool pictured: pic.status === Image.Ready
    readonly property string themed: root.files.cfg.icons === "theme" ? Stack.iconPath(F.themeIcon(root.kind), true) : ""

    implicitWidth: root.size
    implicitHeight: root.size

    onSourcesChanged: root.attempt = 0

    Image {
        id: pic
        anchors.fill: parent
        source: root.attempt < root.sources.length ? root.sources[root.attempt] : ""
        sourceSize.width: Math.ceil(root.size * 2)
        sourceSize.height: Math.ceil(root.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
        visible: root.pictured
        onStatusChanged: {
            if (pic.status === Image.Error && root.attempt < root.sources.length)
                root.attempt++;
        }
    }

    Rectangle {
        visible: root.pictured
        anchors.centerIn: parent
        width: pic.paintedWidth + 2
        height: pic.paintedHeight + 2
        radius: Tokens.r(4)
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.14)
    }

    Image {
        anchors.fill: parent
        visible: !root.pictured && root.themed !== ""
        source: root.themed
        sourceSize.width: Math.ceil(root.size * 2)
        sourceSize.height: Math.ceil(root.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
    }

    Glyph {
        anchors.centerIn: parent
        visible: !root.pictured && root.themed === ""
        text: F.glyphOf(root.kind)
        size: root.size * (root.kind === "folder" ? 0.96 : 0.84)
        color: root.chosen ? (root.kind === "folder" ? Theme.onAccent : Qt.alpha(Theme.onAccent, 0.85)) : root.kind === "folder" ? Theme.accent : Qt.alpha(Theme.text, 0.78)
    }
}
