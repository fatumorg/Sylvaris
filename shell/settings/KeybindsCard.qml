import QtQuick
import qs
import qs.services
import qs.components
import "../lib/keys.mjs" as K
import "../lib/icons.mjs" as Icons

Card {
    id: root

    property string capturing: ""
    readonly property var binds: Settings.shown.keybinds

    function assign(id: string, combo: string): void {
        const next = Object.assign({}, root.binds);
        if (combo === "")
            delete next[id];
        else
            next[id] = combo;
        Settings.put("keybinds", next);
    }

    title: "Key bindings"
    note: Keybinds.supported ? "Click an action, then press the keys. Sylvaris adds the binding to " + (Compositor.name === "hyprland" ? "Hyprland" : "sway") + " right away. Esc cancels; Backspace or × removes the binding. Bindings already in your compositor config show up here too." + (Keybinds.included ? "" : " To have them land in your config as well, add " + Keybinds.include + " to your config.") : "Your compositor cannot take new bindings at runtime; copy the lines from Advanced › Commands into its config instead."

    Repeater {
        model: K.ACTIONS

        delegate: SettingRow {
            id: row
            required property var modelData
            required property int index
            readonly property bool active: root.capturing === row.modelData.id
            readonly property string own: root.binds[row.modelData.id] || ""
            readonly property string combo: row.own || Keybinds.external[row.modelData.id] || ""
            title: row.modelData.label
            subtitle: "sylvaris " + row.modelData.id + (row.own === "" && row.combo !== "" ? " · from your compositor config" : "")
            last: index === K.ACTIONS.length - 1

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

                Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: clearGlyph.visible ? -10 : 0
                    text: row.active ? "Press keys…" : row.combo === "" ? "Not set" : row.combo.split("+").join(" + ")
                    color: row.active ? Theme.onAccent : row.combo === "" ? Theme.textDim : Theme.text
                    font.family: row.combo === "" || row.active ? Tokens.fontUi : Tokens.fontMono
                    font.pixelSize: Tokens.smallSize
                }

                MouseArea {
                    id: pickArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: Keybinds.supported
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
                    visible: Keybinds.supported && (row.active || row.own !== "")
                    text: Icons.GLYPHS.close
                    size: 14
                    color: row.active ? Theme.onAccent : clearArea.containsMouse ? Theme.text : Theme.textDim
                    opacity: clearArea.pressed ? 0.6 : 1

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
                                root.assign(row.modelData.id, "");
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
        focus: false
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
                root.assign(id, "");
                return;
            }
            const name = K.keyName(event.key, event.text);
            if (name === "")
                return;
            const mods = [];
            if (event.modifiers & Qt.MetaModifier)
                mods.push("SUPER");
            if (event.modifiers & Qt.ControlModifier)
                mods.push("CTRL");
            if (event.modifiers & Qt.AltModifier)
                mods.push("ALT");
            if (event.modifiers & Qt.ShiftModifier)
                mods.push("SHIFT");
            const combo = K.normalize(mods.concat([name]).join("+"));
            root.capturing = "";
            if (combo !== "")
                root.assign(id, combo);
        }
    }
}
