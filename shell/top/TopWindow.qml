import QtQuick
import qs
import SylStack
import qs.services
import qs.components
import "../lib/top.mjs" as T
import "../lib/icons.mjs" as Icons

FloatingWindow {
    id: win

    required property var task

    title: win.task.title
    implicitWidth: 1080
    implicitHeight: 700
    minimumSize: Qt.size(720, 460)
    color: "transparent"
    BackgroundEffect.blurRegion: Resin.enabled ? blur : null
    onClosed: {
        const task = win.task;
        Qt.callLater(() => task.close());
    }

    Region {
        id: blur
        width: win.width
        height: win.height
    }

    Glass {
        role: "top"
        anchors.fill: parent
        raised: true
        offColor: Theme.surface
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.task.close()

        Column {
            id: side
            x: 12
            y: 14
            width: 196
            spacing: 4

            Row {
                x: 8
                height: 44
                spacing: 10

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.GLYPHS.chart
                    size: 22
                    color: Theme.accent
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SylTop"
                    color: Theme.text
                    font.family: Tokens.fontDisplay
                    font.pixelSize: Tokens.titleSize
                    font.weight: Tokens.titleWeight
                }
            }

            Repeater {
                model: T.PAGES

                delegate: Item {
                    id: tab

                    required property var modelData
                    readonly property bool current: win.task.page === tab.modelData.id

                    width: side.width
                    height: 40
                    Accessible.role: Accessible.PageTab
                    Accessible.name: tab.modelData.label

                    Glass {
                        anchors.fill: parent
                        radius: Tokens.radiusRow
                        inner: true
                        lit: tab.current
                        hot: tabArea.containsMouse
                        opacity: tab.current || tabArea.containsMouse ? 1 : 0
                    }

                    Glyph {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.GLYPHS[tab.modelData.glyph] || ""
                        size: 18
                        color: tab.current ? Theme.onAccent : Theme.textDim
                    }

                    Text {
                        textFormat: Text.PlainText
                        x: 42
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.label
                        color: tab.current ? Theme.onAccent : Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.bodySize
                        font.weight: tab.current ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: tabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.task.show(tab.modelData.id)
                    }
                }
            }
        }

        Column {
            x: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: side.width - 16
            spacing: 4
            visible: win.task.sample !== null

            Text {
                textFormat: Text.PlainText
                text: win.task.sample === null ? "" : "CPU " + Math.round(win.task.sample.cpu.total) + "%"
                color: Theme.textDim
                font.family: Tokens.fontMono
                font.pixelSize: Tokens.smallSize
            }

            Text {
                textFormat: Text.PlainText
                text: win.task.sample === null ? "" : win.task.sample.procs.length + " processes"
                color: Theme.textDim
                font.family: Tokens.fontMono
                font.pixelSize: Tokens.smallSize
            }
        }

        Item {
            id: main
            anchors.left: side.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.bottom: noteText.top
            anchors.bottomMargin: 8

            Loader {
                anchors.fill: parent
                sourceComponent: ({
                        processes: processesPage,
                        performance: performancePage,
                        startup: startupPage,
                        services: servicesPage,
                        users: usersPage
                    })[win.task.page]
            }
        }

        Text {
            id: noteText
            textFormat: Text.PlainText
            anchors.left: main.left
            anchors.right: main.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: win.task.note === "" ? 0 : 12
            height: win.task.note === "" ? 0 : implicitHeight
            text: win.task.note
            elide: Text.ElideRight
            color: Theme.danger
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }
    }

    Component {
        id: processesPage

        TopProcesses {
            task: win.task
        }
    }

    Component {
        id: performancePage

        TopPerformance {
            task: win.task
        }
    }

    Component {
        id: startupPage

        TopStartup {
            task: win.task
        }
    }

    Component {
        id: servicesPage

        TopServices {
            task: win.task
        }
    }

    Component {
        id: usersPage

        TopUsers {
            task: win.task
        }
    }
}
