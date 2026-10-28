import QtQuick
import qs

Item {
    id: root

    property string text: ""
    property font font
    property color color: "white"

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row

        Repeater {
            model: root.text.length

            delegate: Item {
                id: slot

                required property int index
                readonly property string ch: root.text.charAt(slot.index)
                property string shown: slot.ch
                property string prev: ""
                property real t: 1

                width: now.implicitWidth
                height: now.implicitHeight
                clip: slot.t < 1

                onChChanged: {
                    slot.prev = slot.shown;
                    slot.shown = slot.ch;
                    if (Tokens.motion < 0.05 || Tokens.lite || slot.prev === "") {
                        roll.stop();
                        slot.t = 1;
                        return;
                    }
                    roll.restart();
                }

                NumberAnimation {
                    id: roll
                    target: slot
                    property: "t"
                    from: 0
                    to: 1
                    duration: Tokens.ms(260)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.springCurve
                }

                Text {
                    textFormat: Text.PlainText
                    visible: slot.t < 1
                    y: -slot.height * slot.t
                    opacity: 1 - slot.t
                    text: slot.prev
                    font: root.font
                    color: root.color
                }

                Text {
                    id: now
                    textFormat: Text.PlainText
                    y: slot.height * (1 - slot.t)
                    text: slot.shown
                    font: root.font
                    color: root.color
                }
            }
        }
    }
}
