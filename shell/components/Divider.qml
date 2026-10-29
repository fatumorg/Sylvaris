import QtQuick
import QtQuick.Shapes
import qs
import qs.services

Item {
    id: root

    readonly property string kind: Tokens.dividerStyle

    width: parent ? parent.width : 0
    implicitHeight: root.kind === "none" ? 0 : 1

    Rectangle {
        visible: root.kind === "hairline"
        anchors.fill: parent
        color: Theme.line
    }

    Shape {
        visible: root.kind === "dashed"
        anchors.fill: parent

        ShapePath {
            strokeColor: Theme.line
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 3]
            fillColor: "transparent"
            PathPolyline {
                path: [Qt.point(0, 0.5), Qt.point(root.width, 0.5)]
            }
        }
    }
}
