import QtQuick
import QtQuick.Shapes
import qs
import qs.services

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property color colour: root.o.colour ? root.o.colour : Theme.text
    readonly property bool outlined: root.o.style === "outlined"
    readonly property string words: root.o.text === undefined ? "Sylvaris" : root.o.text

    Text {
        id: fit
        anchors.fill: parent
        opacity: root.outlined ? 0 : 1
        textFormat: Text.PlainText
        text: root.outlined ? root.words.replace(/\s+/g, " ") : root.words
        wrapMode: root.outlined ? Text.NoWrap : Text.Wrap
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        horizontalAlignment: root.o.align === "left" ? Text.AlignLeft : root.o.align === "right" ? Text.AlignRight : Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.colour
        font.family: root.o.font ? root.o.font : Tokens.fontDisplay
        font.pixelSize: 400
        font.weight: Font.DemiBold
    }

    Shape {
        id: outline
        visible: root.outlined
        preferredRendererType: Shape.CurveRenderer
        x: (root.o.align === "left" ? 0 : root.o.align === "right" ? root.width - outline.boundingRect.width : (root.width - outline.boundingRect.width) / 2) - outline.boundingRect.x
        y: (root.height - outline.boundingRect.height) / 2 - outline.boundingRect.y

        ShapePath {
            strokeColor: root.colour
            strokeWidth: Math.max(1.5, fit.fontInfo.pixelSize / 36)
            fillColor: "transparent"

            PathText {
                text: root.outlined ? fit.text : ""
                font.family: fit.font.family
                font.pixelSize: fit.fontInfo.pixelSize
                font.weight: fit.font.weight
            }
        }
    }
}
