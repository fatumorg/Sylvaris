import QtQuick
import qs
import qs.services
import qs.components
import "../lib/look.mjs" as L

Card {
    id: root

    required property string section
    required property string styleId
    readonly property var values: Look.styleOr(root.styleId)[root.section]
    readonly property var fields: L.styleRows(root.section)
    property string fontSlot: "ui"
    property string fontQuery: ""
    readonly property var fontMatches: {
        const q = root.fontQuery.trim().toLowerCase();
        return q === "" ? [] : Look.families.filter(f => f.toLowerCase().indexOf(q) >= 0).slice(0, 8);
    }

    function label(v: var): string {
        const s = String(v);
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    function put(key: string, value: var): void {
        Look.update(root.styleId, root.section, key, value);
    }

    title: ({
            glass: "Glass",
            shape: "Shape",
            type: "Type",
            controls: "Controls",
            motion: "Motion",
            layout: "Layout",
            atmosphere: "Atmosphere"
        })[root.section]

    SettingRow {
        title: "Take from"
        key: "look.takeFrom"
        subtitle: "Copy this whole section from another style"

        Flow {
            width: 420
            spacing: 6

            Repeater {
                model: Look.list().filter(id => id !== root.styleId)

                delegate: Chip {
                    required property string modelData
                    text: Look.styleOr(modelData).name
                    onClicked: Look.takeFrom(root.styleId, root.section, modelData)
                }
            }

            Chip {
                text: "Reset section"
                onClicked: Look.resetSection(root.styleId, root.section)
            }
        }
    }

    Repeater {
        model: root.fields

        delegate: SettingRow {
            id: row

            required property var modelData
            required property int index
            readonly property var value: root.values[modelData.key] !== undefined ? root.values[modelData.key] : root.section === "glass" ? L.MATERIALS[root.values.material][modelData.key] : undefined

            title: modelData.title
            key: "style." + root.section + "." + modelData.key
            subtitle: modelData.path !== "" && Look.configOwned.indexOf(modelData.path) >= 0 ? "Set in your config; your config wins" : ""
            last: row.index === root.fields.length - 1 && root.section !== "type"

            Item {
                implicitWidth: 420
                implicitHeight: row.modelData.kind === "choice" ? pick.implicitHeight : row.modelData.kind === "number" ? amount.implicitHeight : flag.implicitHeight

                Segmented {
                    id: pick
                    visible: row.modelData.kind === "choice"
                    width: Math.min(420, 70 * (row.modelData.options || []).length)
                    anchors.right: parent.right
                    options: (row.modelData.options || []).map(o => ({
                                key: o,
                                label: root.label(o)
                            }))
                    current: String(row.value)
                    onPicked: key => root.put(row.modelData.key, key)
                }

                Slider {
                    id: amount
                    visible: row.modelData.kind === "number"
                    width: 300
                    anchors.right: parent.right
                    readonly property real lo: row.modelData.min || 0
                    readonly property real hi: row.modelData.max === undefined ? 1 : row.modelData.max
                    value: (Number(row.value) - amount.lo) / (amount.hi - amount.lo)
                    label: Number(row.value).toFixed(2)
                    onMoved: v => {
                        const step = row.modelData.step || 0.05;
                        root.put(row.modelData.key, Math.round(Math.round((amount.lo + v * (amount.hi - amount.lo)) / step) * step * 100) / 100);
                    }
                }

                Toggle {
                    id: flag
                    visible: row.modelData.kind === "bool"
                    anchors.right: parent.right
                    checked: row.value === true
                    onToggled: v => root.put(row.modelData.key, v)
                }
            }
        }
    }

    SettingRow {
        visible: root.section === "type"
        title: "Fonts"
        key: "look.fonts"
        subtitle: root.section === "type" ? "Interface " + root.values.fonts.ui + ", titles " + root.values.fonts.display + ", code " + root.values.fonts.mono : ""

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
            current: root.fontSlot
            onPicked: key => root.fontSlot = key
        }
    }

    SettingRow {
        visible: root.section === "type"
        title: "Find a font"
        key: "look.fontSearch"
        subtitle: root.fontMatches.length === 0 && root.fontQuery !== "" ? "No installed font matches" : "Pick one to use it for " + ({
                ui: "the interface",
                display: "titles",
                mono: "code"
            })[root.fontSlot]
        last: true

        Column {
            spacing: 8

            TextBox {
                width: 300
                placeholder: "Inter"
                onTextChanged: root.fontQuery = text
            }

            Flow {
                width: 300
                spacing: 6

                Repeater {
                    model: root.fontMatches

                    delegate: Chip {
                        required property string modelData
                        text: modelData
                        lit: root.values.fonts[root.fontSlot] === modelData
                        onClicked: root.put("fonts", Object.assign({}, root.values.fonts, {
                            [root.fontSlot]: modelData
                        }))
                    }
                }
            }
        }
    }
}
