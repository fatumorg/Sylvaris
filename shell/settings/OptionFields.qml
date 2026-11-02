import QtQuick
import qs.components
import "../lib/widgets.mjs" as Wd

Column {
    id: root

    property string type: ""
    property var values: ({})

    signal edited(string key, var value)

    function choices(list: var): var {
        return list.map(k => ({
                    key: String(k),
                    label: String(k).charAt(0).toUpperCase() + String(k).slice(1)
                }));
    }

    width: parent ? parent.width : 0

    Repeater {
        model: Wd.TYPES[root.type] === undefined ? [] : Wd.TYPES[root.type].fields.filter(f => f.hidden !== true)

        delegate: SettingRow {
            id: field

            required property var modelData

            title: field.modelData.label
            key: "widgets.option." + field.modelData.key
            readonly property var value: root.values === null || root.values === undefined ? undefined : root.values[field.modelData.key]

            Row {

                Toggle {
                    visible: field.modelData.kind === "toggle"
                    checked: field.value === true
                    onToggled: v => root.edited(field.modelData.key, v)
                }

                Segmented {
                    visible: field.modelData.kind === "choice"
                    width: Math.min(460, 80 * (field.modelData.choices || []).length)
                    options: root.choices(field.modelData.choices || [])
                    current: String(field.value)
                    onPicked: key => root.edited(field.modelData.key, typeof field.modelData.choices[0] === "number" ? Number(key) : key)
                }

                Slider {
                    visible: field.modelData.kind === "number" && field.modelData.max <= 1
                    width: 260
                    value: typeof field.value === "number" ? field.value : 0
                    label: Math.round((typeof field.value === "number" ? field.value : 0) * 100) + "%"
                    onMoved: v => root.edited(field.modelData.key, Math.round(v * 20) / 20)
                }

                Stepper {
                    visible: field.modelData.kind === "number" && field.modelData.max > 1
                    value: typeof field.value === "number" ? field.value : 0
                    from: field.modelData.min === undefined ? 0 : field.modelData.min
                    to: field.modelData.max === undefined ? 100 : field.modelData.max
                    onStepped: v => root.edited(field.modelData.key, v)
                }

                TextBox {
                    visible: field.modelData.kind === "text" || field.modelData.kind === "path" || field.modelData.kind === "list" || field.modelData.kind === "color"
                    width: 300
                    text: Array.isArray(field.value) ? field.value.join(", ") : field.value === undefined ? "" : String(field.value)
                    onAccepted: root.edited(field.modelData.key, field.modelData.kind === "list" ? text.split(",").map(s => s.trim()).filter(s => s !== "") : text)
                }
            }
        }
    }
}
