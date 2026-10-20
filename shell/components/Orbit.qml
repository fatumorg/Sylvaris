import QtQuick
import QtQuick.Shapes
import qs
import qs.services
import "../lib/orbit.mjs" as O

Item {
    id: root

    property string coreIcon: ""
    property string coreName: ""
    property string coreStatus: ""
    property bool statusError: false
    property bool scanning: false
    property var nodes: []
    property real centerX: width / 2
    property real centerY: Tokens.orbitCenterY
    property real t: 0
    property real enter: 1
    readonly property string keySignature: root.nodes.map(n => n.key).join("|")

    signal nodeClicked(string key)
    signal coreClicked

    function pos(index: int): var {
        const p = O.nodePosition(index, root.nodes.length, root.t, root.centerX, root.centerY);
        const f = 0.6 + 0.4 * root.enter;
        return {
            x: root.centerX + (p.x - root.centerX) * f,
            y: root.centerY + (p.y - root.centerY) * f
        };
    }

    onKeySignatureChanged: enterAnim.restart()

    HoverHandler {
        id: hover
    }

    FrameAnimation {
        running: root.visible && !hover.hovered && !Tokens.paused && Settings.values.constellation.speed > 0
        onTriggered: root.t += frameTime * Settings.values.constellation.speed
    }

    NumberAnimation {
        id: enterAnim
        target: root
        property: "enter"
        from: 0
        to: 1
        duration: Tokens.nodeMoveDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.enterCurve
    }

    Shape {
        visible: Settings.values.constellation.ring
        preferredRendererType: Shape.CurveRenderer
        anchors.fill: parent

        ShapePath {
            strokeColor: Theme.line
            strokeWidth: 1
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 9]

            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: O.GEOMETRY.ring.rx
                radiusY: O.GEOMETRY.ring.ry
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    Repeater {
        model: root.nodes
        delegate: SilkLink {
            required property var modelData
            required property int index
            anchors.fill: parent
            visible: modelData.linked === true && Settings.values.constellation.links
            opacity: root.enter
            geometry: {
                const p = root.pos(index);
                return O.linkGeometry(root.centerX, root.centerY, p.x, p.y, Tokens.haloSize / 2, root.t, index);
            }
        }
    }

    HaloCore {
        x: root.centerX - width / 2
        y: root.centerY - height / 2
        icon: root.coreIcon
        scanning: root.scanning
        t: root.t
        onClicked: root.coreClicked()
    }

    Rectangle {
        x: root.centerX - width / 2
        y: root.centerY + Tokens.coreLabelOffset - 4
        width: labelColumn.width + 20
        height: labelColumn.height + 8
        radius: 10
        color: "transparent"

        Glass {
            anchors.fill: parent
            z: -1
            radius: parent.radius
            inner: true
            offColor: Theme.surface
        }


        Column {
            id: labelColumn
            anchors.centerIn: parent
            spacing: 2

            Text {
                textFormat: Text.PlainText
                x: (parent.width - width) / 2
                width: Math.min(implicitWidth, 260)
                horizontalAlignment: Text.AlignHCenter
                text: root.coreName
                elide: Text.ElideRight
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.titleSize
                font.weight: Font.DemiBold
            }

            Text {
                textFormat: Text.PlainText
                x: (parent.width - width) / 2
                width: Math.min(implicitWidth, 260)
                horizontalAlignment: Text.AlignHCenter
                text: root.coreStatus
                elide: Text.ElideRight
                color: root.statusError ? Theme.danger : Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }
        }
    }

    Repeater {
        model: root.nodes
        delegate: OrbitNode {
            required property var modelData
            required property int index
            readonly property var p: root.pos(index)
            x: p.x - width / 2
            y: p.y - height / 2
            opacity: root.enter * (modelData.dim === true ? 0.6 : 1)
            icon: modelData.icon
            label: modelData.label
            sub: modelData.sub === undefined ? "" : modelData.sub
            danger: modelData.danger === true
            selected: modelData.selected === true
            bold: modelData.bold === true
            onClicked: root.nodeClicked(modelData.key)
        }
    }
}
