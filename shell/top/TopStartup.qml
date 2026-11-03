import QtQuick
import qs
import qs.services
import qs.components
import qs.settings
import "../lib/icons.mjs" as Icons

Flickable {
    id: page

    required property var task
    readonly property var info: page.task.startup

    contentHeight: body.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: body
        width: page.width
        spacing: 6

        Text {
            textFormat: Text.PlainText
            text: "Apps that start when you log in"
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
            font.weight: Font.DemiBold
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            wrapMode: Text.Wrap
            text: "From ~/.config/autostart and the system autostart folders. Turning one off writes your own copy with Hidden=true, so the system file stays as it is. It takes effect at your next login."
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }

        Repeater {
            model: page.info === null ? [] : page.info.apps

            delegate: SettingRow {
                required property var modelData
                width: body.width
                title: modelData.name
                subtitle: modelData.exec + (modelData.mine ? "" : " · system")

                Toggle {
                    checked: modelData.on
                    onToggled: v => page.task.autostart(modelData.file, v)
                }
            }
        }

        Item {
            width: 1
            height: 12
        }

        Text {
            textFormat: Text.PlainText
            text: "Your services"
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
            font.weight: Font.DemiBold
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            wrapMode: Text.Wrap
            text: "systemd --user units that are enabled or can be. Switching one runs systemctl --user enable or disable."
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }

        Repeater {
            model: page.info === null ? [] : page.info.units

            delegate: SettingRow {
                required property var modelData
                width: body.width
                title: modelData.unit

                Toggle {
                    checked: modelData.on
                    onToggled: v => page.task.unit("user", v ? "enable" : "disable", modelData.unit)
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            visible: page.info === null
            text: "Reading…"
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }
    }
}
