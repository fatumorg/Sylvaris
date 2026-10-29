import QtQuick
import QtQuick.Effects
import SylStack
import qs
import qs.services
import qs.components
import "../../lib/widgets.mjs" as Wd
import "../../lib/settings.mjs" as S
import "../../lib/paper.mjs" as P
import "../../lib/capture.mjs" as C

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property string source: S.expandHome(root.o.source || "~/Pictures", Stack.env("HOME"))
    readonly property bool recursive: root.o.recursive === true
    readonly property string mode: root.o.mode || "single"
    readonly property string transition: root.o.transition || "fade"
    readonly property real interval: Math.max(3, root.o.interval || 30)
    readonly property color accent: root.frame !== null ? root.frame.accent : Theme.accent
    property var photos: []
    property int at: 0
    property string shown: ""
    property string behind: ""
    property string scanned: ""
    readonly property string wanted: root.frame === null || root.frame.item === null ? "" : root.source + (root.recursive ? "\n*" : "")
    readonly property string current: root.pick(0)
    readonly property real r: root.o.frame === "circle" ? Math.min(width, height) / 2 : root.o.frame === "polaroid" ? Tokens.r(4) : Tokens.radiusRow

    component Shot: RoundImage {
        property string path: ""
        property string recolour: "off"
        property real strength: 0.6
        property color accent: "white"

        source: path === "" ? "" : C.fileUri(path)
        layer.enabled: (recolour === "tint" || recolour === "mono") && gpu
        layer.effect: MultiEffect {
            saturation: recolour === "mono" ? -1 : -0.4 * strength
            colorization: recolour === "tint" ? strength : 0
            colorizationColor: accent
        }
    }

    function pick(offset: int): string {
        return root.photos.length === 0 ? "" : root.photos[(root.at + offset) % root.photos.length];
    }

    function scan(): void {
        if (root.wanted === "" || lister.running)
            return;
        root.scanned = root.wanted;
        if (P.isImage(root.source)) {
            root.photos = [root.source];
            return;
        }
        lister.command = ["find", "-L", root.source].concat(root.recursive ? [] : ["-maxdepth", "1"]).concat(["-type", "f"]);
        lister.running = true;
    }

    onWantedChanged: root.scan()
    Component.onCompleted: root.scan()
    onCurrentChanged: {
        if (root.current === root.shown)
            return;
        root.behind = root.shown;
        root.shown = root.current;
        swap.restart();
    }

    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.scanned !== root.wanted) {
                    Qt.callLater(root.scan);
                    return;
                }
                root.photos = Wd.photoList(text, 500);
                root.at = root.o.shuffle === true ? Wd.nextPhoto(-1, root.photos.length, true, Date.now()) : 0;
            }
        }
    }

    Timer {
        interval: root.interval * 1000
        running: root.visible && root.mode !== "single" && root.photos.length > 1 && !(root.frame !== null && root.frame.paused)
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

    Item {
        id: single
        anchors.fill: parent
        visible: (root.mode === "single" || root.mode === "slideshow") && root.shown !== ""

        Rectangle {
            visible: root.o.frame === "polaroid"
            anchors.fill: parent
            radius: Tokens.r(4)
            color: "#f4f1ea"
        }

        Item {
            id: view
            x: root.o.frame === "polaroid" ? 10 : 0
            y: root.o.frame === "polaroid" ? 10 : 0
            width: root.o.frame === "circle" ? Math.min(parent.width, parent.height) : parent.width - 2 * x
            height: root.o.frame === "circle" ? width : parent.height - y - (root.o.frame === "polaroid" ? 34 : 0)
            anchors.horizontalCenter: root.o.frame === "circle" ? parent.horizontalCenter : undefined
            clip: root.transition === "slide"

            Shot {
                id: back
                width: view.width
                height: view.height
                radius: root.r
                path: root.behind
                recolour: root.o.recolour || "off"
                strength: root.o.strength || 0.6
                accent: root.accent
            }

            Shot {
                id: front
                width: view.width
                height: view.height
                radius: root.r
                path: root.shown
                recolour: root.o.recolour || "off"
                strength: root.o.strength || 0.6
                accent: root.accent
            }
        }

        Text {
            visible: root.o.frame === "polaroid"
            textFormat: Text.PlainText
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 20
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            text: root.shown.split("/").pop().replace(/\.[^.]+$/, "")
            color: "#3b3216"
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }
    }

    ParallelAnimation {
        id: swap

        NumberAnimation {
            target: front
            property: "opacity"
            from: root.transition === "slide" || root.behind === "" ? 1 : 0
            to: 1
            duration: Tokens.lite ? 0 : 700
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: front
            property: "x"
            from: root.transition === "slide" && root.behind !== "" ? view.width : 0
            to: 0
            duration: Tokens.lite ? 0 : 600
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: back
            property: "x"
            from: 0
            to: root.transition === "slide" && root.behind !== "" ? -view.width : 0
            duration: Tokens.lite ? 0 : 600
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: front
            property: "zoom"
            from: 1
            to: root.transition === "kenburns" ? 1.12 : 1
            duration: Tokens.lite ? 0 : root.interval * 1000
        }
    }

    Grid {
        id: mosaic
        readonly property int count: root.photos.length >= 4 ? 4 : root.photos.length >= 2 ? 2 : root.photos.length
        readonly property int lines: Math.ceil(mosaic.count / mosaic.columns)
        visible: root.mode === "mosaic" && root.photos.length > 0
        anchors.fill: parent
        columns: mosaic.count > 1 ? 2 : 1
        spacing: 6

        Repeater {
            model: root.mode === "mosaic" ? mosaic.count : 0

            delegate: Shot {
                required property int index
                width: (mosaic.width - (mosaic.columns - 1) * mosaic.spacing) / mosaic.columns
                height: (mosaic.height - (mosaic.lines - 1) * mosaic.spacing) / Math.max(1, mosaic.lines)
                radius: Tokens.radiusRow
                path: root.pick(index)
                recolour: root.o.recolour || "off"
                strength: root.o.strength || 0.6
                accent: root.accent
            }
        }
    }

    Repeater {
        model: root.mode === "polaroid" ? Math.min(3, root.photos.length) : 0

        delegate: Rectangle {
            id: card

            required property int index
            readonly property int depth: Math.min(3, root.photos.length) - 1 - card.index

            width: root.width * 0.74
            height: root.height * 0.86
            anchors.centerIn: parent
            rotation: [0, 6, -7][card.depth]
            radius: Tokens.r(3)
            color: "#f4f1ea"

            Shot {
                x: 8
                y: 8
                width: parent.width - 16
                height: parent.height - 34
                radius: Tokens.r(2)
                path: root.pick(card.depth)
                recolour: root.o.recolour || "off"
                strength: root.o.strength || 0.6
                accent: root.accent
            }
        }
    }

    TapHandler {
        enabled: root.current !== ""
        onTapped: Ipc.run(["viewer", "open", root.current])
    }
}
