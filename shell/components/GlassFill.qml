import QtQuick
import QtQuick.Shapes

Shape {
    id: root

    property string path: ""
    property color fill: "transparent"
    property color stroke: "transparent"
    property real strokeWidth: 1
    property bool gradient: false
    property color from: "transparent"
    property real fade: 1

    preferredRendererType: Shape.CurveRenderer

    LinearGradient {
        id: grad
        x1: 0
        y1: 0
        x2: 0
        y2: root.height * root.fade
        GradientStop {
            position: 0
            color: root.from
        }
        GradientStop {
            position: 1
            color: "transparent"
        }
    }

    ShapePath {
        strokeWidth: root.stroke.a > 0 ? root.strokeWidth : -1
        strokeColor: root.stroke
        fillColor: root.fill
        fillGradient: root.gradient ? grad : null

        PathSvg {
            path: root.path
        }
    }
}
