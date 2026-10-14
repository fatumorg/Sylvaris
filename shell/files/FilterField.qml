import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

FocusScope {
    id: field

    required property var files

    implicitHeight: 34

    Connections {
        target: field.files

        function onFocusFilter(): void {
            input.forceActiveFocus();
            input.cursorPosition = input.text.length;
        }

        function onQueryChanged(): void {
            if (input.text !== field.files.query)
                input.text = field.files.query;
        }
    }

    Glass {
        anchors.fill: parent
        radius: height / 2
        inner: true
        hot: hover.hovered && !input.activeFocus
        lit: field.files.query !== "" && !input.activeFocus
        offColor: Theme.tintSoft
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: 1.5
        border.color: Theme.accent
        visible: input.activeFocus
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.IBeamCursor
    }

    TapHandler {
        onTapped: input.forceActiveFocus()
    }

    Glyph {
        id: lens
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.GLYPHS.search
        size: 15
        color: field.files.query !== "" && !input.activeFocus ? Theme.onAccent : Theme.textDim
    }

    TextInput {
        id: input
        anchors.left: lens.right
        anchors.leftMargin: 8
        anchors.right: clear.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: field.files.query !== "" && !activeFocus ? Theme.onAccent : Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.onAccent
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
        selectByMouse: true
        onTextEdited: field.files.search(input.text)
        Keys.onEscapePressed: {
            field.files.search("");
            field.files.focusView();
        }
        Keys.onDownPressed: field.files.focusView()
        Keys.onReturnPressed: input.done()
        Keys.onEnterPressed: input.done()

        function done(): void {
            if (field.files.names.length > 0 && field.files.selected.length === 0)
                field.files.selectNames([field.files.names[0]]);
            field.files.focusView();
        }
    }

    Text {
        anchors.left: input.left
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text === ""
        textFormat: Text.PlainText
        text: "Filter"
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !input.activeFocus
            textFormat: Text.PlainText
            text: F.keyText((field.files.keys.byAction.search || [""])[0])
            color: Qt.alpha(Theme.textDim, 0.7)
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
        }
    }

    Glyph {
        id: clear
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: input.text === "" ? 0 : 14
        visible: input.text !== ""
        text: Icons.GLYPHS.close
        size: 13
        color: clearArea.containsMouse ? Theme.text : (field.files.query !== "" && !input.activeFocus ? Theme.onAccent : Theme.textDim)

        MouseArea {
            id: clearArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                field.files.search("");
                field.files.focusView();
            }
        }
    }
}
