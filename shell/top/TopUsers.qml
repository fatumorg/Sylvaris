import QtQuick
import qs
import qs.services
import qs.components
import qs.settings
import "../lib/icons.mjs" as Icons

Column {
    id: page

    required property var task
    readonly property var list: page.task.sessions === null ? [] : page.task.sessions

    spacing: 6

    Text {
        textFormat: Text.PlainText
        text: "Sessions"
        color: Theme.text
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.bodySize
        font.weight: Font.DemiBold
    }

    Text {
        textFormat: Text.PlainText
        width: parent.width
        wrapMode: Text.Wrap
        text: "Who is logged in, from loginctl. Processes per user are on the Processes page: search for the user name."
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    Repeater {
        model: page.list

        delegate: SettingRow {
            required property var modelData
            width: page.width
            title: modelData.user + " · session " + modelData.id
            subtitle: [modelData.type, modelData.class, modelData.seat, modelData.tty, modelData.remote ? "remote" : "local", modelData.state].filter(x => x !== "").join(" · ")

            Chip {
                text: "Show processes"
                glyph: Icons.GLYPHS.search
                onClicked: page.task.find(modelData.user)
            }
        }
    }

    Chip {
        text: "Refresh"
        glyph: Icons.GLYPHS.restart
        onClicked: page.task.show("users")
    }
}
