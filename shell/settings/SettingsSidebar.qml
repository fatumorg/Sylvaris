pragma ComponentBehavior: Bound
import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: root

    property var hubs: []
    property string current: ""
    property string query: ""

    signal picked(string key)
    signal searched(string text)
    signal stepped(int d)
    signal accepted
    signal escaped

    function typeIn(text: string): void {
        box.text = box.text + text;
        box.focusInput();
    }

    onQueryChanged: {
        if (box.text !== root.query)
            box.text = root.query;
    }

    TextBox {
        id: box
        width: root.width
        placeholder: "Search settings"
        onTextChanged: root.searched(text)
        onAccepted: root.accepted()
        Keys.onUpPressed: root.stepped(-1)
        Keys.onDownPressed: root.stepped(1)
        Keys.onEscapePressed: root.escaped()
    }

    Flickable {
        id: list
        y: box.height + 14
        width: root.width
        height: footer.y - y - 12
        clip: true
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: list.width
            spacing: 2

            Repeater {
                model: root.hubs

                delegate: Column {
                    id: group
                    required property var modelData
                    required property int index
                    width: column.width
                    spacing: 2

                    Text {
                        textFormat: Text.PlainText
                        leftPadding: 12
                        topPadding: group.index === 0 ? 4 : 16
                        bottomPadding: 4
                        text: group.modelData.label.toUpperCase()
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                    }

                    Repeater {
                        model: group.modelData.tabs

                        delegate: Item {
                            id: tab
                            required property var modelData
                            readonly property bool on: tab.modelData.key === root.current
                            width: group.width
                            height: 38
                            activeFocusOnTab: true
                            Keys.onReturnPressed: root.picked(tab.modelData.key)
                            Keys.onSpacePressed: root.picked(tab.modelData.key)

                            Glass {
                                anchors.fill: parent
                                radius: Tokens.radiusRow
                                visible: tab.on || area.containsMouse || tab.activeFocus
                                lit: tab.on
                                hot: area.containsMouse || tab.activeFocus
                                raised: tab.on
                            }

                            Glyph {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.modelData.glyph
                                size: 18
                                color: tab.on ? Theme.onAccent : Theme.accent
                            }

                            Text {
                                textFormat: Text.PlainText
                                x: 42
                                width: parent.width - 50
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: tab.modelData.label
                                color: tab.on ? Theme.onAccent : Theme.text
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.bodySize
                                font.weight: tab.on ? Font.DemiBold : Font.Medium
                            }

                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.picked(tab.modelData.key)
                            }
                        }
                    }
                }
            }
        }
    }

    Column {
        id: footer
        y: root.height - height
        width: root.width
        spacing: 8

        Text {
            textFormat: Text.PlainText
            leftPadding: 12
            text: "SETTINGS HOME"
            color: Theme.textDim
            font.family: Tokens.fontUi
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
        }

        HomePicker {
            width: root.width
        }
    }
}
