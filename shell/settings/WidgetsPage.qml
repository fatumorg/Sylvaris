import QtQuick
import qs.services
import qs.components
import "../lib/widgets.mjs" as Wd
import "../lib/icons.mjs" as Icons

Column {
    id: page

    readonly property var cfg: Settings.values.widgets
    property string selected: ""
    readonly property var picked: page.cfg.items.find(i => i.id === page.selected) || page.cfg.items.map(i => (i.children || []).find(c => c.id === page.selected)).find(c => c !== undefined) || null
    readonly property var parentStack: page.picked === null ? null : page.cfg.items.find(i => (i.children || []).some(c => c.id === page.picked.id)) || null
    readonly property var stackable: page.types.filter(t => t !== "stack" && t !== "terminal")
    readonly property var types: Object.keys(Wd.TYPES).filter(t => Wd.TYPES[t].plugin === undefined || Settings.values.plugins.enabled[Wd.TYPES[t].plugin] === true)

    function stored(list: var): var {
        return list.map(i => {
            const out = Object.assign({}, i);
            delete out.inactive;
            if (out.children)
                out.children = page.stored(out.children);
            return out;
        });
    }

    function patch(id: string, change: var): void {
        Settings.set("widgets.items", page.stored(page.cfg.items.map(i => i.id === id ? Object.assign({}, i, change) : i.children && i.children.some(c => c.id === id) ? Object.assign({}, i, {
                children: i.children.map(c => c.id === id ? Object.assign({}, c, change) : c)
            }) : i)));
    }

    function addToStack(type: string): void {
        const ids = page.cfg.items.reduce((all, i) => all.concat([i.id], (i.children || []).map(c => c.id)), []);
        const t = Wd.TYPES[type];
        page.patch(page.picked.id, {
            children: (page.picked.children || []).concat([{
                    id: Wd.newId(ids),
                    type: type,
                    w: t.size[0],
                    h: t.size[1],
                    options: {}
                }])
        });
    }

    function option(key: string, value: var): void {
        page.patch(page.selected, {
            options: Object.assign({}, page.picked.options, {
                [key]: value
            })
        });
    }

    function options(list: var): var {
        return list.map(k => ({
                    key: String(k),
                    label: String(k).charAt(0).toUpperCase() + String(k).slice(1)
                }));
    }

    spacing: 24

    Card {
        title: "Widgets"
        note: "Clocks, weather, a calendar, photos, a terminal and more, right on the desktop. Edit them in place to drag, resize, add and remove; every widget follows your Look."

        SettingRow {
            title: "Show widgets"
            key: "widgets.enabled"

            Toggle {
                checked: page.cfg.enabled
                onToggled: v => Settings.set("widgets.enabled", v)
            }
        }

        SettingRow {
            title: "Edit on the desktop"
            key: "widgets.edit"
            subtitle: "Or run sylvaris widgets edit"

            Chip {
                text: "Edit widgets"
                glyph: Icons.GLYPHS.pencil
                onClicked: Ipc.run(["widgets", "edit"])
            }
        }

        SettingRow {
            title: "Grid size"
            key: "widgets.cell"
            subtitle: "One cell of the grid widgets snap to"
            advanced: true

            Stepper {
                value: page.cfg.cell
                from: 32
                to: 240
                step: 8
                suffix: " px"
                onStepped: v => Settings.set("widgets.cell", v)
            }
        }

        SettingRow {
            title: "Gap"
            key: "widgets.gap"
            advanced: true
            last: true

            Stepper {
                value: page.cfg.gap
                from: 0
                to: 64
                step: 4
                suffix: " px"
                onStepped: v => Settings.set("widgets.gap", v)
            }
        }
    }

    Card {
        title: "Your widgets"
        note: page.cfg.items.length === 0 ? "None yet. Add one below; it lands in the top-left corner of the focused screen." : page.cfg.items.length + " of " + Wd.LIMIT + ". Pick one to change it."

        Repeater {
            model: page.cfg.items

            delegate: SettingRow {
                id: entry

                required property var modelData
                required property int index

                title: Wd.TYPES[entry.modelData.type].label + (entry.modelData.inactive ? " (plugin off)" : "")
                key: "widgets.items." + entry.modelData.id
                subtitle: entry.modelData.id + " · " + entry.modelData.w + "×" + entry.modelData.h + " · " + (entry.modelData.screen || "first screen") + " · " + entry.modelData.anchor
                last: entry.index === page.cfg.items.length - 1

                Row {
                    spacing: 6

                    Chip {
                        text: "Change"
                        lit: page.selected === entry.modelData.id
                        onClicked: page.selected = page.selected === entry.modelData.id ? "" : entry.modelData.id
                    }

                    Chip {
                        text: "Remove"
                        onClicked: Ipc.run(["widgets", "remove", entry.modelData.id])
                    }
                }
            }
        }

        SettingRow {
            title: "Add a widget"
            key: "widgets.add"
            last: true

            Flow {
                width: 560
                spacing: 6
                layoutDirection: Qt.RightToLeft

                Repeater {
                    model: page.types

                    delegate: Chip {
                        required property string modelData
                        text: Wd.TYPES[modelData].label
                        glyph: Icons.GLYPHS[Wd.TYPES[modelData].glyph] || ""
                        onClicked: Ipc.run(["widgets", "add", modelData])
                    }
                }
            }
        }
    }

    Card {
        visible: page.picked !== null
        title: page.picked === null ? "" : Wd.TYPES[page.picked.type].label + " " + page.picked.id + (page.parentStack !== null ? " in stack " + page.parentStack.id : "")

        SettingRow {
            visible: page.picked !== null && page.picked.type === "stack"
            title: "In this stack"
            key: "widgets.stack"
            subtitle: page.picked === null || !page.picked.children || page.picked.children.length === 0 ? "Nothing yet; add widgets below. Scroll over the stack to flip through them." : page.picked.children.map(c => Wd.TYPES[c.type].label + " " + c.id).join(", ")

            Column {
                spacing: 6

                Repeater {
                    model: page.picked === null || page.picked.type !== "stack" ? [] : page.picked.children || []

                    delegate: Row {
                        id: kid

                        required property var modelData

                        spacing: 6
                        layoutDirection: Qt.RightToLeft

                        Chip {
                            text: "Remove " + Wd.TYPES[kid.modelData.type].label
                            onClicked: page.patch(page.picked.id, {
                                    children: page.picked.children.filter(c => c.id !== kid.modelData.id)
                                })
                        }

                        Chip {
                            text: "Change " + Wd.TYPES[kid.modelData.type].label
                            onClicked: page.selected = kid.modelData.id
                        }
                    }
                }
            }
        }

        SettingRow {
            visible: page.picked !== null && page.picked.type === "stack"
            title: "Add to the stack"
            key: "widgets.stack.add"

            Flow {
                width: 560
                spacing: 6
                layoutDirection: Qt.RightToLeft

                Repeater {
                    model: page.picked !== null && page.picked.type === "stack" ? page.stackable : []

                    delegate: Chip {
                        required property string modelData
                        text: Wd.TYPES[modelData].label
                        glyph: Icons.GLYPHS[Wd.TYPES[modelData].glyph] || ""
                        onClicked: page.addToStack(modelData)
                    }
                }
            }
        }

        SettingRow {
            visible: page.parentStack !== null
            title: "Back to the stack"
            key: "widgets.stack.back"

            Chip {
                text: page.parentStack === null ? "" : "Stack " + page.parentStack.id
                onClicked: page.selected = page.parentStack.id
            }
        }

        Repeater {
            model: page.picked === null ? [] : Wd.TYPES[page.picked.type].fields.filter(f => f.hidden !== true)

            delegate: SettingRow {
                id: field

                required property var modelData

                title: field.modelData.label
                key: "widgets.option." + field.modelData.key
                readonly property var value: page.picked === null ? undefined : page.picked.options[field.modelData.key]

                Row {

                    Toggle {
                        visible: field.modelData.kind === "toggle"
                        checked: field.value === true
                        onToggled: v => page.option(field.modelData.key, v)
                    }

                    Segmented {
                        visible: field.modelData.kind === "choice"
                        width: Math.min(460, 80 * (field.modelData.choices || []).length)
                        options: page.options(field.modelData.choices || [])
                        current: String(field.value)
                        onPicked: key => page.option(field.modelData.key, typeof field.modelData.choices[0] === "number" ? Number(key) : key)
                    }

                    Slider {
                        visible: field.modelData.kind === "number" && field.modelData.max <= 1
                        width: 260
                        value: typeof field.value === "number" ? field.value : 0
                        label: Math.round((typeof field.value === "number" ? field.value : 0) * 100) + "%"
                        onMoved: v => page.option(field.modelData.key, Math.round(v * 20) / 20)
                    }

                    Stepper {
                        visible: field.modelData.kind === "number" && field.modelData.max > 1
                        value: typeof field.value === "number" ? field.value : 0
                        from: field.modelData.min === undefined ? 0 : field.modelData.min
                        to: field.modelData.max === undefined ? 100 : field.modelData.max
                        onStepped: v => page.option(field.modelData.key, v)
                    }

                    TextBox {
                        visible: field.modelData.kind === "text" || field.modelData.kind === "path" || field.modelData.kind === "list" || field.modelData.kind === "color"
                        width: 300
                        text: Array.isArray(field.value) ? field.value.join(", ") : field.value === undefined ? "" : String(field.value)
                        onAccepted: page.option(field.modelData.key, field.modelData.kind === "list" ? text.split(",").map(s => s.trim()).filter(s => s !== "") : text)
                    }
                }
            }
        }

        SettingRow {
            visible: page.parentStack === null
            title: "Size"
            key: "widgets.size"
            subtitle: page.picked === null ? "" : page.picked.w + " × " + page.picked.h + " cells"

            Segmented {
                width: 200
                options: [
                    {
                        key: "S",
                        label: "S"
                    },
                    {
                        key: "M",
                        label: "M"
                    },
                    {
                        key: "L",
                        label: "L"
                    }
                ]
                current: ""
                onPicked: key => {
                    const p = Wd.TYPES[page.picked.type].sizes.presets[key];
                    const r = Wd.resizeTo(page.picked, p[0], p[1]);
                    page.patch(page.selected, {
                        w: r.w,
                        h: r.h
                    });
                }
            }
        }

        SettingRow {
            visible: page.parentStack === null
            title: "Layer"
            key: "widgets.layer"
            subtitle: "On the desktop under windows, above them, or over everything"

            Segmented {
                width: 300
                options: page.options(Wd.LAYERS)
                current: page.picked === null ? "" : page.picked.layer
                onPicked: key => page.patch(page.selected, {
                        layer: key
                    })
            }
        }

        SettingRow {
            visible: page.parentStack === null
            title: "Click through"
            key: "widgets.clickThrough"
            subtitle: "Clicks go to whatever is under the widget"

            Toggle {
                checked: page.picked !== null && page.picked.clickThrough
                onToggled: v => page.patch(page.selected, {
                        clickThrough: v
                    })
            }
        }

        SettingRow {
            visible: page.parentStack === null
            title: "Hide behind full-screen windows"
            key: "widgets.hideFullscreen"
            last: true

            Toggle {
                checked: page.picked !== null && page.picked.hideFullscreen
                onToggled: v => page.patch(page.selected, {
                        hideFullscreen: v
                    })
            }
        }
    }

    Card {
        title: "Style"
        note: "Shared by every widget; Inherit follows your Look."

        SettingRow {
            title: "Material"
            key: "widgets.style.material"

            Segmented {
                width: 420
                options: page.options(Wd.MATERIALS)
                current: page.cfg.style.material
                onPicked: key => Settings.set("widgets.style.material", key)
            }
        }

        SettingRow {
            title: "Opacity"
            key: "widgets.style.opacity"

            Slider {
                width: 260
                value: page.cfg.style.opacity
                label: Math.round(page.cfg.style.opacity * 100) + "%"
                onMoved: v => Settings.set("widgets.style.opacity", Math.round(v * 20) / 20)
            }
        }

        SettingRow {
            title: "Roundness"
            key: "widgets.style.radius"

            Slider {
                width: 260
                value: page.cfg.style.radius / 3
                label: "×" + page.cfg.style.radius.toFixed(2)
                onMoved: v => Settings.set("widgets.style.radius", Math.round(v * 3 * 20) / 20)
            }
        }

        SettingRow {
            title: "Shadow"
            key: "widgets.style.shadow"
            last: true

            Toggle {
                checked: page.cfg.style.shadow
                onToggled: v => Settings.set("widgets.style.shadow", v)
            }
        }
    }
}
