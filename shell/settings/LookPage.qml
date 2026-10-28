import QtQuick
import qs
import qs.services
import qs.components
import "../lib/look.mjs" as L

Column {
    id: page

    required property var host
    readonly property var cfg: Settings.shown.look
    property string fontSlot: "ui"
    property string fontQuery: ""
    property string saveName: ""
    property string saved: ""
    readonly property real roundness: page.cfg.radius !== undefined ? page.cfg.radius : Look.corners === "sharp" ? Look.radius * 4 : Look.radius
    readonly property var fontMatches: {
        const q = page.fontQuery.trim().toLowerCase();
        return q === "" ? [] : Look.families.filter(f => f.toLowerCase().indexOf(q) >= 0).slice(0, 8);
    }

    function options(list: var): var {
        return list.map(k => ({
                    key: k,
                    label: k.charAt(0).toUpperCase() + k.slice(1)
                }));
    }

    spacing: 24

    Card {
        title: "Style"
        note: "A Look is a whole style at once: glass, corners, spacing and type. Pick one, then change any part of it below."

        Flow {
            width: parent.width
            spacing: 12

            Repeater {
                model: Look.list()

                delegate: Item {
                    id: card

                    required property string modelData
                    readonly property var resolved: L.resolveLook({
                        preset: card.modelData
                    }, {}, Look.userLooks)
                    readonly property bool picked: Look.values.preset === card.modelData

                    width: 150
                    height: 104
                    scale: cardArea.pressed ? 0.96 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Tokens.stateDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.springCurve
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.r(16)
                        color: Theme.base
                        border.width: card.picked ? 2 : 1
                        border.color: card.picked ? Theme.accent : Theme.cardLine
                    }

                    Glass {
                        x: 14
                        y: 12
                        width: parent.width - 28
                        height: 50
                        radius: 14 * card.resolved.radius
                        preview: card.resolved.glass
                    }

                    Text {
                        textFormat: Text.PlainText
                        x: 14
                        y: 70
                        width: parent.width - 28
                        elide: Text.ElideRight
                        text: card.resolved.name
                        color: Theme.text
                        font.family: L.pickFont(card.resolved.fonts.display, Look.families, Tokens.fontDisplay)
                        font.pixelSize: Tokens.smallSize
                        font.weight: Font.DemiBold
                    }

                    Text {
                        textFormat: Text.PlainText
                        x: 14
                        y: 86
                        text: card.resolved.material + " · " + card.resolved.corners
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.tinySize
                    }

                    MouseArea {
                        id: cardArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Look.set(card.modelData)
                    }
                }
            }
        }

        SettingRow {
            title: "Follow the theme"
            subtitle: "Switch to the Look a theme was made for when you apply it"

            Toggle {
                checked: page.cfg.followTheme === true
                onToggled: v => Settings.put("look.followTheme", v)
            }
        }

        SettingRow {
            title: "Aurora"
            subtitle: "Slow accent lights behind full-screen parts, the lock and login screens"

            Toggle {
                checked: Look.values.aurora
                onToggled: v => Settings.put("look.aurora", v)
            }
        }

        SettingRow {
            title: "Save as your own"
            subtitle: page.saved !== "" ? "Saved as " + page.saved + "; share it with sylvaris look export" : "Keeps this Look with every change below"
            last: true

            Row {
                spacing: 8

                TextBox {
                    width: 200
                    text: page.saveName
                    placeholder: "Night Owl"
                    onTextChanged: page.saveName = text
                    onAccepted: page.saved = L.slugLook(page.saveName) === "" ? "" : Look.save(page.saveName)
                }

                Chip {
                    text: "Save"
                    lit: L.slugLook(page.saveName) !== ""
                    onClicked: {
                        if (L.slugLook(page.saveName) !== "")
                            page.saved = Look.save(page.saveName);
                    }
                }
            }
        }
    }

    Card {
        title: "Shape"
        note: "Each change here sits on top of the Look; picking a Look again clears them."

        SettingRow {
            title: "Material"
            subtitle: "The recipe for every glass surface"

            Segmented {
                width: 420
                options: page.options(Object.keys(L.MATERIALS))
                current: Look.material
                onPicked: key => Settings.put("look.material", key)
            }
        }

        SettingRow {
            title: "Corners"
            subtitle: "Round, smooth squircles, cut bevels or sharp"

            Segmented {
                width: 340
                options: page.options(L.CORNERS)
                current: Look.corners
                onPicked: key => Settings.put("look.corners", key)
            }
        }

        SettingRow {
            title: "Roundness"

            Slider {
                width: 300
                value: page.roundness / 2
                label: "×" + page.roundness.toFixed(2)
                onMoved: v => Settings.put("look.radius", Math.round(v * 2 * 20) / 20)
            }
        }

        SettingRow {
            title: "Spacing"

            Segmented {
                width: 300
                options: page.options(Object.keys(L.DENSITY))
                current: Look.values.densityName
                onPicked: key => Settings.put("look.density", key)
            }
        }

        Repeater {
            model: [
                {
                    key: "shadow",
                    title: "Shadow",
                    note: "Under cards and tiles"
                },
                {
                    key: "grain",
                    title: "Grain",
                    note: "A fine texture on panels"
                },
                {
                    key: "highlight",
                    title: "Highlight",
                    note: "Light along the top edge"
                },
                {
                    key: "glow",
                    title: "Glow",
                    note: "Accent light inside the rim"
                }
            ]

            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.title
                subtitle: modelData.note
                last: index === 3

                Slider {
                    width: 300
                    value: Look.glass[modelData.key]
                    label: Math.round(Look.glass[modelData.key] * 100) + "%"
                    onMoved: v => Settings.put("look." + modelData.key, Math.round(v * 20) / 20)
                }
            }
        }
    }

    Card {
        title: "Type"

        SettingRow {
            title: "Title weight"

            Segmented {
                width: 300
                options: page.options(L.WEIGHTS)
                current: Look.values.weight
                onPicked: key => Settings.put("look.weight", key)
            }
        }

        SettingRow {
            title: "Fonts"
            subtitle: "Interface " + Look.fonts.ui + ", titles " + Look.fonts.display + ", code " + Look.fonts.mono

            Segmented {
                width: 300
                options: [
                    {
                        key: "ui",
                        label: "Interface"
                    },
                    {
                        key: "display",
                        label: "Titles"
                    },
                    {
                        key: "mono",
                        label: "Code"
                    }
                ]
                current: page.fontSlot
                onPicked: key => page.fontSlot = key
            }
        }

        SettingRow {
            title: "Find a font"
            subtitle: page.fontMatches.length === 0 && page.fontQuery !== "" ? "No installed font matches" : "Pick one to use it for " + ({
                    ui: "the interface",
                    display: "titles",
                    mono: "code"
                })[page.fontSlot]
            last: true

            Column {
                spacing: 8

                TextBox {
                    width: 300
                    placeholder: "Inter"
                    onTextChanged: page.fontQuery = text
                }

                Flow {
                    width: 300
                    spacing: 6

                    Repeater {
                        model: page.fontMatches

                        delegate: Chip {
                            required property string modelData
                            text: modelData
                            lit: Look.fonts[page.fontSlot] === modelData
                            onClicked: Settings.put("look.fonts." + page.fontSlot, modelData)
                        }
                    }
                }
            }
        }
    }
}
