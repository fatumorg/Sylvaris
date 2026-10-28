import QtQuick
import qs
import qs.services
import qs.plugins.diver
import "../lib/icons.mjs" as Icons

Item {
    id: root

    property string day: ""
    property int rows: 3
    readonly property var items: root.day === "" ? [] : Diver.agenda(root.day)
    readonly property string title: {
        if (root.day === "")
            return "";
        const d = new Date(root.day + "T12:00:00");
        return root.day === Diver.today ? "Today" : Qt.formatDate(d, "dddd, d MMMM");
    }

    signal closed

    Row {
        id: head
        width: parent.width
        spacing: 8

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.GLYPHS.planner
            size: 16
            color: Theme.accent
        }

        Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (Diver.planner ? 60 + openLabel.width + 8 : 60)
            text: root.title + (root.items.length > 0 ? " · " + root.items.length : "")
            elide: Text.ElideRight
            color: Theme.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.bodySize
            font.weight: Font.DemiBold
        }

        Text {
            textFormat: Text.PlainText
            id: openLabel
            visible: Diver.planner
            anchors.verticalCenter: parent.verticalCenter
            text: "Diver ›"
            color: openArea.containsMouse ? Theme.accentHi : Theme.accent
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
            font.weight: Font.DemiBold
            scale: openArea.pressed ? 0.94 : 1

            MouseArea {
                id: openArea
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Diver.request("day", "", root.day)
            }
        }

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.GLYPHS.close
            size: 14
            color: closeArea.containsMouse ? Theme.text : Theme.textDim

            MouseArea {
                id: closeArea
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closed()
            }
        }
    }

    Column {
        id: list
        anchors.top: head.bottom
        anchors.topMargin: 8
        width: parent.width
        spacing: 2

        Text {
            textFormat: Text.PlainText
            visible: root.items.length === 0
            text: Diver.plugged && (Diver.paired || Demo.enabled) ? "Nothing planned" : "Pair Diver in SylSettings to see your plans"
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }

        Repeater {
            model: root.items.slice(0, root.rows)

            delegate: Item {
                id: entry
                required property var modelData
                required property int index
                width: list.width
                height: 24
                opacity: 0
                Component.onCompleted: fade.start()

                NumberAnimation {
                    id: fade
                    target: entry
                    property: "opacity"
                    to: 1
                    duration: Tokens.enterDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.enterCurve
                }

                Rectangle {
                    x: 16
                    width: parent.width - 16
                    height: parent.height
                    radius: Tokens.r(8)
                    color: Qt.alpha(Theme.text, 0.07)
                    opacity: rowArea.containsMouse ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Tokens.stateDuration
                        }
                    }
                }

                MouseArea {
                    id: rowArea
                    x: 18
                    width: parent.width - 18
                    height: parent.height
                    enabled: Diver.planner
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Diver.request("edit", entry.modelData.task.id, "")
                }

                Rectangle {
                    id: tick
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: Tokens.r(7)
                    color: tickArea.containsMouse ? Qt.alpha(Theme.accent, 0.4) : "transparent"
                    border.width: 1.5
                    border.color: entry.modelData.task.alarm ? Theme.danger : Theme.accent

                    MouseArea {
                        id: tickArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Diver.done(entry.modelData.task.id)
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    x: 22
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    text: entry.modelData.allDay ? "·" : Qt.formatTime(new Date(entry.modelData.start), "HH:mm")
                    color: Theme.accent
                    font.family: Tokens.fontMono
                    font.pixelSize: Tokens.tinySize
                }

                Text {
                    textFormat: Text.PlainText
                    x: 70
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x
                    text: Diver.plain(entry.modelData.task.text) + (entry.modelData.task.alarm ? "  " + Icons.GLYPHS.alarm : "") + (entry.modelData.task.rule || entry.modelData.task.repeat ? "  " + Icons.GLYPHS.repeat : "")
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            visible: root.items.length > root.rows
            text: "+ " + (root.items.length - root.rows) + " more"
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
        }
    }

    Item {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 30
        visible: Diver.plugged && (Diver.paired || Demo.enabled)

        Rectangle {
            anchors.fill: parent
            radius: Tokens.r(10)
            color: Qt.alpha(Theme.text, 0.06)
            border.width: 1
            border.color: input.activeFocus ? Theme.accent : Qt.alpha(Theme.text, 0.1)
        }

        Text {
            textFormat: Text.PlainText
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: "Add to this day… “call Ana 18:00”"
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.tinySize
        }

        Glyph {
            visible: Diver.planner
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.GLYPHS.pencil
            size: 13
            color: moreArea.containsMouse ? Theme.accent : Theme.textDim

            MouseArea {
                id: moreArea
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Diver.request("new", input.text, root.day);
                    input.text = "";
                }
            }
        }

        TextInput {
            id: input
            x: 12
            width: parent.width - (Diver.planner ? 44 : 24)
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            clip: true
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
            onAccepted: {
                if (text.trim() === "")
                    return;
                Diver.add(text, root.day);
                text = "";
            }
        }
    }
}
