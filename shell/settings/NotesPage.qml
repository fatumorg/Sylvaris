import QtQuick
import qs
import qs.services
import qs.components

Column {
    id: root

    readonly property var cfg: Settings.shown.notes

    spacing: 24

    Card {
        title: "SylNotes"
        note: "A small editor for notes, configs and code. Open a file with “sylvaris notes open <file>”, or make it your default text editor. Unsaved typing is kept in ~/.local/state/sylvaris/notes until you save, so it survives a crash."

        SettingRow {
            title: "Wrap long lines"
            key: "notes.wrap"
            subtitle: "Alt+Z switches it in the editor"

            Toggle {
                checked: root.cfg.wrap
                onToggled: v => Settings.put("notes.wrap", v)
            }
        }

        SettingRow {
            title: "Line numbers"
            key: "notes.lineNumbers"

            Toggle {
                checked: root.cfg.lineNumbers
                onToggled: v => Settings.put("notes.lineNumbers", v)
            }
        }

        SettingRow {
            title: "Colour code"
            key: "notes.highlight"
            subtitle: "Colours by language, picked from the file name; files over 1 MB stay plain"

            Toggle {
                checked: root.cfg.highlight
                onToggled: v => Settings.put("notes.highlight", v)
            }
        }

        SettingRow {
            title: "Text size"
            key: "notes.size"

            Stepper {
                value: root.cfg.size
                from: 6
                to: 64
                step: 1
                onStepped: v => Settings.put("notes.size", v)
            }
        }

        SettingRow {
            title: "Indent with spaces"
            key: "notes.spaces"
            subtitle: "Off puts a tab character where you press Tab"

            Toggle {
                checked: root.cfg.spaces
                onToggled: v => Settings.put("notes.spaces", v)
            }
        }

        SettingRow {
            title: "Tab width"
            key: "notes.tabWidth"
            last: true

            Stepper {
                value: root.cfg.tabWidth
                from: 1
                to: 16
                step: 1
                onStepped: v => Settings.put("notes.tabWidth", v)
            }
        }
    }
}
