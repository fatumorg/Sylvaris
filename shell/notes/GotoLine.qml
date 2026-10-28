import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: box

    required property var editor
    property bool shown: false

    function open(): void {
        if (box.editor === null)
            return;
        box.shown = true;
        input.text = "";
        input.forceActiveFocus();
    }

    function close(): void {
        box.shown = false;
        if (box.editor !== null)
            box.editor.edit.forceActiveFocus();
    }

    function go(): void {
        const n = parseInt(input.text, 10);
        box.shown = false;
        if (box.editor !== null && n > 0)
            box.editor.goTo(n);
        else
            box.close();
    }

    width: 280
    height: 44
    visible: box.shown

    Glass {
        anchors.fill: parent
        radius: height / 2
        raised: true
        flowing: false
        offColor: Theme.surface
        offBorder: Theme.line
    }

    Text {
        id: label
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "Go to line"
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    TextInput {
        id: input
        anchors.left: label.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.onAccent
        font.family: Tokens.fontMono
        font.pixelSize: Tokens.smallSize
        validator: IntValidator {
            bottom: 1
        }
        onActiveFocusChanged: {
            if (!activeFocus)
                box.shown = false;
        }
        Keys.onEscapePressed: box.close()
        Keys.onReturnPressed: box.go()
        Keys.onEnterPressed: box.go()
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text === ""
        textFormat: Text.PlainText
        text: box.editor === null ? "" : "1 – " + box.editor.starts.length
        color: Qt.alpha(Theme.textDim, 0.7)
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.tinySize
    }
}
