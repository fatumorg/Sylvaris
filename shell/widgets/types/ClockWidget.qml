import QtQuick
import qs
import qs.services
import qs.components
import "../../lib/widgets.mjs" as Wd

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property var zones: (root.o.zones || []).map(z => Wd.zoneTime(face.now, z, root.o.hours24 !== false)).filter(z => z !== null)

    ClockFace {
        id: face
        width: parent.width
        height: parent.height - (zoneRow.visible ? zoneRow.height + 8 : 0)
        face: root.o.face || "digital"
        hours24: root.o.hours24 !== false
        seconds: root.o.seconds === true
        dateFormat: root.o.date !== undefined ? root.o.date : ""
        align: root.o.align || "center"
        family: root.o.font || ""
        accent: root.frame !== null ? root.frame.accent : Theme.accent
        paused: root.frame !== null && root.frame.paused
    }

    Row {
        id: zoneRow
        visible: root.zones.length > 0 && root.height > 110
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 16

        Repeater {
            model: root.zones

            delegate: Column {
                required property var modelData

                Text {
                    textFormat: Text.PlainText
                    text: modelData.time
                    color: Theme.text
                    font.family: Tokens.fontMono
                    font.pixelSize: Tokens.bodySize
                }

                Text {
                    textFormat: Text.PlainText
                    text: modelData.label
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }
            }
        }
    }
}
