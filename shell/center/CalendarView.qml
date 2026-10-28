import QtQuick
import qs
import qs.services
import qs.plugins.diver
import qs.components
import "../lib/calendar.mjs" as C
import "../lib/icons.mjs" as Icons

Item {
    id: root

    signal closeRequested

    property date today: new Date()
    property int year: root.today.getFullYear()
    property int month: root.today.getMonth()
    readonly property int firstDay: Qt.locale().firstDayOfWeek
    readonly property var cells: C.monthGrid(root.year, root.month, root.firstDay)
    readonly property var labels: C.weekdayLabels(root.firstDay, [0, 1, 2, 3, 4, 5, 6].map(d => Qt.locale().dayName(d, Locale.ShortFormat)))
    readonly property int cellWidth: 66
    readonly property bool planner: Diver.active
    readonly property int cellHeight: root.planner ? 42 : 56
    readonly property var busy: Diver.busy(root.year, root.month)
    property string picked: Qt.formatDate(root.today, "yyyy-MM-dd")

    function shift(delta: int): void {
        const m = C.shiftMonth(root.year, root.month, delta);
        root.year = m.year;
        root.month = m.month;
    }

    ViewHeader {
        title: Qt.locale().standaloneMonthName(root.month, Locale.LongFormat) + " " + root.year
        onBack: root.closeRequested()
    }

    Row {
        x: parent.width - width - 28
        y: 20
        spacing: 18

        Repeater {
            model: [
                {
                    glyph: Icons.GLYPHS.chevronLeft,
                    delta: -1
                },
                {
                    glyph: Icons.GLYPHS.chevronRight,
                    delta: 1
                }
            ]
            delegate: Glyph {
                required property var modelData
                text: modelData.glyph
                size: 26
                color: Theme.accent

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shift(modelData.delta)
                }
            }
        }
    }

    Grid {
        x: (parent.width - width) / 2
        y: 96
        columns: 7
        columnSpacing: 12
        rowSpacing: 10

        Repeater {
            model: root.labels
            delegate: Text {
                required property var modelData
                width: root.cellWidth
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }
        }

        Repeater {
            model: root.cells
            delegate: Rectangle {
                id: dayCell
                required property var modelData
                readonly property bool isToday: C.isSameDay(modelData, root.today)
                readonly property string key: modelData.year + "-" + String(modelData.month + 1).padStart(2, "0") + "-" + String(modelData.day).padStart(2, "0")
                readonly property int count: root.busy[dayCell.key] || 0
                width: root.cellWidth
                height: root.cellHeight
                border.width: root.planner && root.picked === dayCell.key ? 1.5 : 0
                border.color: Theme.accent
                radius: Tokens.radiusRow
                color: "transparent"

                Glass {
                    anchors.fill: parent
                    z: -1
                    visible: parent.isToday || modelData.inMonth
                    radius: parent.radius
                    inner: true
                    lit: parent.isToday
                }


                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    spacing: 3
                    visible: dayCell.count > 0

                    Repeater {
                        model: Math.min(3, dayCell.count)

                        delegate: Rectangle {
                            width: 4
                            height: 4
                            radius: Tokens.r(2)
                            color: dayCell.isToday ? Theme.onAccent : Theme.accent
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.planner
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked = dayCell.key
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: modelData.day
                    color: parent.isToday ? Theme.onAccent : Theme.text
                    opacity: modelData.inMonth ? 1 : 0.4
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.bodySize
                    font.weight: parent.isToday ? Font.DemiBold : Font.Normal
                }
            }
        }
    }

    DayAgenda {
        visible: root.planner
        x: 28
        y: 96 + 7 * (root.cellHeight + 10) + 4
        width: parent.width - 56
        height: parent.height - y - 24
        day: root.picked
        rows: 3
        onClosed: root.picked = Qt.formatDate(root.today, "yyyy-MM-dd")
    }

    RowButton {
        visible: !root.planner
        x: (parent.width - width) / 2
        y: parent.height - height - 28
        icon: Icons.GLYPHS.check
        label: "Today · " + Qt.formatDate(root.today, "dddd, d MMMM")
        onClicked: {
            root.year = root.today.getFullYear();
            root.month = root.today.getMonth();
        }
    }
}
