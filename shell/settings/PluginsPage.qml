import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons
import "../lib/plugins.mjs" as P

Column {
    id: root

    property string armed: ""
    property string problem: ""
    property string newKind: "bar"

    function attempt(fn: var): void {
        try {
            root.problem = "";
            fn();
        } catch (e) {
            root.problem = e.message;
        }
    }

    spacing: 24

    Component.onCompleted: Plugins.refresh()

    Card {
        title: "Installed"
        note: "Diver and AirPods come with Sylvaris and stay off until you turn them on. Your own plugins live in " + Plugins.dir + ". They run with the same rights as Sylvaris, so only turn on ones you trust. A bar plugin shows up once you add plugin:<id> to a bar group; a panel opens with “sylvaris plugins open <id>”."

        Text {
            textFormat: Text.PlainText
            visible: Plugins.list.every(p => p.builtin === true)
            width: parent.width
            topPadding: 4
            bottomPadding: 8
            text: "No plugins of your own yet. Make one below or install one from a Git address."
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }

        Repeater {
            model: Plugins.list

            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.ok ? modelData.manifest.name + "  ·  " + (modelData.builtin ? "built in" : modelData.manifest.kind) : modelData.id
                subtitle: modelData.ok ? (modelData.manifest.description || modelData.id) + (modelData.manifest.version ? " · " + modelData.manifest.version : "") : "Not loaded: " + modelData.error
                last: index === Plugins.list.length - 1

                Row {
                    spacing: 8

                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.builtin !== true
                        text: root.armed === modelData.id ? "Really remove?" : "Remove"
                        glyph: Icons.GLYPHS.trash
                        lit: root.armed === modelData.id
                        onClicked: {
                            if (root.armed !== modelData.id) {
                                root.armed = modelData.id;
                                return;
                            }
                            root.armed = "";
                            root.attempt(() => Plugins.remove(modelData.id));
                        }
                    }

                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.ok
                        checked: Plugins.isEnabled(modelData.id)
                        onToggled: v => Plugins.setEnabled(modelData.id, v)
                    }
                }
            }
        }
    }

    Card {
        title: "Make a plugin"
        note: "Creates a folder with plugin.json and a Plugin.qml that already works. Plugins can import qs, qs.services and qs.components to look like the rest of Sylvaris."

        Row {
            width: parent.width
            spacing: 8

            TextBox {
                id: newId
                width: parent.width - kindPick.width - makeChip.width - 16
                placeholder: "my-plugin"
            }

            Segmented {
                id: kindPick
                width: 210
                anchors.verticalCenter: parent.verticalCenter
                options: [
                    {
                        key: "bar",
                        label: "Bar"
                    },
                    {
                        key: "panel",
                        label: "Panel"
                    },
                    {
                        key: "service",
                        label: "Service"
                    }
                ]
                current: root.newKind
                onPicked: key => root.newKind = key
            }

            Chip {
                id: makeChip
                anchors.verticalCenter: parent.verticalCenter
                text: "Create"
                glyph: Icons.GLYPHS.plus
                onClicked: root.attempt(() => {
                    Plugins.create(newId.text.trim(), root.newKind);
                    newId.text = "";
                })
            }
        }
    }

    Card {
        title: "Install from Git"
        note: "Fetches the plugin and shows the exact commit before anything is installed. It stays off until you turn it on above."

        Row {
            width: parent.width
            spacing: 8

            TextBox {
                id: gitUrl
                width: parent.width - installChip.width - 8
                placeholder: "https://github.com/someone/some-plugin"
            }

            Chip {
                id: installChip
                anchors.verticalCenter: parent.verticalCenter
                text: Plugins.fetching ? "Fetching…" : "Install"
                glyph: Icons.GLYPHS.web
                onClicked: root.attempt(() => {
                    Plugins.install(gitUrl.text.trim());
                    gitUrl.text = "";
                })
            }
        }

        Column {
            width: parent.width
            visible: Plugins.pending !== null
            topPadding: 12
            spacing: 8

            Text {
                textFormat: Text.PlainText
                width: parent.width
                wrapMode: Text.Wrap
                text: Plugins.pending === null ? "" : "Ready to install " + Plugins.pending.id + " from " + Plugins.pending.url
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.bodySize
            }

            Text {
                textFormat: Text.PlainText
                width: parent.width
                wrapMode: Text.WrapAnywhere
                text: Plugins.pending === null ? "" : "Commit " + Plugins.pending.commit
                color: Theme.textSoft
                font.family: Tokens.fontMono
                font.pixelSize: Tokens.smallSize
            }

            Text {
                textFormat: Text.PlainText
                width: parent.width
                wrapMode: Text.Wrap
                text: P.INSTALL_WARNING
                color: Theme.danger
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }

            Row {
                spacing: 8

                Chip {
                    text: "Install this commit"
                    glyph: Icons.GLYPHS.shield
                    onClicked: root.attempt(() => Plugins.confirm())
                }

                Chip {
                    text: "Discard"
                    glyph: Icons.GLYPHS.close
                    onClicked: root.attempt(() => Plugins.discard())
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: text !== ""
            topPadding: 8
            wrapMode: Text.Wrap
            text: root.problem !== "" ? root.problem : Plugins.problem
            color: Theme.danger
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }

        RowButton {
            icon: Icons.GLYPHS.folder
            label: "Open the plugins folder"
            onClicked: Stack.execDetached(["sh", "-c", "mkdir -p \"$0\" && xdg-open \"$0\"", Plugins.dir])
        }
    }
}
