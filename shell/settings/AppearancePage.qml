import QtQuick
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Column {
    id: page

    required property var host
    property string editing: ""
    property string newName: ""
    property string fault: ""
    property string doomed: ""

    function edit(id: string): void {
        if (id !== Theme.currentId)
            Theme.apply(id);
        page.doomed = "";
        page.editing = id;
    }

    function attempt(fn: var): void {
        try {
            fn();
            page.fault = "";
        } catch (e) {
            page.fault = e.message;
        }
    }

    spacing: 24

    Card {
        visible: page.editing === ""
        title: "Theme"

        SettingRow {
            title: Theme.theme.name || "Built-in"
            key: "theme"
            subtitle: Theme.theme.description || "The active theme"

            Chip {
                text: "Open the theme picker"
                glyph: Icons.GLYPHS.theme
                onClicked: host.hand("theme", "")
            }
        }

        SettingRow {
            title: "Theme-coloured app icons"
            key: "iconTint"
            subtitle: "App icons in the bar, deck, launcher, switcher and notifications take the theme's accent"

            Toggle {
                checked: Settings.shown.iconTint
                onToggled: v => Settings.put("iconTint", v)
            }
        }

    }

    Card {
        visible: page.editing === ""
        title: "Themes"
        note: "Click Use to switch. Your own themes can be edited and deleted; a theme from your config stays as it is, so duplicate it and change the copy."

        Repeater {
            model: Theme.ids

            delegate: SettingRow {
                id: item

                required property string modelData
                readonly property var entry: Theme.catalog[item.modelData]
                readonly property bool mine: Theme.managed.indexOf(item.modelData) < 0
                readonly property bool active: item.modelData === Theme.currentId

                title: item.entry !== undefined ? item.entry.name : item.modelData
                key: "theme.apply"
                subtitle: (item.active ? "In use · " : "") + (item.mine ? "Yours" : "From your config")

                Row {
                    spacing: 6

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -6
                        rightPadding: 10

                        Repeater {
                            model: ["base", "surface", "accent", "text"]

                            delegate: Rectangle {
                                required property string modelData
                                width: 22
                                height: 22
                                radius: height / 2
                                color: item.entry !== undefined ? item.entry.colors[modelData] : "transparent"
                                border.width: 1
                                border.color: Theme.lineStrong
                            }
                        }
                    }

                    Chip {
                        visible: !item.active
                        text: "Use"
                        onClicked: Theme.apply(item.modelData)
                    }

                    Chip {
                        visible: item.mine
                        text: "Edit"
                        onClicked: page.edit(item.modelData)
                    }

                    Chip {
                        text: "Duplicate"
                        onClicked: page.attempt(() => page.edit(Theme.duplicate(item.modelData)))
                    }

                    Chip {
                        visible: item.mine
                        text: page.doomed === item.modelData ? "Really delete?" : "Delete"
                        lit: page.doomed === item.modelData
                        onClicked: {
                            if (page.doomed !== item.modelData) {
                                page.doomed = item.modelData;
                                return;
                            }
                            page.doomed = "";
                            page.attempt(() => Theme.remove(item.modelData));
                        }
                    }
                }
            }
        }

        SettingRow {
            title: "New theme"
            key: "theme.new"
            subtitle: page.fault !== "" ? page.fault : "Starts as a copy of the theme you use now"
            last: true

            Row {
                spacing: 8

                TextBox {
                    width: 200
                    text: page.newName
                    placeholder: "Night Owl"
                    onTextChanged: page.newName = text
                    onAccepted: page.attempt(() => page.edit(Theme.create(page.newName, "")))
                }

                Chip {
                    text: "Create"
                    lit: page.newName.trim() !== ""
                    onClicked: page.attempt(() => page.edit(Theme.create(page.newName, "")))
                }
            }
        }
    }

    Loader {
        active: page.editing !== ""
        width: parent.width
        sourceComponent: ThemeEditor {
            themeId: page.editing
            onDone: page.editing = ""
        }
    }

    Card {
        visible: page.editing === ""
        title: "Resin Glass"
        note: "Every panel, tile and card is drawn in translucent glass. Blur comes from your compositor."

        GlassPreview {}

        SettingRow {
            title: "Glass"
            key: "glass.enabled"
            subtitle: "Off brings back solid panels"

            Toggle {
                checked: Resin.enabled
                onToggled: v => Settings.put("glass.enabled", v)
            }
        }

        Repeater {
            model: host.glassKeys

            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.label
                key: "glass." + modelData.key
                last: index === host.glassKeys.length - 1
                opacity: Resin.enabled ? 1 : 0.45

                Slider {
                    width: 300
                    value: host.glass(modelData.key) / modelData.max
                    label: host.glass(modelData.key).toFixed(modelData.max < 1 ? 3 : 2)
                    onMoved: v => Settings.put("glass." + modelData.key, Math.round(v * modelData.max * 1000) / 1000)
                }
            }
        }
    }
}
