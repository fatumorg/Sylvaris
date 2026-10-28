import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons
import "../lib/center.mjs" as C

Column {
    id: page

    required property var host
    readonly property var cfg: Settings.shown.center
    readonly property var toggleTiles: Config.values.toggles.map(t => ({
                key: "toggle:" + t.id,
                label: t.label,
                glyph: t.icon
            }))
    readonly property var tiles: [
        {
            key: "wifi",
            label: "Wi-Fi",
            glyph: Icons.GLYPHS.wifi
        },
        {
            key: "bluetooth",
            label: "Bluetooth",
            glyph: Icons.GLYPHS.bluetooth
        },
        {
            key: "night",
            label: "Night light",
            glyph: Icons.GLYPHS.nightLight
        },
        {
            key: "dnd",
            label: "DND",
            glyph: Icons.GLYPHS.dnd
        }
    ].concat(page.toggleTiles.slice(0, 1), [
        {
            key: "hotspot",
            label: "Hotspot",
            glyph: Icons.GLYPHS.hotspot
        }
    ], page.toggleTiles.slice(1))
    readonly property var extras: C.offeredExtras(Settings.shown.plugins).map(e => ({
                key: e.key,
                label: e.label,
                glyph: Icons.GLYPHS[e.glyph]
            }))
    readonly property var shownTiles: page.tiles.filter(t => page.cfg.hidden.indexOf(t.key) < 0).concat(page.extras.filter(e => page.cfg.extra.indexOf(e.key) >= 0))

    spacing: 24

    function flip(list: string, key: string): void {
        const next = page.cfg[list].slice();
        const i = next.indexOf(key);
        if (i < 0)
            next.push(key);
        else
            next.splice(i, 1);
        Settings.put("center." + list, next);
    }

    Card {
        title: "Control Center"
        note: "What SylCenter shows. A tile also needs its device or service, so Wi-Fi only appears on machines that have it."

        Item {
            width: parent.width
            height: preview.implicitHeight + 32

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusCard
                inner: true
            }

            Column {
                id: preview
                anchors.centerIn: parent
                width: 260
                spacing: 8

                Grid {
                    width: parent.width
                    columns: 2
                    spacing: 8

                    Repeater {
                        model: page.shownTiles

                        delegate: Item {
                            required property var modelData
                            width: (preview.width - 8) / 2
                            height: 34

                            Glass {
                                anchors.fill: parent
                                radius: Tokens.radiusRow
                                inner: true
                                offColor: Theme.tintMid
                            }

                            Row {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Glyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.glyph
                                    size: 14
                                    color: Theme.accent
                                }

                                Text {
                                    textFormat: Text.PlainText
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: (preview.width - 8) / 2 - 42
                                    elide: Text.ElideRight
                                    text: modelData.label
                                    color: Theme.text
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.tinySize
                                }
                            }
                        }
                    }
                }

                Repeater {
                    model: [
                        {
                            on: page.cfg.volume,
                            label: "Volume",
                            glyph: Icons.GLYPHS.volume
                        },
                        {
                            on: page.cfg.media,
                            label: "Now playing",
                            glyph: Icons.GLYPHS.music
                        }
                    ]

                    delegate: Item {
                        required property var modelData
                        visible: modelData.on
                        width: preview.width
                        height: 30

                        Glass {
                            anchors.fill: parent
                            radius: Tokens.radiusRow
                            inner: true
                            offColor: Theme.tintMid
                        }

                        Row {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.glyph
                                size: 14
                                color: Theme.accent
                            }

                            Text {
                                textFormat: Text.PlainText
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: Theme.textDim
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.tinySize
                            }
                        }
                    }
                }
            }
        }

        SettingRow {
            title: "Tiles"
            key: "center.hidden"
            subtitle: "Click to show or hide"

            Flow {
                width: 360
                spacing: 8

                Repeater {
                    model: page.tiles

                    delegate: Chip {
                        required property var modelData
                        text: modelData.label
                        glyph: modelData.glyph
                        lit: page.cfg.hidden.indexOf(modelData.key) < 0
                        onClicked: page.flip("hidden", modelData.key)
                    }
                }
            }
        }

        SettingRow {
            title: "Extra tiles"
            key: "center.extra"
            subtitle: "Speed Test and AirPods show up here once their plugins are on"

            Flow {
                width: 360
                spacing: 8

                Repeater {
                    model: page.extras

                    delegate: Chip {
                        required property var modelData
                        text: modelData.label
                        glyph: modelData.glyph
                        lit: page.cfg.extra.indexOf(modelData.key) >= 0
                        onClicked: page.flip("extra", modelData.key)
                    }
                }
            }
        }

        SettingRow {
            title: "Layout"
            key: "center.layout"
            subtitle: "Even tiles, or two wide tiles over small squares"

            Segmented {
                width: 220
                current: page.cfg.layout
                options: [
                    {
                        key: "grid",
                        label: "Grid"
                    },
                    {
                        key: "bento",
                        label: "Bento"
                    }
                ]
                onPicked: key => Settings.put("center.layout", key)
            }
        }

        SettingRow {
            title: "Volume slider"
            key: "center.volume"
            subtitle: "Output volume with a shortcut to the outputs"

            Toggle {
                checked: page.cfg.volume
                onToggled: v => Settings.put("center.volume", v)
            }
        }

        SettingRow {
            title: "Now playing"
            key: "center.media"
            subtitle: "The media card while something plays"

            Toggle {
                checked: page.cfg.media
                onToggled: v => Settings.put("center.media", v)
            }
        }

        SettingRow {
            title: "Corner"
            key: "center.corner"
            subtitle: "Where SylCenter and SylMedia open"
            last: true

            Segmented {
                width: 300
                options: page.host.corners
                current: page.cfg.corner
                onPicked: key => Settings.put("center.corner", key)
            }
        }
    }

    Card {
        title: "Hotspot"
        note: "Used when you start the hotspot from its tile, where you also set the password."

        SettingRow {
            title: "Network name"
            key: "hotspot.ssid"
            advanced: true
            subtitle: ssid.text.length < 1 || ssid.text.length > 32 ? "1 to 32 characters" : "Press Enter to save"

            TextBox {
                id: ssid
                width: 220
                text: Settings.shown.hotspot.ssid
                placeholder: "Sylvaris"
                onAccepted: {
                    if (ssid.text.length >= 1 && ssid.text.length <= 32)
                        Settings.put("hotspot.ssid", ssid.text);
                }
            }
        }

        SettingRow {
            title: "Band"
            key: "hotspot.band"
            advanced: true
            subtitle: "5 GHz is faster, 2.4 GHz reaches further"
            last: true

            Segmented {
                width: 220
                options: [
                    {
                        key: "bg",
                        label: "2.4 GHz"
                    },
                    {
                        key: "a",
                        label: "5 GHz"
                    }
                ]
                current: Settings.shown.hotspot.band
                onPicked: key => Settings.put("hotspot.band", key)
            }
        }
    }
}
