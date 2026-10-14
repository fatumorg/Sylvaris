import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

Card {
    id: root

    property string capturing: ""
    property string part: "files"
    property var actions: F.FILE_ACTIONS
    readonly property var own: Settings.shown[root.part].keys
    readonly property var map: F.keymap(root.own, root.actions)

    function assign(id: string, combos: var): void {
        const next = Object.assign({}, root.own);
        if (combos === null)
            delete next[id];
        else
            next[id] = combos;
        Settings.put(root.part + ".keys", next);
    }

    function labelOf(id: string): string {
        const a = root.actions.find(x => x.id === id);
        return a ? a.label : id;
    }

    title: "Keys in SylFiles"
    note: "Click an action, then press the keys. Esc cancels, Backspace or × unbinds it, ↺ brings back the default. A key you set wins over a default that uses the same key."

    Repeater {
        model: root.actions

        delegate: SettingRow {
            id: row
            required property var modelData
            required property int index
            readonly property bool active: root.capturing === row.modelData.id
            readonly property bool changed: root.own[row.modelData.id] !== undefined
            readonly property var combos: root.map.byAction[row.modelData.id]
            readonly property var lost: row.combos.filter(c => root.map.byCombo[c] !== row.modelData.id)
            title: row.modelData.label
            subtitle: row.lost.length > 0 ? F.keyText(row.lost[0]) + " is taken by “" + root.labelOf(root.map.byCombo[row.lost[0]]) + "”" : ""
            last: row.index === root.actions.length - 1

            Row {
                spacing: 8

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.changed
                    text: Icons.GLYPHS.restart
                    size: 15
                    color: resetArea.containsMouse ? Theme.accent : Theme.textDim

                    MouseArea {
                        id: resetArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.assign(row.modelData.id, null)
                    }
                }

                Item {
                    width: 190
                    height: 36

                    Glass {
                        anchors.fill: parent
                        radius: height / 2
                        inner: true
                        lit: row.active
                        hot: pickArea.containsMouse
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: height / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.accent
                        visible: catcher.activeFocus && row.active
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: clearGlyph.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: row.active ? "Press keys…" : row.combos.length === 0 ? "Not set" : row.combos.map(F.keyText).join("  ·  ")
                        color: row.active ? Theme.onAccent : row.combos.length === 0 ? Theme.textDim : Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                    }

                    MouseArea {
                        id: pickArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.capturing = row.modelData.id;
                            catcher.forceActiveFocus();
                        }
                    }

                    Glyph {
                        id: clearGlyph
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.active || row.combos.length > 0
                        text: Icons.GLYPHS.close
                        size: 14
                        color: row.active ? Theme.onAccent : clearArea.containsMouse ? Theme.text : Theme.textDim

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (row.active)
                                    root.capturing = "";
                                else
                                    root.assign(row.modelData.id, []);
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: catcher
        width: 0
        height: 0
        onActiveFocusChanged: {
            if (!activeFocus && Window.activeFocusItem !== null)
                root.capturing = "";
        }
        Keys.onPressed: event => {
            if (root.capturing === "")
                return;
            event.accepted = true;
            if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr].indexOf(event.key) >= 0)
                return;
            const id = root.capturing;
            if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                root.capturing = "";
                return;
            }
            if (event.key === Qt.Key_Backspace && event.modifiers === Qt.NoModifier) {
                root.capturing = "";
                root.assign(id, []);
                return;
            }
            const combo = F.comboOf(event.key, event.modifiers);
            if (combo === "")
                return;
            root.capturing = "";
            root.assign(id, [combo]);
        }
    }
}
