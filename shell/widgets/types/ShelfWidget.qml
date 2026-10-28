import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: root

    property var frame: null
    readonly property var o: root.frame !== null && root.frame.item !== null ? root.frame.item.options : ({})
    readonly property var ids: root.o.apps && root.o.apps.length > 0 ? root.o.apps : Settings.values.deck.pinned
    readonly property var apps: root.ids.map(id => Demo.enabled ? Apps.byId(id) : Apps.entry(id)).filter(a => a !== null && a !== undefined)
    readonly property bool labels: root.o.labels === true
    readonly property real cell: root.apps.length === 0 ? 0 : Math.min(root.height, (root.width - (root.apps.length - 1) * 8) / root.apps.length)
    readonly property real icon: Math.max(16, Math.min(64, root.cell - (root.labels ? 22 : 4)))

    Text {
        textFormat: Text.PlainText
        visible: root.apps.length === 0
        anchors.fill: parent
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: "Pin apps to SylDeck or list them in SylSettings › Desktop › Widgets"
        color: Theme.textDim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.smallSize
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: root.apps

            delegate: Item {
                id: slot

                required property var modelData

                width: root.cell
                height: root.cell

                Image {
                    id: icon
                    width: root.icon
                    height: root.icon
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.labels ? (parent.height - height - 18) / 2 : (parent.height - height) / 2
                    source: Apps.icon(slot.modelData)
                    sourceSize.width: root.icon * 2
                    sourceSize.height: root.icon * 2
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    scale: hover.hovered ? 1.12 : 1
                    layer.enabled: Tokens.iconTint
                    layer.effect: IconTint {}

                    Behavior on scale {
                        NumberAnimation {
                            duration: Tokens.fadeDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.moveCurve
                        }
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    visible: root.labels
                    anchors.top: icon.bottom
                    anchors.topMargin: 4
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: slot.modelData.name
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.tinySize
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: Apps.launch(slot.modelData)
                }
            }
        }
    }
}
