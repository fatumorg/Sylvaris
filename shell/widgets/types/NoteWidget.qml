import QtQuick
import qs
import qs.services

Item {
    id: root

    property var frame: null
    readonly property var item: root.frame !== null ? root.frame.item : null
    readonly property var o: root.item !== null ? root.item.options : ({})
    readonly property string stored: root.o.text || ""
    readonly property bool paper: root.o.paper !== false
    readonly property color ink: root.paper ? "#3b3216" : Theme.text

    function save(): void {
        const f = root.frame;
        if (f === null || !f.host || root.item === null || edit.text === root.stored)
            return;
        f.host.change({
            kind: "set",
            id: root.item.id,
            values: {
                options: Object.assign({}, root.item.options, {
                    text: edit.text.slice(0, 20000)
                })
            }
        });
    }

    onStoredChanged: {
        if (!edit.activeFocus && edit.text !== root.stored)
            edit.text = root.stored;
    }
    Component.onCompleted: edit.text = root.stored
    Component.onDestruction: {
        if (saver.running)
            root.save();
    }

    Timer {
        id: saver
        interval: 800
        onTriggered: root.save()
    }

    Rectangle {
        visible: root.paper
        anchors.fill: parent
        anchors.margins: root.frame !== null ? -root.frame.pad + 4 : 0
        radius: root.frame !== null ? Math.max(0, root.frame.radius - 4) : 0
        color: "#f6e7a1"
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: edit.contentHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        TextEdit {
            id: edit
            width: flick.width
            height: Math.max(flick.height, contentHeight)
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            color: root.ink
            selectionColor: root.paper ? "#c9a227" : Theme.accent
            selectedTextColor: root.paper ? "#1d1808" : Theme.onAccent
            font.family: Tokens.fontUi
            font.pixelSize: root.o.size || 14
            Keys.onEscapePressed: edit.focus = false
            onTextChanged: {
                if (edit.length > 20000)
                    edit.remove(20000, edit.length);
                if (edit.text !== root.stored)
                    saver.restart();
            }
            onActiveFocusChanged: {
                if (!activeFocus)
                    root.save();
            }
            onCursorRectangleChanged: {
                const r = edit.cursorRectangle;
                if (r.y < flick.contentY)
                    flick.contentY = r.y;
                else if (r.y + r.height > flick.contentY + flick.height)
                    flick.contentY = r.y + r.height - flick.height;
            }
        }
    }

    Text {
        textFormat: Text.PlainText
        visible: edit.text === "" && !edit.activeFocus
        text: "Write something"
        color: Qt.alpha(root.ink, 0.5)
        font: edit.font
    }
}
