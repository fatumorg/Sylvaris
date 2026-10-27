import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Column {
    id: root

    property string version: ""
    property string memory: ""
    property string uptime: ""
    readonly property var stats: [
        {
            glyph: Icons.GLYPHS.timer,
            value: root.uptime || "—",
            label: "Uptime"
        },
        {
            glyph: Icons.GLYPHS.bolt,
            value: root.memory || "—",
            label: "Shell memory"
        },
        {
            glyph: Icons.GLYPHS.apps,
            value: String(Apps.list.length),
            label: "Apps"
        },
        {
            glyph: Icons.GLYPHS.theme,
            value: String(Theme.ids.length),
            label: "Themes"
        },
        {
            glyph: Icons.GLYPHS.newWindow,
            value: String(Compositor.windows.length),
            label: "Windows"
        },
        {
            glyph: Icons.GLYPHS.grid,
            value: String(Compositor.workspaces.length),
            label: "Workspaces"
        },
        {
            glyph: Icons.GLYPHS.displays,
            value: String(Stack.screens.length),
            label: "Screens"
        },
        {
            glyph: Icons.GLYPHS.bell,
            value: String(Notifications.count),
            label: "Notifications"
        }
    ]

    signal reload

    spacing: 18

    Grid {
        width: parent.width
        columns: 2
        spacing: 10

        Repeater {
            model: root.stats

            delegate: Item {
                required property var modelData
                required property int index
                width: (root.width - 10) / 2
                height: 78

                Glass {
                    anchors.fill: parent
                    radius: Tokens.radiusCard
                    inner: true
                    offBorder: Theme.cardLine
                }

                Glyph {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: 14
                    text: modelData.glyph
                    size: 16
                    color: Theme.accent
                }

                Text {
                    textFormat: Text.PlainText
                    x: 14
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 30
                    text: modelData.value
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    textFormat: Text.PlainText
                    x: 14
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    text: modelData.label
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }
            }
        }
    }

    Row {
        spacing: 12

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.GLYPHS.info
            size: 22
            color: Theme.accent
        }

        Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: "About"
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }
    }

    Item {
        width: parent.width
        height: aboutColumn.implicitHeight + 28

        Glass {
            anchors.fill: parent
            radius: Tokens.radiusCard
            inner: true
            offBorder: Theme.cardLine
        }

        Column {
            id: aboutColumn
            x: 16
            y: 14
            width: parent.width - 32
            spacing: 6

            Text {
                textFormat: Text.PlainText
                text: "Sylvaris " + root.version
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.titleSize
                font.weight: Font.DemiBold
            }

            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: "A desktop shell for Hyprland, niri and sway, built on SylStack. Running on " + Compositor.name + (Compositor.usingLua ? " with a Lua config" : "") + "."
                wrapMode: Text.Wrap
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }

            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: Config.dir
                elide: Text.ElideMiddle
                color: Theme.textSoft
                font.family: Tokens.fontMono
                font.pixelSize: Tokens.tinySize
            }

            Row {
                spacing: 8
                topPadding: 6

                Chip {
                    text: "Open folder"
                    glyph: Icons.GLYPHS.open
                    onClicked: Stack.execDetached(["xdg-open", Config.dir])
                }

                Chip {
                    text: "Reload"
                    glyph: Icons.GLYPHS.restart
                    onClicked: root.reload()
                }
            }

            Text {
                textFormat: Text.PlainText
                width: parent.width
                topPadding: 6
                text: "The constellation idea is inspired by ilyamiro/serpantinum. AirPods support follows the accessory protocol documented by LibrePods. Weather by Open-Meteo."
                wrapMode: Text.Wrap
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.tinySize
            }
        }
    }
}
