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
    property string hovered: ""
    property string peek: ""
    readonly property var studio: page.peek !== "" ? L.resolveLook({
        preset: page.peek
    }, {}, Look.userLooks) : Look.values
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

    Timer {
        id: peekTimer
        interval: Tokens.previewDelay
        onTriggered: page.peek = page.hovered
    }

    Card {
        title: "Style"
        note: "A Look is a whole style at once: glass, corners, spacing and type. Point at one to try it here, click to keep it, then change any part of it below."

        Item {
            id: stage
            width: parent.width
            height: 200

            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: Tokens.r(16)
                color: Theme.base
                border.width: 1
                border.color: Theme.cardLine
                clip: true

                Rectangle {
                    width: parent.width * 0.6
                    height: width
                    x: -width * 0.2
                    y: -height * 0.55
                    radius: width / 2
                    color: Qt.alpha(Theme.accent, 0.35)
                }

                Rectangle {
                    width: parent.width * 0.4
                    height: width
                    x: parent.width - width * 0.7
                    y: parent.height - height * 0.35
                    radius: width / 2
                    color: Qt.alpha(Theme.accent, 0.18)
                }

                Glass {
                    id: sample
                    x: 28
                    y: 22
                    width: Math.min(420, parent.width - 220)
                    height: parent.height - 44
                    radius: Tokens.r(18) * page.studio.radius
                    preview: page.studio.glass

                    Text {
                        textFormat: Text.PlainText
                        x: 20
                        y: 16
                        text: "Good evening"
                        color: Theme.text
                        font.family: L.pickFont(page.studio.fonts.display, Look.families, Tokens.fontDisplay)
                        font.pixelSize: Tokens.titleSize
                        font.weight: page.studio.weight === "light" ? Font.Normal : page.studio.weight === "medium" ? Font.Bold : Font.DemiBold
                    }

                    Text {
                        textFormat: Text.PlainText
                        x: 20
                        y: 50
                        text: "Wi-Fi, Bluetooth and sound"
                        color: Theme.textDim
                        font.family: L.pickFont(page.studio.fonts.ui, Look.families, Tokens.fontUi)
                        font.pixelSize: Tokens.smallSize
                    }

                    Row {
                        x: 20
                        y: parent.height - height - 16
                        spacing: Math.round(8 * page.studio.density)

                        Repeater {
                            model: ["Wi-Fi", "Night light", "12:40"]

                            delegate: Glass {
                                id: chip

                                required property string modelData
                                required property int index

                                inner: true
                                lit: chip.index === 0
                                preview: page.studio.glass
                                radius: Tokens.r(12) * page.studio.radius
                                width: chipText.implicitWidth + 24
                                height: 32

                                Text {
                                    id: chipText
                                    textFormat: Text.PlainText
                                    anchors.centerIn: parent
                                    text: chip.modelData
                                    color: chip.index === 0 ? Theme.onAccent : Theme.text
                                    font.family: chip.index === 2 ? L.pickFont(page.studio.fonts.mono, Look.families, Tokens.fontMono) : L.pickFont(page.studio.fonts.ui, Look.families, Tokens.fontUi)
                                    font.pixelSize: Tokens.smallSize
                                }
                            }
                        }
                    }
                }

                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    width: 160
                    spacing: 4

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        text: page.peek !== "" ? "Trying" : "Your Look"
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.tinySize
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.6
                    }

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        text: page.studio.name
                        color: Theme.text
                        font.family: L.pickFont(page.studio.fonts.display, Look.families, Tokens.fontDisplay)
                        font.pixelSize: Tokens.bodySize
                        font.weight: Font.DemiBold
                    }

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        text: page.studio.material + " · " + page.studio.corners + " · " + page.studio.densityName
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.tinySize
                    }
                }
            }
        }

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
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            page.hovered = card.modelData;
                            peekTimer.restart();
                        }
                        onExited: {
                            if (page.hovered !== card.modelData)
                                return;
                            page.hovered = "";
                            page.peek = "";
                            peekTimer.stop();
                        }
                        onClicked: {
                            page.peek = "";
                            Look.set(card.modelData);
                        }
                    }
                }
            }
        }

        SettingRow {
            title: "Follow the theme"
            key: "look.followTheme"
            subtitle: "Switch to the Look a theme was made for when you apply it"

            Toggle {
                checked: page.cfg.followTheme === true
                onToggled: v => Settings.put("look.followTheme", v)
            }
        }

        SettingRow {
            title: "Shuffle"
            key: "look.shuffle"
            subtitle: "Pick a new Look and theme for you every day, or right now"

            Row {
                spacing: 8

                Segmented {
                    width: 200
                    options: page.options(["off", "daily"])
                    current: page.cfg.shuffle === "daily" ? "daily" : "off"
                    onPicked: key => Settings.put("look.shuffle", key)
                }

                Chip {
                    text: "Shuffle now"
                    onClicked: Look.shuffle(Date.now())
                }
            }
        }

        SettingRow {
            title: "Aurora"
            key: "look.aurora"
            subtitle: "Slow accent lights behind full-screen parts, the lock and login screens"

            Toggle {
                checked: Look.values.aurora
                onToggled: v => Settings.put("look.aurora", v)
            }
        }

        SettingRow {
            title: "Save as your own"
            key: "look.save"
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
            key: "look.material"
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
            key: "look.corners"
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
            key: "look.radius"

            Slider {
                width: 300
                value: page.roundness / 2
                label: "×" + page.roundness.toFixed(2)
                onMoved: v => Settings.put("look.radius", Math.round(v * 2 * 20) / 20)
            }
        }

        SettingRow {
            title: "Spacing"
            key: "look.density"

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
                key: "look." + modelData.key
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
            key: "look.weight"

            Segmented {
                width: 300
                options: page.options(L.WEIGHTS)
                current: Look.values.weight
                onPicked: key => Settings.put("look.weight", key)
            }
        }

        SettingRow {
            title: "Fonts"
            key: "look.fonts"
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
            key: "look.fontSearch"
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
