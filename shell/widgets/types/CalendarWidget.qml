import QtQuick
import qs
import qs.services
import qs.plugins.diver
import "../../lib/calendar.mjs" as C

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    property date now: new Date()
    readonly property int firstDay: root.o.monday === false ? 0 : 1
    readonly property var cells: C.monthGrid(root.now.getFullYear(), root.now.getMonth(), root.firstDay)
    readonly property var labels: C.weekdayLabels(root.firstDay, [0, 1, 2, 3, 4, 5, 6].map(d => Qt.locale().dayName(d, Locale.NarrowFormat)))
    readonly property var busy: root.o.dots !== false && Settings.values.plugins.enabled.diver === true ? Diver.busy(root.now.getFullYear(), root.now.getMonth()) : ({})
    readonly property real cw: root.width / 7
    readonly property real ch: (root.height - title.height - 24) / 7

    function keyOf(cell: var): string {
        return cell.year + "-" + String(cell.month + 1).padStart(2, "0") + "-" + String(cell.day).padStart(2, "0");
    }

    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        onTriggered: root.now = new Date()
    }

    Text {
        id: title
        textFormat: Text.PlainText
        text: Qt.locale().standaloneMonthName(root.now.getMonth()) + " " + root.now.getFullYear()
        color: Theme.text
        font.family: Tokens.fontDisplay
        font.pixelSize: Tokens.bodySize
        font.weight: Font.DemiBold
    }

    Grid {
        y: title.height + 8
        columns: 7

        Repeater {
            model: root.labels

            delegate: Text {
                required property string modelData
                textFormat: Text.PlainText
                width: root.cw
                height: root.ch
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.tinySize
            }
        }

        Repeater {
            model: root.cells

            delegate: Item {
                id: cell

                required property var modelData
                readonly property bool today: C.isSameDay(cell.modelData, root.now)

                width: root.cw
                height: root.ch

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 2
                    height: width
                    radius: width / 2
                    visible: cell.today
                    color: root.frame !== null ? root.frame.accent : Theme.accent
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: cell.modelData.day
                    opacity: cell.modelData.inMonth ? 1 : 0.35
                    color: cell.today ? Theme.onAccent : Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Math.max(10, Math.min(Tokens.smallSize, root.ch * 0.5))
                }

                Rectangle {
                    visible: (root.busy[root.keyOf(cell.modelData)] || 0) > 0 && !cell.today
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 4
                    height: 4
                    radius: width / 2
                    color: root.frame !== null ? root.frame.accent : Theme.accent
                }
            }
        }
    }
}
