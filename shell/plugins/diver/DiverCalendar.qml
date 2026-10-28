import QtQuick
import qs
import qs.services
import qs.components
import qs.settings
import "../../lib/diver.mjs" as D
import "../../lib/plan.mjs" as P
import "../../lib/icons.mjs" as Icons

Item {
    id: root

    property int year: new Date(Diver.now).getFullYear()
    property int month: new Date(Diver.now).getMonth()
    property string day: Diver.today
    readonly property var busy: Diver.busy(root.year, root.month)
    readonly property int lead: (new Date(root.year, root.month, 1).getDay() + 6) % 7
    readonly property int length: new Date(root.year, root.month + 1, 0).getDate()
    readonly property var items: Diver.agenda(root.day)

    signal edit(string id, string where)
    signal create(string text, string day)
    signal focusTask(string id)

    function shift(d: int): void {
        const m = new Date(root.year, root.month + d, 1);
        root.year = m.getFullYear();
        root.month = m.getMonth();
    }

    Item {
        id: grid
        width: 380
        height: parent.height

        Row {
            id: head
            width: parent.width
            height: 36

            Glyph {
                width: 36
                height: 36
                text: Icons.GLYPHS.chevronLeft
                size: 18
                color: prevArea.containsMouse ? Theme.accent : Theme.textDim

                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shift(-1)
                }
            }

            Text {
                textFormat: Text.PlainText
                width: parent.width - 72
                height: 36
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
                color: Theme.text
                font.family: Tokens.fontDisplay
                font.pixelSize: Tokens.titleSize
                font.weight: Tokens.titleWeight
            }

            Glyph {
                width: 36
                height: 36
                text: Icons.GLYPHS.chevronRight
                size: 18
                color: nextArea.containsMouse ? Theme.accent : Theme.textDim

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shift(1)
                }
            }
        }

        Grid {
            id: cells
            anchors.top: head.bottom
            anchors.topMargin: 10
            columns: 7
            spacing: 4
            readonly property real cell: (grid.width - 6 * 4) / 7

            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                delegate: Text {
                    required property string modelData
                    width: cells.cell
                    height: 22
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }
            }

            Repeater {
                model: root.lead + root.length

                delegate: Item {
                    id: cell
                    required property int index
                    readonly property int date: cell.index - root.lead + 1
                    readonly property string key: cell.date > 0 ? D.dayKey(new Date(root.year, root.month, cell.date)) : ""
                    readonly property bool picked: cell.key === root.day
                    width: cells.cell
                    height: cells.cell * 0.86

                    Glass {
                        anchors.fill: parent
                        visible: cell.date > 0
                        radius: Tokens.r(12)
                        inner: true
                        lit: cell.picked
                        hot: dayArea.containsMouse
                        offBorder: cell.key === Diver.today ? Theme.accent : "transparent"
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        visible: cell.date > 0
                        text: cell.date
                        color: cell.picked ? Theme.onAccent : Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 5
                        visible: cell.date > 0 && (root.busy[cell.key] || 0) > 0
                        width: 5
                        height: 5
                        radius: 2.5
                        color: cell.picked ? Theme.onAccent : Theme.accent
                    }

                    MouseArea {
                        id: dayArea
                        anchors.fill: parent
                        enabled: cell.date > 0
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.day = cell.key
                    }
                }
            }
        }
    }

    Item {
        anchors.left: grid.right
        anchors.leftMargin: 28
        anchors.right: parent.right
        height: parent.height

        Text {
            textFormat: Text.PlainText
            id: dayTitle
            height: 36
            verticalAlignment: Text.AlignVCenter
            text: P.dayLabel(root.day) + (root.day === Diver.today ? "  ·  today" : "")
            color: Theme.text
            font.family: Tokens.fontDisplay
            font.pixelSize: Tokens.titleSize
            font.weight: Tokens.titleWeight
        }

        Row {
            id: addRow
            anchors.top: dayTitle.bottom
            anchors.topMargin: 10
            width: parent.width
            spacing: 8

            Chip {
                text: "Details"
                glyph: Icons.GLYPHS.pencil
                onClicked: root.create("", root.day)
            }
        }

        Flickable {
            anchors.top: addRow.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            width: parent.width
            contentHeight: dayList.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: dayList
                width: parent.width
                spacing: 6

                Text {
                    textFormat: Text.PlainText
                    visible: root.items.length === 0
                    topPadding: 12
                    text: "Nothing on this day yet."
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }

                Repeater {
                    model: root.items

                    delegate: DiverTaskRow {
                        required property var modelData
                        width: dayList.width
                        task: modelData.task
                        when: modelData.allDay ? "all day" : Qt.formatTime(new Date(modelData.start), "HH:mm")
                        path: modelData.path.filter(Boolean).join(" › ")
                        showPath: true
                        onOpen: root.edit(modelData.task.id, modelData.ci + "-" + modelData.gi + "-" + modelData.si)
                        onFocusRequested: root.focusTask(modelData.task.id)
                    }
                }
            }
        }
    }
}
