import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: bar

    required property var editor
    required property int zoom
    property bool picking: false
    readonly property var cfg: Settings.values.notes
    readonly property int selected: bar.editor === null ? 0 : bar.editor.edit.selectionEnd - bar.editor.edit.selectionStart
    readonly property var choices: {
        if (bar.editor === null || !bar.picking)
            return [];
        const q = filter.text.toLowerCase();
        return ["Plain text"].concat(bar.editor.languages).filter(n => q === "" || n.toLowerCase().indexOf(q) >= 0);
    }

    function pick(name: string): void {
        bar.picking = false;
        if (bar.editor === null)
            return;
        bar.editor.chosen = name;
        bar.editor.edit.forceActiveFocus();
    }

    onEditorChanged: bar.picking = false
    onPickingChanged: {
        filter.text = "";
        if (bar.picking)
            filter.forceActiveFocus();
    }

    Row {
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Text {
            visible: bar.editor !== null
            textFormat: Text.PlainText
            text: bar.editor === null || bar.editor.language === "" ? "Plain text" : bar.editor.language
            color: langArea.containsMouse || bar.picking ? Theme.accent : Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize

            MouseArea {
                id: langArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.picking = !bar.picking
            }
        }

        Repeater {
            model: bar.editor === null ? [] : [bar.editor.eol === "crlf" ? "CRLF" : "LF", "UTF-8", bar.cfg.spaces ? "Spaces: " + bar.cfg.tabWidth : "Tab width: " + bar.cfg.tabWidth]

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

        Repeater {
            model: bar.editor === null ? [] : [bar.selected > 0 ? bar.selected + " selected" : "", bar.zoom !== 0 ? Math.round(bar.editor.fontSize / bar.cfg.size * 100) + "%" : "", "Ln " + bar.editor.line + ", Col " + bar.editor.column].filter(t => t !== "")

            Text {
                required property string modelData
                textFormat: Text.PlainText
                text: modelData
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.tinySize
                font.features: {
                    "tnum": 1
                }
            }
        }
    }

    Item {
        x: 10
        y: -height - 6
        width: 280
        height: Math.min(360, 52 + list.contentHeight)
        visible: bar.picking

        Glass {
            anchors.fill: parent
            radius: Tokens.r(14)
            raised: true
            flowing: false
            offColor: Theme.surface
            offBorder: Theme.line
        }

        TextInput {
            id: filter
            x: 16
            y: 14
            width: parent.width - 32
            clip: true
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
            Keys.onEscapePressed: bar.pick(bar.editor === null ? "" : bar.editor.chosen)
            Keys.onReturnPressed: {
                if (bar.choices.length > 0)
                    bar.pick(bar.choices[0]);
            }

            Text {
                anchors.fill: parent
                visible: filter.text === ""
                textFormat: Text.PlainText
                text: "Language"
                color: Theme.textDim
                font: filter.font
            }
        }

        ListView {
            id: list
            x: 6
            y: 44
            width: parent.width - 12
            height: parent.height - 50
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: bar.choices

            delegate: Rectangle {
                id: row
                required property string modelData
                width: list.width
                height: 28
                radius: height / 2
                color: rowArea.containsMouse ? Theme.tintMid : "transparent"

                Text {
                    x: 10
                    width: parent.width - 20
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: row.modelData
                    elide: Text.ElideRight
                    color: bar.editor !== null && row.modelData === bar.editor.language ? Theme.accent : Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.pick(row.modelData)
                }
            }
        }
    }
}
