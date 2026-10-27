import QtQuick
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Column {
    id: root

    readonly property var info: Ipc.snapshot.polkit || ({
            registered: false
        })

    signal previewRequested

    spacing: 24

    Card {
        title: "Authentication"
        note: "SylPolkit asks for your password when an app needs extra rights, like changing the time zone or mounting a disk. Only one such agent can run at a time, so stop any other one (hyprpolkitagent, polkit-gnome) for SylPolkit to take over."

        SettingRow {
            title: root.info.registered ? "SylPolkit is handling requests" : "Another agent is handling requests"
            subtitle: root.info.registered ? "Password prompts appear in the Sylvaris style" : "SylPolkit takes over after the other agent stops and Sylvaris restarts"

            Glyph {
                text: root.info.registered ? Icons.GLYPHS.check : Icons.GLYPHS.lock
                size: 22
                color: root.info.registered ? Theme.accent : Theme.textDim
            }
        }

        SettingRow {
            title: "Preview"
            subtitle: "Shows the prompt with a sample request; the password “right” completes it"
            last: true

            RowButton {
                icon: Icons.GLYPHS.lock
                label: "Show"
                onClicked: root.previewRequested()
            }
        }
    }
}
