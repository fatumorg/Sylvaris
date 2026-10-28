import QtQuick
import qs
import qs.services

Item {
    id: bar

    required property var editor
    readonly property var cfg: Settings.values.notes

    Row {
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Repeater {
            model: bar.editor === null ? [] : [bar.editor.language === "" ? "Plain text" : bar.editor.language, bar.editor.eol === "crlf" ? "CRLF" : "LF", "UTF-8", bar.cfg.spaces ? "Spaces: " + bar.cfg.tabWidth : "Tab width: " + bar.cfg.tabWidth]

            Text {
                required property string modelData
                textFormat: Text.PlainText
                text: modelData
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.tinySize
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Text {
            visible: bar.editor !== null && bar.editor.readOnly
            textFormat: Text.PlainText
            text: "Read-only"
            color: Theme.accent
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
            font.weight: Font.DemiBold
        }

        Text {
            visible: bar.editor !== null
            textFormat: Text.PlainText
            text: bar.editor === null ? "" : "Ln " + bar.editor.line + ", Col " + bar.editor.column
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
            font.features: {
                "tnum": 1
            }
        }
    }
}
