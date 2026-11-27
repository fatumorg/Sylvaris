pragma ComponentBehavior: Bound
import QtQuick
import qs
import qs.services
import qs.components

Flickable {
    id: root

    property var hubs: []
    property int columns: 3
    property int hovered: -1

    signal pickedPage(string key)
    signal pickedHub(string key)
    signal hoveredHub(int index)

    clip: true
    contentHeight: grid.implicitHeight + 24
    boundsBehavior: Flickable.StopAtBounds

    Grid {
        id: grid
        width: root.width
        columns: root.columns
        spacing: 18

        Repeater {
            model: root.hubs

            delegate: Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool hot: cardArea.containsMouse || root.hovered === card.index || card.activeFocus
                width: (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                height: body.implicitHeight + 44
                activeFocusOnTab: true
                scale: cardArea.pressed ? 0.98 : 1
                Keys.onReturnPressed: root.pickedHub(card.modelData.key)
                Keys.onSpacePressed: root.pickedHub(card.modelData.key)

                Behavior on scale {
                    NumberAnimation {
                        duration: Tokens.stateDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.springCurve
                    }
                }

                Glass {
                    anchors.fill: parent
                    radius: Tokens.radiusPanel
                    raised: card.hot
                    hot: card.hot
                    offColor: Theme.surface
                    offBorder: Theme.line
                }

                MouseArea {
                    id: cardArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoveredHub(card.index)
                    onExited: root.hoveredHub(-1)
                    onClicked: root.pickedHub(card.modelData.key)
                }

                Column {
                    id: body
                    x: 22
                    y: 22
                    width: card.width - 44
                    spacing: 14

                    Row {
                        spacing: 12

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.modelData.glyph
                            size: 24
                            color: card.hot ? Theme.accentHi : Theme.accent
                        }

                        Text {
                            textFormat: Text.PlainText
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.modelData.label
                            color: Theme.text
                            font.family: Tokens.fontUi
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }
                    }

                    Flow {
                        width: body.width
                        spacing: 6

                        Repeater {
                            model: card.modelData.tabs

                            delegate: Item {
                                id: link
                                required property var modelData
                                readonly property bool lit: linkArea.containsMouse || link.activeFocus
                                width: name.implicitWidth + 20
                                height: 30
                                activeFocusOnTab: true
                                scale: linkArea.pressed ? 0.95 : 1
                                Keys.onReturnPressed: root.pickedPage(link.modelData.key)
                                Keys.onSpacePressed: root.pickedPage(link.modelData.key)

                                Glass {
                                    anchors.fill: parent
                                    radius: height / 2
                                    hot: link.lit
                                    lit: link.lit
                                }

                                Text {
                                    id: name
                                    textFormat: Text.PlainText
                                    anchors.centerIn: parent
                                    text: link.modelData.label
                                    color: link.lit ? Theme.onAccent : Theme.textSoft
                                    font.family: Tokens.fontUi
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: linkArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.pickedPage(link.modelData.key)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
