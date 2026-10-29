import QtQuick
import qs
import qs.services

Text {
    id: root

    property real size: Tokens.tinySize

    textFormat: Text.PlainText
    color: Theme.textDim
    elide: Text.ElideRight
    font.family: Tokens.fontUi
    font.pixelSize: root.size
    font.weight: Font.DemiBold
    font.capitalization: Tokens.labelCase
    font.letterSpacing: Tokens.tracking * root.size
}
