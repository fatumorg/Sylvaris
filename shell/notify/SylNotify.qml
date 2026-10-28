import QtQuick
import qs
import qs.services
import qs.components
import "../lib/notify.mjs" as N
import "../lib/icons.mjs" as Icons
import "../lib/motion.mjs" as M

Popup {
    id: root

    readonly property var groups: N.groups(Notifications.list, e => e.n.appName)

    namespace: "sylnotify"
    corner: root.local.notifications.corner
    panelWidth: Tokens.notifyWidth
    panelHeight: Tokens.notifyHeight

    onShownChanged: Notifications.centerOpen = root.shown

    Item {
        id: header
        x: Tokens.panelPaddingX
        y: 22
        width: parent.width - Tokens.panelPaddingX * 2
        height: 44

        Text {
            textFormat: Text.PlainText
            id: title
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.text
            font.family: Tokens.fontDisplay
            font.pixelSize: Tokens.titleSize + 3
            font.weight: Tokens.titleWeight
        }

        Rectangle {
            visible: Notifications.count > 0
            anchors.left: title.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(24, countText.implicitWidth + 14)
            height: 24
            radius: Tokens.r(12)
            color: Theme.accent

            Text {
                textFormat: Text.PlainText
                id: countText
                anchors.centerIn: parent
                text: Notifications.count
                color: Theme.onAccent
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.tinySize
                font.weight: Font.DemiBold
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Repeater {
                model: [
                    {
                        key: "dnd",
                        glyph: Icons.GLYPHS.dnd,
                        lit: Dnd.enabled,
                        show: Dnd.available
                    },
                    {
                        key: "clear",
                        glyph: Icons.GLYPHS.clearAll,
                        lit: false,
                        show: Notifications.count > 0
                    }
                ]
                delegate: Item {
                    required property var modelData
                    visible: modelData.show
                    width: 40
                    height: 40

                    Glass {
                        anchors.fill: parent
                        radius: Tokens.r(20)
                        inner: true
                        lit: modelData.lit
                        hot: area.containsMouse
                        offBorder: Theme.cardLine
                    }

                    Glyph {
                        anchors.centerIn: parent
                        text: modelData.glyph
                        size: 18
                        color: modelData.lit ? Theme.onAccent : Theme.text
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.key === "dnd")
                                Dnd.setEnabled(!Dnd.enabled);
                            else
                                Notifications.clear();
                        }
                    }
                }
            }
        }
    }

    Text {
        textFormat: Text.PlainText
        visible: Dnd.enabled
        x: Tokens.panelPaddingX
        anchors.top: header.bottom
        text: "Do not disturb is on. Only urgent notifications pop up."
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    ListView {
        id: list
        x: Tokens.panelPaddingX - 6
        y: header.y + header.height + (Dnd.enabled ? 30 : 12)
        width: parent.width - (Tokens.panelPaddingX - 6) * 2
        height: parent.height - y - 18
        clip: true
        spacing: Tokens.gap
        boundsBehavior: Flickable.StopAtBounds
        model: root.groups

        delegate: Column {
            id: group
            required property var modelData
            required property int index
            readonly property real arrive: M.stagger(root.phase, Math.min(group.index, 6), 7, Math.min(0.9, Tokens.staggerSpread * 10 / 7))
            width: list.width
            spacing: 8
            opacity: group.arrive

            transform: Translate {
                y: 18 * (1 - group.arrive)
            }

            Item {
                width: parent.width
                height: 22

                Text {
                    textFormat: Text.PlainText
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: group.modelData.app
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                    font.weight: Font.DemiBold
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clear"
                    color: clearArea.containsMouse ? Theme.accent : Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            for (const e of group.modelData.items)
                                Notifications.dismiss(e.id);
                        }
                    }
                }
            }

            Repeater {
                model: group.modelData.items
                delegate: NotificationCard {
                    required property var modelData
                    width: group.width
                    height: implicitHeight
                    entry: modelData
                }
            }
        }
    }

    Column {
        visible: Notifications.count === 0
        anchors.centerIn: parent
        spacing: 10

        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons.GLYPHS.bell
            size: 44
            color: Theme.textDim
            opacity: 0.6
        }

        Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: "You're all caught up"
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
            font.weight: Font.DemiBold
        }

        Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: "New notifications will show up here"
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }
    }
}
