import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Column {
    id: root

    readonly property var cfg: Settings.shown.top

    spacing: 24

    Card {
        title: "SylTop"
        note: "A task manager: processes as a list or a tree, live graphs for the processor, memory, disks, network, graphics and, with SylTemp on, temperatures, plus your startup apps, services and sessions. It reads /proc only while its window is open. Open it with “sylvaris top”, from the launcher, or bind Task manager under Key bindings (Ctrl+Shift+Escape works well)."

        SettingRow {
            title: "Show SylTop"
            key: "parts.top"
            subtitle: "Off removes it with its keybinding action; the same switch: sylvaris set parts.top false"

            Toggle {
                checked: Settings.shown.parts.top !== false
                onToggled: v => Settings.put("parts.top", v)
            }
        }

        SettingRow {
            title: "Refresh every"
            key: "top.interval"
            subtitle: "Faster graphs cost a little more processor time while the window is open"

            Segmented {
                width: 260
                current: String(root.cfg.interval)
                options: [1, 2, 3, 5].map(s => ({
                            key: String(s),
                            label: s + " s"
                        }))
                onPicked: key => Settings.put("top.interval", Number(key))
            }
        }

        SettingRow {
            title: "Show processes as a tree"
            key: "top.tree"
            subtitle: "Children sit under the process that started them; a search shows a flat list"
            last: true

            Toggle {
                checked: root.cfg.tree
                onToggled: v => Settings.put("top.tree", v)
            }
        }
    }

    RowButton {
        icon: Icons.GLYPHS.chart
        label: "Open SylTop"
        onClicked: Ipc.run(["top", "open"])
    }
}
