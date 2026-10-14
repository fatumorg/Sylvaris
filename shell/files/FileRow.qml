import QtQuick
import qs
import qs.services
import "../lib/files.mjs" as F

Item {
    id: row

    required property var files
    required property var modelData
    required property int index
    required property var columns
    readonly property bool renaming: row.files.renaming === row.modelData.name

    z: row.renaming ? 5 : 0

    Entry {
        id: box
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        radius: 10
        files: row.files
        entry: row.modelData

        FileIcon {
            id: icon
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            files: row.files
            entry: row.modelData
            size: 22
            chosen: box.chosen
            opacity: box.faded ? 0.5 : 1
        }

        Text {
            visible: !row.renaming
            x: icon.x + icon.width + 10
            width: row.columns.name - x - 8
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: row.modelData.name
            elide: Text.ElideMiddle
            color: box.chosen ? Theme.onAccent : Theme.text
            opacity: box.faded ? 0.6 : 1
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
            font.weight: box.chosen ? Font.DemiBold : Font.Normal
        }

        Loader {
            active: row.renaming
            x: icon.x + icon.width + 6
            width: Math.max(160, row.columns.name - x)
            anchors.verticalCenter: parent.verticalCenter

            sourceComponent: RenameField {
                files: row.files
                name: row.modelData.name
                folder: row.modelData.dir
                align: TextInput.AlignLeft
            }
        }

        Repeater {
            model: [
                {
                    x: row.columns.name,
                    w: row.columns.size,
                    text: row.modelData.dir ? "—" : F.sizeText(row.modelData.size),
                    right: true
                },
                {
                    x: row.columns.name + row.columns.size,
                    w: row.columns.time,
                    text: F.whenText(row.modelData.modified, Date.now()),
                    right: false
                },
                {
                    x: row.columns.name + row.columns.size + row.columns.time,
                    w: row.columns.kind,
                    text: F.kindLabel(row.modelData.name, row.modelData.dir),
                    right: false
                }
            ]

            delegate: Text {
                required property var modelData
                x: modelData.x + 12
                width: modelData.w - 24
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: modelData.text
                elide: Text.ElideRight
                horizontalAlignment: modelData.right ? Text.AlignRight : Text.AlignLeft
                color: box.chosen ? Theme.onAccent : Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
                font.features: {
                    "tnum": 1
                }
            }
        }
    }
}
