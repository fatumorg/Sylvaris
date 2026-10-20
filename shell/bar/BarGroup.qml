import QtQuick
import Quickshell
import qs
import qs.services
import qs.components

Item {
    id: root

    property var list: []
    property string side: "left"
    property bool islands: true
    property bool vertical: false
    property var barWindow: null
    property var moduleFor: null
    readonly property int pad: root.islands ? Tokens.barPadding : 0
    readonly property Region blur: Region {
        x: root.x + 1
        y: root.y + 1
        width: Math.max(0, root.width - 2)
        height: Math.max(0, root.height - 2)
        radius: Tokens.barRadius - 1
    }

    property bool room: true
    visible: root.room && root.list.length > 0 && (root.vertical ? grid.implicitHeight : grid.implicitWidth) > 0
    width: root.vertical ? (root.parent ? root.parent.width : 0) : grid.implicitWidth + root.pad * 2
    height: root.vertical ? grid.implicitHeight + root.pad * 2 : (root.parent ? root.parent.height : 0)

    Behavior on width {
        enabled: !root.vertical
        NumberAnimation {
            duration: Tokens.moveDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.moveCurve
        }
    }

    Behavior on height {
        enabled: root.vertical
        NumberAnimation {
            duration: Tokens.moveDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.moveCurve
        }
    }

    Glass {
        anchors.fill: parent
        visible: root.islands
        flowing: false
        radius: Tokens.barRadius
        offColor: Theme.surface
        offBorder: Theme.line
    }

    Grid {
        id: grid
        anchors.centerIn: parent
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        spacing: Tokens.barGap
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Tokens.enterDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.enterCurve
            }
        }

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Tokens.moveDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.moveCurve
            }
        }

        Repeater {
            model: root.list

            delegate: Loader {
                id: slot
                required property string modelData
                visible: slot.item !== null && slot.item.wanted !== false
                sourceComponent: root.moduleFor === null ? null : root.moduleFor(slot.modelData)
                onLoaded: {
                    slot.item.screenRef = root.barWindow.modelData;
                    slot.item.win = root.barWindow;
                    if (slot.item.hasOwnProperty("moduleName"))
                        slot.item.moduleName = slot.modelData;
                }
            }
        }
    }
}
