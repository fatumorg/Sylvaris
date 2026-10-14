import QtQuick
import qs
import qs.services
import "../lib/files.mjs" as F

Item {
    id: cell

    required property var files
    required property var modelData
    required property int index
    readonly property bool renaming: cell.files.renaming === cell.modelData.name

    z: cell.renaming ? 5 : 0

    Entry {
        id: box
        anchors.fill: parent
        anchors.margins: 4
        files: cell.files
        entry: cell.modelData

        FileIcon {
            id: icon
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            files: cell.files
            entry: cell.modelData
            size: cell.files.cfg.iconSize
            chosen: box.chosen
            opacity: box.faded ? 0.5 : 1
            scale: box.hovered && !box.chosen ? 1.04 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Tokens.stateDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        Text {
            visible: !cell.renaming
            anchors.top: icon.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 12
            textFormat: Text.PlainText
            text: cell.modelData.name
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: 2
            elide: Text.ElideRight
            color: box.chosen ? Theme.onAccent : Theme.text
            opacity: box.faded ? 0.6 : 1
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
            font.weight: box.chosen ? Font.DemiBold : Font.Normal
        }

        Loader {
            active: cell.renaming
            anchors.top: icon.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width + 24

            sourceComponent: RenameField {
                files: cell.files
                name: cell.modelData.name
                folder: cell.modelData.dir
            }
        }
    }
}
