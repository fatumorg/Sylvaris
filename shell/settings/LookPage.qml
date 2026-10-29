import QtQuick
import qs
import qs.services
import qs.components
import "../lib/look.mjs" as L

Column {
    id: page

    required property var host
    readonly property var cfg: Settings.shown.look
    property string editing: ""
    property string saveName: ""
    property string saved: ""
    property string hovered: ""
    property string peek: ""
    readonly property var studio: page.peek !== "" ? L.resolveLook({
        preset: page.peek
    }, {}, Look.userLooks) : Look.values

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
        visible: page.editing === ""
        title: "Style"
        note: "A style reshapes everything at once: glass, corners, fonts, switches, motion and layout. Point at one to try it here, click to keep it, or edit it to make it yours."

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

                    Caption {
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        text: page.peek !== "" ? "Trying" : "Your Look"
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

        StyleGallery {
            onEdit: id => page.editing = id
            onEntered: id => {
                page.hovered = id;
                peekTimer.restart();
            }
            onExited: id => {
                if (page.hovered !== id)
                    return;
                page.hovered = "";
                page.peek = "";
                peekTimer.stop();
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

    Loader {
        active: page.editing !== ""
        width: parent.width
        sourceComponent: StyleEditor {
            styleId: page.editing
            onDone: page.editing = ""
        }
    }
}
