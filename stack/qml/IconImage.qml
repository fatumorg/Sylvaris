import QtQuick

Item {
    id: root

    property alias source: image.source
    property real implicitSize: 0
    property alias asynchronous: image.asynchronous
    property alias status: image.status
    property alias mipmap: image.mipmap

    implicitWidth: root.implicitSize
    implicitHeight: root.implicitSize

    Image {
        id: image

        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        sourceSize.width: Math.ceil(Math.max(root.width, root.implicitSize) * (root.Window.window ? root.Window.window.devicePixelRatio : 1))
        sourceSize.height: Math.ceil(Math.max(root.height, root.implicitSize) * (root.Window.window ? root.Window.window.devicePixelRatio : 1))
    }
}
