import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.components
import "../../lib/icons.mjs" as Icons

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property color accent: root.frame !== null ? root.frame.accent : Theme.accent
    readonly property bool vinyl: root.o.vinyl === true
    readonly property real side: Math.min(root.height, root.width * 0.45)

    component Button: Glyph {
        id: button

        signal pressed

        color: hover.hovered ? root.accent : Theme.text
        size: Math.min(26, root.height * 0.22)

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: button.pressed()
        }
    }

    Text {
        textFormat: Text.PlainText
        visible: !Media.available
        anchors.fill: parent
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: "Nothing is playing"
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    Item {
        id: cover
        visible: Media.available
        width: root.side
        height: root.side
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            visible: Media.art === ""
            radius: root.vinyl ? width / 2 : Tokens.radiusRow
            color: Theme.tintMid

            Glyph {
                anchors.centerIn: parent
                text: Icons.GLYPHS.music
                color: root.accent
                size: parent.width * 0.4
            }
        }

        RoundImage {
            id: art
            anchors.fill: parent
            visible: Media.art !== ""
            radius: root.vinyl ? width / 2 : Tokens.radiusRow
            source: Media.art
            layer.enabled: (root.o.recolour === "tint" || root.o.recolour === "mono") && art.gpu
            layer.effect: MultiEffect {
                saturation: root.o.recolour === "mono" ? -1 : -0.3
                colorization: root.o.recolour === "tint" ? 0.6 : 0
                colorizationColor: root.accent
            }
        }

        Rectangle {
            visible: root.vinyl
            anchors.centerIn: parent
            width: parent.width * 0.16
            height: width
            radius: width / 2
            color: Theme.base
            border.width: 2
            border.color: Qt.alpha(Theme.text, 0.25)
        }

        NumberAnimation on rotation {
            from: 0
            to: 360
            duration: Tokens.loopMs(6000)
            loops: Animation.Infinite
            running: root.vinyl && root.visible
            paused: running && (!Media.playing || root.frame !== null && root.frame.paused)
            onStopped: cover.rotation = 0
        }
    }

    Column {
        visible: Media.available
        anchors.left: cover.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: Media.title
            color: Theme.text
            font.family: Tokens.fontDisplay
            font.pixelSize: Tokens.bodySize
            font.weight: Font.DemiBold
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: Media.artist
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }

        Item {
            width: 1
            height: 8
        }

        Row {
            visible: root.o.controls !== false
            spacing: 18

            Button {
                text: Icons.GLYPHS.previous
                onPressed: Media.previous()
            }

            Button {
                text: Media.playing ? Icons.GLYPHS.pause : Icons.GLYPHS.play
                onPressed: Media.toggle()
            }

            Button {
                text: Icons.GLYPHS.next
                onPressed: Media.next()
            }
        }
    }
}
