import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F

FocusScope {
    id: bar

    required property var files
    readonly property var pick: bar.files.chooser
    readonly property bool saving: bar.pick !== null && bar.pick.mode === "save"
    readonly property var choice: bar.pick === null || bar.saving ? [] : F.pickChoice(bar.pick.mode, bar.pick.multiple, bar.files.itemsOf(bar.files.selected), bar.files.path)
    readonly property bool ready: bar.saving ? name.text.trim() !== "" : bar.choice.length > 0

    implicitHeight: 62

    function submit(): void {
        if (!bar.ready)
            return;
        if (bar.saving)
            bar.files.savePick(name.text);
        else
            bar.files.choosePick();
    }

    function prime(): void {
        if (!bar.saving)
            return;
        name.text = bar.files.pickName;
        const dot = name.text.lastIndexOf(".");
        name.focusInput();
        name.select(0, dot > 0 ? dot : name.text.length);
    }

    onPickChanged: Qt.callLater(bar.prime)
    Component.onCompleted: Qt.callLater(bar.prime)

    Connections {
        target: bar.files

        function onPickNameChanged(): void {
            if (bar.saving && name.text !== bar.files.pickName)
                name.text = bar.files.pickName;
        }
    }

    Keys.onReturnPressed: bar.submit()
    Keys.onEnterPressed: bar.submit()
    Keys.onEscapePressed: bar.files.close()

    Glass {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 4
        radius: Tokens.radiusCard
        inner: true
        flowing: false
    }

    Text {
        id: lead
        x: 26
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -2
        textFormat: Text.PlainText
        text: bar.saving ? "Name" : bar.choice.length === 0 ? (bar.pick !== null && bar.pick.mode === "folder" ? "Select a folder" : "Select a file") : bar.choice.length === 1 ? "“" + F.nameOf(bar.choice[0]) + "”" : bar.choice.length + " items"
        elide: Text.ElideMiddle
        width: bar.saving ? implicitWidth : Math.min(implicitWidth, buttons.x - lead.x - 16)
        color: bar.saving || bar.choice.length > 0 ? Theme.text : Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
        font.weight: Font.DemiBold
    }

    TextBox {
        id: name
        visible: bar.saving
        anchors.left: lead.right
        anchors.leftMargin: 14
        anchors.right: problem.visible ? problem.left : buttons.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -2
        implicitHeight: 38
        placeholder: "File name"
        onTextChanged: {
            if (bar.saving && bar.files.pickName !== name.text) {
                bar.files.pickName = name.text;
                bar.files.pickError = "";
            }
        }
    }

    Text {
        id: problem
        visible: bar.files.pickError !== ""
        anchors.right: buttons.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -2
        textFormat: Text.PlainText
        text: bar.files.pickError
        color: Theme.danger
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.tinySize
    }

    Row {
        id: buttons
        anchors.right: parent.right
        anchors.rightMargin: 26
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -2
        spacing: 8

        PillButton {
            label: "Cancel"
            onClicked: bar.files.close()
        }

        PillButton {
            label: bar.saving ? "Save" : bar.pick !== null && bar.pick.mode === "folder" ? "Select" : "Open"
            glyph: bar.saving ? F.GLYPH.paste : F.GLYPH.folderOpen
            primary: true
            enabled: bar.ready
            onClicked: bar.submit()
        }
    }
}
