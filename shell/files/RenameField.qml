import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: root

    required property var files
    required property string name
    property bool folder: false
    property int align: TextInput.AlignHCenter
    property bool done: false

    implicitHeight: input.implicitHeight + 10

    function finish(): void {
        if (root.done)
            return;
        if (root.files.commitRename(root.name, input.text))
            root.done = true;
    }

    Component.onCompleted: {
        input.text = root.name;
        const dot = root.name.lastIndexOf(".");
        input.select(0, root.folder || dot <= 0 ? root.name.length : dot);
        input.forceActiveFocus();
    }

    Glass {
        anchors.fill: parent
        radius: Tokens.r(8)
        raised: true
        flowing: false
        offColor: Theme.surface
        offBorder: Theme.accent
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.r(8)
        color: "transparent"
        border.width: 1.5
        border.color: root.files.renameError === "" ? Theme.accent : Theme.danger
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.margins: 5
        horizontalAlignment: root.align
        verticalAlignment: TextInput.AlignVCenter
        wrapMode: root.align === TextInput.AlignHCenter ? TextInput.WrapAnywhere : TextInput.NoWrap
        clip: true
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.onAccent
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
        selectByMouse: true
        onTextEdited: root.files.renameError = ""
        Keys.onReturnPressed: root.finish()
        Keys.onEnterPressed: root.finish()
        Keys.onEscapePressed: {
            root.done = true;
            root.files.cancelRename();
        }
        onActiveFocusChanged: {
            if (!activeFocus && !root.done && root.files.renaming === root.name) {
                root.finish();
                if (!root.done) {
                    root.done = true;
                    root.files.cancelRename();
                }
            }
        }
    }

    Text {
        visible: root.files.renameError !== ""
        anchors.top: parent.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: root.align === TextInput.AlignHCenter ? parent.horizontalCenter : undefined
        z: 10
        textFormat: Text.PlainText
        text: root.files.renameError
        color: Theme.danger
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.tinySize
    }
}
