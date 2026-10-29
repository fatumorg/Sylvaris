import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: root

    property string title: ""
    property string note: ""
    default property alias rows: column.data

    width: parent ? parent.width : 0
    implicitHeight: heading.height + body.height

    Column {
        id: heading
        width: parent.width
        spacing: 4
        bottomPadding: root.title === "" ? 0 : 10

        Caption {
            visible: root.title !== ""
            text: root.title
            size: Tokens.smallSize
        }

        Text {
            textFormat: Text.PlainText
            visible: root.note !== ""
            width: parent.width
            text: root.note
            wrapMode: Text.Wrap
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }
    }

    Item {
        id: body
        anchors.top: heading.bottom
        width: parent.width
        visible: column.implicitHeight > 0
        height: visible ? column.implicitHeight + 12 : 0

        Glass {
            anchors.fill: parent
            radius: Tokens.radiusCard
            inner: true
            offBorder: Theme.cardLine
        }

        Column {
            id: column
            x: 18
            y: 6
            width: parent.width - 36
        }
    }
}
