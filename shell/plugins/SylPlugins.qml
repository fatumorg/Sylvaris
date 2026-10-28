import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Popup {
    id: root

    property string current: ""
    readonly property var panels: Plugins.active("panel")
    readonly property var shownPlugin: root.current === "" ? null : Plugins.byId(root.current)

    namespace: "sylplugins"
    corner: "center"
    panelWidth: Tokens.pluginsWidth
    panelHeight: Tokens.pluginsHeight

    function openPlugin(id: string): void {
        const p = Plugins.byId(id);
        if (p === null || p.manifest.kind !== "panel")
            throw new Error("no panel plugin called " + id);
        if (!Plugins.isEnabled(id))
            throw new Error(id + " is turned off; turn it on in SylSettings › Plugins");
        root.current = id;
        root.open();
    }

    onClosed: root.current = ""

    Item {
        visible: false

        Repeater {
            model: Plugins.active("service")

            delegate: Loader {
                required property var modelData
                source: Plugins.url(modelData)
                onLoaded: {
                    if (item.hasOwnProperty("api"))
                        item.api = Plugins.api(modelData.id);
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        anchors.margins: 22
        active: root.shownPlugin !== null
        source: root.shownPlugin === null ? "" : Plugins.url(root.shownPlugin)
        onLoaded: {
            if (item.hasOwnProperty("api"))
                item.api = Plugins.api(root.current);
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 24
        visible: root.shownPlugin === null
        spacing: 16

        Row {
            spacing: 10

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.GLYPHS.puzzle
                size: 20
                color: Theme.accent
            }

            Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: "Plugins"
                color: Theme.text
                font.family: Tokens.fontDisplay
                font.pixelSize: Tokens.titleSize
                font.weight: Tokens.titleWeight
            }
        }

        Text {
            textFormat: Text.PlainText
            visible: root.panels.length === 0
            width: parent.width
            wrapMode: Text.Wrap
            text: "No panel plugins are turned on. Add or turn them on in SylSettings › Plugins."
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
        }

        Flow {
            width: parent.width
            spacing: 10

            Repeater {
                model: root.panels

                delegate: RowButton {
                    required property var modelData
                    icon: Icons.GLYPHS.puzzle
                    label: modelData.manifest.name
                    onClicked: root.current = modelData.id
                }
            }
        }
    }
}
