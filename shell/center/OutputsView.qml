import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons

Item {
    id: root

    signal closeRequested

    ViewHeader {
        title: "Sound output"
        onBack: root.closeRequested()
    }

    Flickable {
        x: 28
        y: 84
        width: parent.width - 56
        height: volumeSlider.y - y - 16
        contentHeight: list.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list
            width: parent.width
            spacing: 8

            Repeater {
                model: Audio.sinks
                delegate: Rectangle {
                    required property var modelData
                    width: parent.width
                    height: 56
                    radius: Tokens.radiusRow
                    color: "transparent"

                    Glass {
                        anchors.fill: parent
                        z: -1
                        radius: parent.radius
                        inner: true
                        hot: rowHover.hovered
                        offColor: modelData.current ? Theme.tintStrong : rowHover.hovered ? Theme.tintMid : Theme.tintSoft
                    }

                    border.width: modelData.current ? 1 : 0
                    border.color: Theme.accent

                    HoverHandler {
                        id: rowHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    Glyph {
                        id: speaker
                        x: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.GLYPHS.speaker
                        size: 20
                        color: Theme.accent
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.left: speaker.right
                        anchors.leftMargin: 14
                        anchors.right: check.left
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.bodySize
                    }

                    Glyph {
                        id: check
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.current
                        text: Icons.GLYPHS.check
                        size: 20
                        color: Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Audio.setDefault(modelData.key)
                    }
                }
            }

            Repeater {
                model: [
                    {
                        kind: "play",
                        title: "Apps"
                    },
                    {
                        kind: "record",
                        title: "Recording"
                    }
                ]
                delegate: Column {
                    id: section
                    required property var modelData
                    readonly property var keys: Audio.streams.filter(s => s.kind === section.modelData.kind).map(s => s.key)
                    width: parent.width
                    spacing: 8
                    visible: section.keys.length > 0

                    Text {
                        textFormat: Text.PlainText
                        topPadding: 12
                        text: section.modelData.title
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                        font.weight: Font.DemiBold
                    }

                    Repeater {
                        model: section.keys
                        delegate: Slider {
                            required property string modelData
                            readonly property var stream: Audio.streams.find(s => s.key === modelData) || {
                                kind: "play",
                                app: "",
                                title: "",
                                volume: 0,
                                muted: false,
                                device: null,
                                live: false
                            }
                            readonly property string device: Audio.deviceName(stream.device)
                            width: parent.width
                            opacity: stream.live ? 1 : 0.5
                            value: stream.muted ? 0 : stream.volume
                            icon: stream.kind === "record" ? (stream.muted ? Icons.GLYPHS.micOff : Icons.GLYPHS.mic) : stream.muted ? Icons.GLYPHS.volumeMute : Icons.GLYPHS.volume
                            label: stream.title === "" ? stream.app : stream.app + " · " + stream.title
                            trailing: Math.round(stream.volume * 100) + "%" + (device === "" ? "" : " · " + device)
                            onMoved: v => Audio.setStreamVolume(modelData, v)
                            onIconClicked: Audio.toggleStreamMute(modelData)
                            onTrailingClicked: Audio.cycleDevice(modelData)
                        }
                    }
                }
            }
        }
    }

    Slider {
        id: volumeSlider
        x: 28
        y: parent.height - height - 28
        width: parent.width - 56
        value: Audio.muted ? 0 : Audio.volume
        icon: Audio.muted ? Icons.GLYPHS.volumeMute : Icons.GLYPHS.volume
        label: Math.round(Audio.volume * 100) + "%"
        onMoved: v => Audio.setVolume(v)
        onIconClicked: Audio.toggleMute()
    }
}
