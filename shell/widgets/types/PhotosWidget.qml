import QtQuick
import QtQuick.Effects
import SylStack
import qs
import qs.services
import qs.components
import "../../lib/widgets.mjs" as Wd
import "../../lib/settings.mjs" as S
import "../../lib/paper.mjs" as P

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property string source: S.expandHome(root.o.source || "~/Pictures", Stack.env("HOME"))
    property var photos: []
    property int at: 0
    readonly property string current: root.photos.length > 0 ? root.photos[Math.min(root.at, root.photos.length - 1)] : ""
    readonly property real r: root.o.frame === "circle" ? Math.min(width, height) / 2 : root.o.frame === "polaroid" ? Tokens.r(4) : Tokens.radiusRow

    function scan(): void {
        if (P.isImage(root.source)) {
            root.photos = [root.source];
            return;
        }
        lister.command = ["find", "-L", root.source].concat(root.o.recursive === true ? [] : ["-maxdepth", "1"]).concat(["-type", "f"]);
        lister.running = true;
    }

    onSourceChanged: root.scan()
    Component.onCompleted: root.scan()

    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                root.photos = Wd.photoList(text, 500);
                root.at = root.o.shuffle === true ? Wd.nextPhoto(-1, root.photos.length, true, Date.now()) : 0;
            }
        }
    }

    Timer {
        interval: Math.max(3, root.o.interval || 30) * 1000
        running: root.visible && root.o.mode !== "single" && root.photos.length > 1 && !(root.frame !== null && root.frame.paused)
        repeat: true
        onTriggered: root.at = Wd.nextPhoto(root.at, root.photos.length, root.o.shuffle === true, Date.now())
    }

    Text {
        textFormat: Text.PlainText
        visible: root.photos.length === 0
        anchors.centerIn: parent
        width: parent.width - 16
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        text: "No pictures in " + root.source
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    Rectangle {
        visible: root.o.frame === "polaroid" && root.current !== ""
        anchors.fill: parent
        radius: Tokens.r(4)
        color: "#f4f1ea"
    }

    RoundImage {
        id: photo
        visible: root.current !== ""
        x: root.o.frame === "polaroid" ? 10 : 0
        y: root.o.frame === "polaroid" ? 10 : 0
        width: root.o.frame === "circle" ? Math.min(parent.width, parent.height) : parent.width - 2 * x
        height: root.o.frame === "circle" ? width : parent.height - y - (root.o.frame === "polaroid" ? 34 : 0)
        anchors.horizontalCenter: root.o.frame === "circle" ? parent.horizontalCenter : undefined
        radius: root.r
        source: root.current === "" ? "" : "file://" + root.current
        layer.enabled: (root.o.recolour === "tint" || root.o.recolour === "mono") && photo.gpu
        layer.effect: MultiEffect {
            saturation: root.o.recolour === "mono" ? -1 : -0.4 * (root.o.strength || 0.6)
            colorization: root.o.recolour === "tint" ? root.o.strength || 0.6 : 0
            colorizationColor: root.frame !== null ? root.frame.accent : Theme.accent
        }

        TapHandler {
            onTapped: Ipc.run(["viewer", "open", root.current])
        }
    }
}
