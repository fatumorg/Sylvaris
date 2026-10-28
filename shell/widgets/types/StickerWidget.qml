import QtQuick
import QtQuick.Effects
import SylStack
import qs
import qs.services
import "../../lib/settings.mjs" as S
import "../../lib/capture.mjs" as C

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property string path: root.o.source ? S.expandHome(root.o.source, Stack.env("HOME")) : ""

    Text {
        textFormat: Text.PlainText
        visible: root.path === "" || picture.status === Image.Error
        anchors.fill: parent
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: root.path === "" ? "Pick a picture or GIF in SylSettings › Desktop › Widgets" : "Cannot open " + root.path
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    Item {
        id: art
        anchors.fill: parent
        visible: root.path !== ""
        layer.enabled: (root.o.recolour === "tint" || root.o.recolour === "mono") && art.GraphicsInfo.api !== GraphicsInfo.Software && art.GraphicsInfo.api !== GraphicsInfo.Unknown
        layer.effect: MultiEffect {
            saturation: root.o.recolour === "mono" ? -1 : -0.4 * (root.o.strength === undefined ? 0.6 : root.o.strength)
            colorization: root.o.recolour === "tint" ? (root.o.strength === undefined ? 0.6 : root.o.strength) : 0
            colorizationColor: root.frame !== null ? root.frame.accent : Theme.accent
        }

        AnimatedImage {
            id: picture
            anchors.fill: parent
            source: root.path === "" ? "" : C.fileUri(root.path)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
            playing: root.visible && !(root.frame !== null && root.frame.paused)
        }
    }
}
