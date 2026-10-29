import QtQuick
import QtQuick.Effects
import qs
import qs.services
import "../lib/icons.mjs" as Icons

Text {
    textFormat: Text.PlainText
    id: root

    property real size: 20
    property bool marked: false
    readonly property string mark: root.marked && root.text !== "" ? Tokens.iconStyle : "plain"
    readonly property var nudge: Icons.nudge(root.text)

    font.family: Tokens.fontGlyph
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    layer.enabled: root.mark === "glow" && !Tokens.lite
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.accent
        shadowBlur: 0.6
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    Rectangle {
        z: -1
        visible: root.mark === "plate" || root.mark === "ring"
        anchors.centerIn: parent
        width: Math.round(root.size * 1.7)
        height: width
        radius: root.mark === "ring" ? width / 2 : Tokens.r(8)
        antialiasing: true
        color: root.mark === "plate" ? Theme.tint : "transparent"
        border.width: root.mark === "ring" ? 1 : 0
        border.color: Qt.alpha(Theme.text, 0.35)
    }

    TextMetrics {
        id: ink
        font: root.font
        text: root.text
    }

    FontMetrics {
        id: line
        font: root.font
    }

    transform: Translate {
        x: root.text === "" ? 0 : Math.round(ink.advanceWidth / 2 - ink.tightBoundingRect.x - ink.tightBoundingRect.width / 2 + root.nudge.x * root.size)
        y: root.text === "" ? 0 : Math.round(line.height / 2 - line.ascent - ink.tightBoundingRect.y - ink.tightBoundingRect.height / 2 + root.nudge.y * root.size)
    }
}
