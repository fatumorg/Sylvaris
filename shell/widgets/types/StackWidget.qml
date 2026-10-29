import QtQuick
import qs
import qs.services
import "../../lib/widgets.mjs" as Wd

Item {
    id: root

    property var frame: null
    readonly property var item: root.frame !== null ? root.frame.item : null
    readonly property var kids: root.item !== null && root.item.children ? root.item.children.filter(c => !c.inactive) : []
    property int at: 0
    readonly property var shown: root.kids.length > 0 ? root.kids[Math.min(root.at, root.kids.length - 1)] : null
    readonly property var proxy: ({
            item: root.shown,
            accent: root.frame !== null ? root.frame.accent : Theme.accent,
            paused: root.frame !== null && root.frame.paused,
            host: root.frame !== null ? root.frame.host : null,
            pad: root.frame !== null ? root.frame.pad : 0,
            radius: root.frame !== null ? root.frame.radius : 0
        })

    Timer {
        interval: Math.max(3, root.item !== null ? root.item.options.every : 0) * 1000
        running: root.visible && root.kids.length > 1 && root.item !== null && root.item.options.every > 0 && !(root.frame !== null && root.frame.paused)
        repeat: true
        onTriggered: root.at = Wd.stackIndex(root.at, root.kids.length, 1)
    }

    WheelHandler {
        onWheel: event => root.at = Wd.stackIndex(root.at, root.kids.length, event.angleDelta.y > 0 ? -1 : 1)
    }

    Text {
        textFormat: Text.PlainText
        visible: root.kids.length === 0
        anchors.centerIn: parent
        text: "An empty stack; add widgets to it in SylSettings › Desktop › Widgets"
        width: parent.width
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    Loader {
        id: body
        anchors.fill: parent
        anchors.bottomMargin: dots.visible ? 14 : 0
        source: root.shown === null || root.shown.type === "terminal" ? "" : Qt.resolvedUrl(root.shown.type.charAt(0).toUpperCase() + root.shown.type.slice(1) + "Widget.qml")
        onLoaded: body.item.frame = Qt.binding(() => root.proxy)
    }

    Row {
        id: dots
        visible: root.kids.length > 1
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 5

        Repeater {
            model: root.kids.length

            delegate: Rectangle {
                required property int index
                width: 6
                height: 6
                radius: width / 2
                color: index === root.at ? Theme.text : Qt.alpha(Theme.text, 0.3)
            }
        }
    }
}
