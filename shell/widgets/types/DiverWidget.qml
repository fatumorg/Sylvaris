import QtQuick
import qs
import qs.services
import qs.plugins.diver

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property var tasks: Diver.agendaToday.filter(x => root.o.done === true || !x.task.done).slice(0, root.o.count || 5)

    Text {
        id: title
        textFormat: Text.PlainText
        text: "Today"
        color: Theme.text
        font.family: Tokens.fontDisplay
        font.pixelSize: Tokens.bodySize
        font.weight: Font.DemiBold
    }

    Text {
        textFormat: Text.PlainText
        visible: root.tasks.length === 0
        anchors.centerIn: parent
        text: Diver.active ? "Nothing planned" : "Pair Diver in SylSettings › Plugins › Diver"
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    Column {
        y: title.height + 8
        width: parent.width
        height: parent.height - y
        clip: true

        Repeater {
            model: root.tasks

            delegate: DiverTaskRow {
                required property var modelData
                width: parent.width
                task: modelData.task
            }
        }
    }
}
