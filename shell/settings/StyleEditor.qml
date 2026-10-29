import QtQuick
import qs
import qs.services
import qs.components
import "../lib/look.mjs" as L

Column {
    id: root

    required property string styleId
    readonly property var style: Look.styleOr(root.styleId)

    signal done

    spacing: 24

    Card {
        title: "Edit a style"
        note: "Every change applies at once and is kept in looks/" + root.styleId + ".json. Take a whole section from another style, then fine-tune it."

        SettingRow {
            title: "Name"
            key: "look.styleName"
            subtitle: ({
                    "built-in": "A built-in style; editing it keeps your version until you reset it",
                    "edited": "Your edit of a built-in style",
                    "yours": "Your own style"
                })[Look.origin(root.styleId)] || ""
            last: true

            Row {
                spacing: 8

                TextBox {
                    width: 220
                    text: root.style.name
                    placeholder: "My style"
                    onAccepted: {
                        if (text.trim() !== "")
                            Look.update(root.styleId, "name", "", text.trim());
                    }
                }

                Chip {
                    text: "Done"
                    lit: true
                    onClicked: root.done()
                }
            }
        }
    }

    Repeater {
        model: L.SECTIONS

        delegate: StyleSection {
            required property string modelData
            section: modelData
            styleId: root.styleId
        }
    }
}
