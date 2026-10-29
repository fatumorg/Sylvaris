import QtQuick
import qs
import qs.services

Text {
    textFormat: Text.PlainText
    color: Theme.textDim
    elide: Text.ElideRight
    font.family: Tokens.fontUi
    font.pixelSize: Tokens.tinySize
    font.weight: Font.DemiBold
    font.capitalization: Tokens.labelCase
    font.letterSpacing: Tokens.tracking * font.pixelSize
}
