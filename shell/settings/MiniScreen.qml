import QtQuick
import qs
import qs.services
import qs.components
import "../lib/bar.mjs" as B
import "../lib/motion.mjs" as M

Item {
    id: root

    property bool showBar: true
    property bool dim: true
    readonly property var bar: Settings.shown.bar
    readonly property bool barOn: root.showBar && root.bar.enabled && Settings.shown.parts.bar
    readonly property bool vertical: B.vertical(root.bar.position)
    readonly property real k: screen.width / 1920
    readonly property real barThick: Math.max(6, 44 * root.k)
    readonly property alias stage: stage
    default property alias content: stage.data

    function spot(corner: string, w: real, h: real): var {
        const o = M.origin(corner);
        const pad = 6;
        const gap = root.barOn ? root.barThick + 8 : 0;
        const top = pad + (root.barOn && root.bar.position === "top" ? gap : 0);
        const bottom = pad + (root.barOn && root.bar.position === "bottom" ? gap : 0);
        const left = pad + (root.barOn && root.bar.position === "left" ? gap : 0);
        const right = pad + (root.barOn && root.bar.position === "right" ? gap : 0);
        return {
            x: left + (stage.width - left - right - w) * o.h,
            y: top + (stage.height - top - bottom - h) * o.v
        };
    }

    width: parent ? parent.width : 0
    height: Math.min(230, Math.round(width * 9 / 16))

    Item {
        id: screen
        anchors.centerIn: parent
        height: parent.height
        width: Math.round(height * 16 / 9)
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.base
            border.width: 1
            border.color: Theme.line
        }

        Image {
            anchors.fill: parent
            anchors.margins: 1
            source: Theme.wallpaper === "" ? "" : "file://" + Theme.wallpaper
            sourceSize.width: 480
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: root.dim ? 0.55 : 1
        }

        Item {
            id: stage
            anchors.fill: parent
        }

        Repeater {
            model: root.barOn ? (root.bar.style === "islands" ? ["left", "center", "right"] : ["all"]) : []

            delegate: Rectangle {
                required property string modelData
                readonly property int count: modelData === "all" ? root.bar.left.length + root.bar.center.length + root.bar.right.length : root.bar[modelData].length
                readonly property real along: modelData === "all" ? (root.vertical ? screen.height : screen.width) - 8 : Math.max(10, count * 9 + 6)
                readonly property real at: modelData === "left" || modelData === "all" ? 4 : modelData === "center" ? ((root.vertical ? screen.height : screen.width) - along) / 2 : (root.vertical ? screen.height : screen.width) - along - 4
                visible: count > 0
                x: root.vertical ? (root.bar.position === "left" ? 4 : screen.width - width - 4) : at
                y: root.vertical ? at : (root.bar.position === "top" ? 4 : screen.height - height - 4)
                width: root.vertical ? root.barThick : along
                height: root.vertical ? along : root.barThick
                radius: Math.min(width, height) / 2
                color: Qt.alpha(Theme.surface, 0.85)
                border.width: 1
                border.color: Theme.line

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

                Grid {
                    anchors.centerIn: parent
                    rows: root.vertical ? -1 : 1
                    columns: root.vertical ? 1 : -1
                    spacing: 4

                    Repeater {
                        model: Math.min(parent.parent.count, 20)

                        delegate: Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: index === 0 ? Theme.accent : Qt.alpha(Theme.text, 0.6)
                        }
                    }
                }
            }
        }
    }
}
