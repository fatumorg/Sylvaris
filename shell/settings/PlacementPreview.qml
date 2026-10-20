import QtQuick
import qs
import qs.services
import qs.components
import "../lib/bar.mjs" as B
import "../lib/notify.mjs" as N

MiniScreen {
    id: root

    readonly property string pos: Settings.shown.parts.bar ? Settings.shown.bar.position : "top"
    readonly property var boxes: [
        {
            label: "SylCenter",
            corner: B.placeCorner(Settings.shown.center.corner, root.pos),
            w: 460,
            h: 560
        },
        {
            label: "SylClock",
            corner: B.placeCorner(Settings.shown.clock.corner, root.pos),
            w: 700,
            h: 420
        },
        {
            label: "Toasts",
            corner: B.placeCorner(Settings.shown.notifications.corner, root.pos),
            w: 380,
            h: 110
        }
    ]

    Repeater {
        model: root.boxes

        delegate: Rectangle {
            required property var modelData
            required property int index
            readonly property var at: root.spot(modelData.corner, modelData.w * root.k, modelData.h * root.k)
            readonly property var shift: index === 2 ? N.toastShift(modelData.corner, "s", {
                corner: root.boxes[0].corner,
                width: root.boxes[0].w * root.k,
                height: root.boxes[0].h * root.k,
                screen: "s"
            }, 10 * root.k) : ({
                x: 0,
                y: 0
            })
            x: at.x + (modelData.corner.indexOf("right") > 0 ? -shift.x : shift.x)
            y: at.y + (modelData.corner.indexOf("bottom") === 0 ? -shift.y : shift.y)
            z: index === 2 ? 2 : 1
            width: modelData.w * root.k
            height: modelData.h * root.k
            radius: 6
            color: Qt.alpha(index === 2 ? Theme.accent : Theme.surface, index === 2 ? 0.8 : 0.9)
            border.width: 1
            border.color: index === 2 ? Theme.accentHi : Theme.line

            Behavior on x {
                NumberAnimation {
                    duration: Tokens.moveDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.enterCurve
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: Tokens.moveDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.enterCurve
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: modelData.label
                color: index === 2 ? Theme.onAccent : Theme.textSoft
                font.family: Tokens.fontUi
                font.pixelSize: 9
            }
        }
    }
}
