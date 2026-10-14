import QtQuick
import qs
import qs.services

Rectangle {
    id: root

    property alias text: input.text
    property bool password: false
    property string placeholder: ""
    property alias persistentSelection: input.persistentSelection

    signal accepted

    function focusInput(): void {
        input.forceActiveFocus();
    }

    function select(start: int, end: int): void {
        input.select(start, end);
    }

    implicitHeight: 44
    radius: Tokens.radiusRow
    color: "transparent"
    border.width: input.activeFocus ? 1 : 0
    border.color: Theme.accent

    Glass {
        anchors.fill: parent
        z: -1
        radius: root.radius
        inner: true
        offColor: Theme.tintMid
        offBorder: input.activeFocus ? "transparent" : Theme.cardLine
    }


    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.fill
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.bodySize
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        clip: true
        onAccepted: root.accepted()
    }

    Text {
        textFormat: Text.PlainText
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: input.text === ""
        text: root.placeholder
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.bodySize
    }
}
