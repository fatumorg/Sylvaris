import QtQuick
import qs
import qs.services
import qs.components
import qs.settings
import "../lib/icons.mjs" as Icons

Item {
    id: page

    required property var task
    property string scope: "system"
    property string query: ""
    readonly property var all: page.task.services === null ? [] : page.task.services[page.scope] || []
    readonly property var shown: page.all.filter(u => page.query === "" || (u.unit + " " + u.description).toLowerCase().indexOf(page.query.toLowerCase()) >= 0)

    Row {
        id: tools
        width: parent.width
        spacing: 8

        Segmented {
            width: 220
            current: page.scope
            options: [
                {
                    key: "system",
                    label: "System"
                },
                {
                    key: "user",
                    label: "Yours"
                }
            ]
            onPicked: key => page.scope = key
        }

        TextBox {
            width: Math.min(320, parent.width - 236 - refresh.width - 8)
            placeholder: "Search services"
            onTextChanged: page.query = text
        }

        Chip {
            id: refresh
            anchors.verticalCenter: parent.verticalCenter
            text: "Refresh"
            glyph: Icons.GLYPHS.restart
            onClicked: page.task.show("services")
        }
    }

    Text {
        id: hint
        anchors.top: tools.bottom
        anchors.topMargin: 8
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: page.scope === "system" ? "System services start, stop and restart through pkexec, so you are asked for your password." : "Your own systemd --user services."
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    ListView {
        id: list
        anchors.top: hint.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: page.shown
        reuseItems: true

        delegate: Item {
            id: row

            required property var modelData
            readonly property bool running: row.modelData.active === "active"

            width: list.width
            height: 46

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusRow
                inner: true
                hot: rowArea.containsMouse
                opacity: rowArea.containsMouse ? 1 : 0.5
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
            }

            Column {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24 - actions.width
                spacing: 2

                Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: row.modelData.description || row.modelData.unit
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                    font.weight: Font.DemiBold
                }

                Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: row.modelData.unit + " · " + row.modelData.active + " (" + row.modelData.sub + ")"
                    elide: Text.ElideRight
                    color: row.running ? Theme.accent : Theme.textDim
                    font.family: Tokens.fontMono
                    font.pixelSize: Tokens.tinySize
                }
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Chip {
                    text: row.running ? "Stop" : "Start"
                    onClicked: page.task.unit(page.scope, row.running ? "stop" : "start", row.modelData.unit)
                }

                Chip {
                    text: "Restart"
                    visible: row.running
                    onClicked: page.task.unit(page.scope, "restart", row.modelData.unit)
                }
            }
        }
    }
}
