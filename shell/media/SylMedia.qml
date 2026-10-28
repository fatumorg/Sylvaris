import QtQuick
import QtQuick.Shapes
import SylStack
import qs
import qs.services
import qs.components
import "../lib/eq.mjs" as E
import "../lib/icons.mjs" as Icons

Popup {
    id: root

    property string tab: "playing"

    namespace: "sylmedia"
    corner: root.local.placement.media === "auto" ? root.local.center.corner : root.local.placement.media
    panelWidth: Tokens.mediaWidth
    panelHeight: Tokens.mediaHeight

    function time(s: real): string {
        const t = Math.max(0, Math.round(s));
        return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0");
    }

    function openTab(name: string): void {
        root.tab = name;
    }

    Timer {
        interval: 1000
        running: root.shown && root.tab === "playing" && Media.playing
        repeat: true
        onTriggered: {
            Media.tick();
            if (Demo.enabled)
                Media.demoPosition = Math.min(Media.length, Media.demoPosition + 1);
        }
    }

    Segmented {
        id: tabs
        x: Tokens.panelPaddingX
        y: 22
        width: parent.width - Tokens.panelPaddingX * 2
        current: root.tab
        options: [
            {
                key: "playing",
                label: "Playing",
                icon: Icons.GLYPHS.music
            },
            {
                key: "sound",
                label: "Sound",
                icon: Icons.GLYPHS.equalizer
            },
            {
                key: "devices",
                label: "Devices",
                icon: Icons.GLYPHS.headphones
            }
        ]
        onPicked: key => root.tab = key
    }

    Item {
        id: page
        x: Tokens.panelPaddingX
        anchors.top: tabs.bottom
        anchors.topMargin: 20
        width: parent.width - Tokens.panelPaddingX * 2
        height: parent.height - y - 24

        Item {
            anchors.fill: parent
            visible: root.tab === "playing"

            Column {
                anchors.centerIn: parent
                visible: !Media.available
                spacing: 8

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Icons.GLYPHS.music
                    size: 44
                    color: Theme.textDim
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nothing is playing"
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.bodySize
                    font.weight: Font.DemiBold
                }
            }

            Column {
                width: parent.width
                visible: Media.available
                spacing: 18

                Item {
                    width: parent.width
                    height: Tokens.mediaArt

                    Rectangle {
                        id: artBox
                        width: Tokens.mediaArt
                        height: Tokens.mediaArt
                        radius: Tokens.radiusCard
                        antialiasing: true
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Theme.accentDeep
                            }
                            GradientStop {
                                position: 1
                                color: Theme.surface
                            }
                        }

                        Glyph {
                            anchors.centerIn: parent
                            visible: art.status !== Image.Ready
                            text: Icons.GLYPHS.music
                            size: 42
                            color: Theme.onAccent
                            opacity: 0.7
                        }
                    }

                    Image {
                        id: art
                        anchors.fill: artBox
                        visible: false
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        mipmap: true
                        sourceSize.height: Tokens.mediaArt * 2
                        source: Media.art
                    }

                    ShaderEffectSource {
                        id: artTexture
                        anchors.fill: artBox
                        visible: false
                        sourceItem: art
                        hideSource: true
                        mipmap: true
                    }

                    Shape {
                        anchors.fill: artBox
                        visible: art.status === Image.Ready
                        layer.enabled: true
                        layer.samples: 8

                        ShapePath {
                            strokeWidth: -1
                            fillItem: artTexture

                            PathRectangle {
                                width: artBox.width
                                height: artBox.height
                                radius: Tokens.radiusCard
                            }
                        }
                    }

                    Column {
                        anchors.left: artBox.right
                        anchors.leftMargin: 18
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            textFormat: Text.PlainText
                            width: parent.width
                            text: Media.title === "" ? "Unknown title" : Media.title
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Tokens.fontDisplay
                            font.pixelSize: Tokens.titleSize + 2
                            font.weight: Tokens.titleWeight
                        }

                        Text {
                            textFormat: Text.PlainText
                            width: parent.width
                            visible: Media.artist !== ""
                            text: Media.artist
                            elide: Text.ElideRight
                            color: Theme.textSoft
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.bodySize
                        }

                        Text {
                            textFormat: Text.PlainText
                            width: parent.width
                            visible: Media.album !== ""
                            text: Media.album
                            elide: Text.ElideRight
                            color: Theme.textDim
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.smallSize
                        }

                        Text {
                            textFormat: Text.PlainText
                            topPadding: 6
                            text: Media.identity
                            color: Theme.accent
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.tinySize
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 34
                    visible: Media.length > 0

                    Rectangle {
                        id: track
                        y: 4
                        width: parent.width
                        height: 6
                        radius: Tokens.r(3)
                        color: Qt.alpha(Theme.text, 0.14)

                        Rectangle {
                            width: parent.width * Math.min(1, Media.position / Math.max(1, Media.length))
                            height: parent.height
                            radius: Tokens.r(3)
                            color: Theme.accent
                        }

                        Rectangle {
                            x: parent.width * Math.min(1, Media.position / Math.max(1, Media.length)) - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: seek.containsMouse || seek.pressed ? 16 : 0
                            height: width
                            radius: width / 2
                            color: Theme.accentHi

                            Behavior on width {
                                NumberAnimation {
                                    duration: Tokens.stateDuration
                                }
                            }
                        }

                        MouseArea {
                            id: seek
                            anchors.fill: parent
                            anchors.margins: -10
                            enabled: Media.canSeek
                            hoverEnabled: true
                            cursorShape: Media.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onReleased: mouse => Media.seekTo((mouse.x - 10) / track.width * Media.length)
                        }
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        text: root.time(Media.position)
                        color: Theme.textDim
                        font.family: Tokens.fontMono
                        font.pixelSize: Tokens.tinySize
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        text: "-" + root.time(Media.length - Media.position)
                        color: Theme.textDim
                        font.family: Tokens.fontMono
                        font.pixelSize: Tokens.tinySize
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 26

                    Repeater {
                        model: [
                            {
                                act: "shuffle",
                                glyph: Icons.GLYPHS.shuffle,
                                on: Media.shuffle,
                                show: Media.shuffleSupported
                            },
                            {
                                act: "previous",
                                glyph: Icons.GLYPHS.previous,
                                on: false,
                                show: true
                            },
                            {
                                act: "toggle",
                                glyph: Media.playing ? Icons.GLYPHS.pause : Icons.GLYPHS.play,
                                on: true,
                                show: true
                            },
                            {
                                act: "next",
                                glyph: Icons.GLYPHS.next,
                                on: false,
                                show: true
                            },
                            {
                                act: "loop",
                                glyph: Media.loopState === MprisLoopState.Track ? Icons.GLYPHS.repeatOnce : Media.loopState === MprisLoopState.Playlist ? Icons.GLYPHS.repeat : Icons.GLYPHS.repeatOff,
                                on: Media.loopState !== MprisLoopState.None,
                                show: Media.loopSupported
                            }
                        ]

                        delegate: Item {
                            required property var modelData
                            readonly property bool big: modelData.act === "toggle"
                            visible: modelData.show
                            anchors.verticalCenter: parent.verticalCenter
                            width: big ? 62 : 36
                            height: width

                            Rectangle {
                                anchors.fill: parent
                                visible: parent.big
                                radius: width / 2
                                color: Theme.accent
                                scale: controlArea.pressed ? 0.92 : 1

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Tokens.ms(120)
                                    }
                                }
                            }

                            Glyph {
                                anchors.centerIn: parent
                                text: modelData.glyph
                                size: parent.big ? 30 : 22
                                color: parent.big ? Theme.onAccent : modelData.on && modelData.act !== "previous" && modelData.act !== "next" ? Theme.accent : Theme.textSoft
                            }

                            MouseArea {
                                id: controlArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.act === "toggle")
                                        Media.toggle();
                                    else if (modelData.act === "next")
                                        Media.next();
                                    else if (modelData.act === "previous")
                                        Media.previous();
                                    else if (modelData.act === "shuffle")
                                        Media.setShuffle(!Media.shuffle);
                                    else
                                        Media.cycleLoop();
                                }
                            }
                        }
                    }
                }

                Slider {
                    width: parent.width
                    visible: Media.volumeSupported
                    value: Media.volume
                    icon: Icons.GLYPHS.volume
                    label: Media.identity + " " + Math.round(Media.volume * 100) + "%"
                    onMoved: v => Media.setVolume(v)
                }

                Flow {
                    width: parent.width
                    spacing: 8
                    visible: Media.players.length > 1

                    Repeater {
                        model: Media.players

                        delegate: Item {
                            required property var modelData
                            readonly property bool current: modelData === Media.player
                            width: playerText.implicitWidth + 26
                            height: 32

                            Glass {
                                anchors.fill: parent
                                radius: height / 2
                                inner: true
                                lit: parent.current
                                offBorder: Theme.cardLine
                            }

                            Text {
                                textFormat: Text.PlainText
                                id: playerText
                                anchors.centerIn: parent
                                text: modelData.identity
                                color: parent.current ? Theme.onAccent : Theme.text
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.smallSize
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Media.choose(modelData)
                            }
                        }
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: root.tab === "sound"

            Column {
                width: parent.width
                spacing: 16

                Item {
                    width: parent.width
                    height: 30

                    Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Equalizer"
                        color: Theme.text
                        font.family: Tokens.fontDisplay
                        font.pixelSize: Tokens.titleSize
                        font.weight: Tokens.titleWeight
                    }

                    Toggle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Equalizer.cfg.enabled
                        onToggled: v => Equalizer.set({
                                enabled: v
                            })
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 7

                    Repeater {
                        model: Object.keys(E.PRESETS).concat(["custom"])

                        delegate: Item {
                            required property string modelData
                            readonly property bool current: Equalizer.cfg.preset === modelData
                            visible: modelData !== "custom" || current
                            width: presetText.implicitWidth + 22
                            height: 30

                            Glass {
                                anchors.fill: parent
                                radius: height / 2
                                inner: true
                                lit: parent.current
                                hot: presetArea.containsMouse
                                offBorder: Theme.cardLine
                            }

                            Text {
                                textFormat: Text.PlainText
                                id: presetText
                                anchors.centerIn: parent
                                text: E.PRESET_NAMES[modelData]
                                color: parent.current ? Theme.onAccent : Theme.text
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.smallSize
                            }

                            MouseArea {
                                id: presetArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Equalizer.set({
                                    preset: modelData,
                                    enabled: true
                                })
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Tokens.eqHeight + 50
                    opacity: Equalizer.cfg.enabled ? 1 : 0.45

                    Glass {
                        anchors.fill: parent
                        radius: Tokens.radiusCard
                        inner: true
                        offBorder: Theme.cardLine
                    }

                    Rectangle {
                        x: 14
                        y: 24 + Tokens.eqHeight / 2
                        width: parent.width - 28
                        height: 1
                        color: Qt.alpha(Theme.text, 0.14)
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8

                        Repeater {
                            model: E.BANDS.length

                            delegate: Item {
                                id: bandItem
                                required property int index
                                readonly property real gain: Equalizer.cfg.bands[index]
                                readonly property real railTop: 16
                                width: (page.width - 20) / E.BANDS.length
                                height: Tokens.eqHeight + 40

                                Text {
                                    textFormat: Text.PlainText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (bandItem.gain > 0 ? "+" : "") + bandItem.gain
                                    color: bandItem.gain === 0 ? Theme.textDim : Theme.accent
                                    font.family: Tokens.fontMono
                                    font.pixelSize: 10
                                }

                                Rectangle {
                                    id: rail
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: bandItem.railTop
                                    width: 4
                                    height: Tokens.eqHeight
                                    radius: Tokens.r(2)
                                    color: Qt.alpha(Theme.text, 0.1)

                                    Rectangle {
                                        width: parent.width
                                        radius: Tokens.r(2)
                                        color: Theme.accent
                                        y: bandItem.gain >= 0 ? rail.height / 2 - rail.height / 2 * bandItem.gain / E.LIMIT : rail.height / 2
                                        height: Math.abs(bandItem.gain) / E.LIMIT * rail.height / 2
                                    }
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: bandItem.railTop + rail.height / 2 - rail.height / 2 * bandItem.gain / E.LIMIT - height / 2
                                    width: 18
                                    height: 18
                                    radius: Tokens.r(9)
                                    color: Theme.text
                                    border.width: 3
                                    border.color: Theme.accent
                                }

                                MouseArea {
                                    x: 0
                                    y: bandItem.railTop - 10
                                    width: parent.width
                                    height: rail.height + 20
                                    cursorShape: Qt.SizeVerCursor
                                    function gainAt(my: real): real {
                                        return Math.max(-E.LIMIT, Math.min(E.LIMIT, (1 - 2 * (my - 10) / rail.height) * E.LIMIT));
                                    }
                                    onPressed: mouse => Equalizer.setBand(bandItem.index, gainAt(mouse.y))
                                    onPositionChanged: mouse => {
                                        if (pressed)
                                            Equalizer.setBand(bandItem.index, gainAt(mouse.y));
                                    }
                                    onDoubleClicked: Equalizer.setBand(bandItem.index, 0)
                                }

                                Text {
                                    textFormat: Text.PlainText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    text: E.BANDS[bandItem.index] >= 1000 ? E.BANDS[bandItem.index] / 1000 + "k" : E.BANDS[bandItem.index]
                                    color: Theme.textDim
                                    font.family: Tokens.fontMono
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: spatialText.implicitHeight

                    Column {
                        id: spatialText
                        width: parent.width - 70
                        spacing: 2

                        Text {
                            textFormat: Text.PlainText
                            text: "Spatial audio"
                            color: Theme.text
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.bodySize
                            font.weight: Font.DemiBold
                        }

                        Text {
                            textFormat: Text.PlainText
                            width: parent.width
                            text: "Headphone crossfeed: a little of each side reaches the other ear, like speakers in a room."
                            wrapMode: Text.Wrap
                            color: Theme.textDim
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.smallSize
                        }
                    }

                    Toggle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Equalizer.cfg.spatial
                        onToggled: v => Equalizer.set({
                                spatial: v
                            })
                    }
                }

                Slider {
                    width: parent.width
                    visible: Equalizer.cfg.spatial
                    value: Equalizer.cfg.spatialLevel
                    icon: Icons.GLYPHS.headphones
                    label: "Width " + Math.round(Equalizer.cfg.spatialLevel * 100) + "%"
                    onMoved: v => Equalizer.set({
                            spatialLevel: Math.max(0.1, Math.round(v * 20) / 20)
                        })
                }

                Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    visible: Equalizer.error !== "" && !Equalizer.running && Equalizer.enabled
                    text: "The equalizer stopped: " + Equalizer.error
                    wrapMode: Text.Wrap
                    color: Theme.danger
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: root.tab === "devices"

            Column {
                width: parent.width
                spacing: 16

                Loader {
                    width: parent.width
                    active: Headphones.plugged
                    visible: active
                    source: "../plugins/airpods/AirPodsCard.qml"
                }

                Text {
                    textFormat: Text.PlainText
                    text: "Batteries"
                    color: Theme.text
                    font.family: Tokens.fontDisplay
                    font.pixelSize: Tokens.titleSize
                    font.weight: Tokens.titleWeight
                }

                Text {
                    textFormat: Text.PlainText
                    visible: Headphones.devices.length === 0
                    text: "No devices report a battery."
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }

                Repeater {
                    model: Headphones.devices

                    delegate: Item {
                        required property var modelData
                        width: page.width
                        height: 40

                        Glyph {
                            id: devGlyph
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.charging ? Icons.GLYPHS.bolt : Icons.batteryIcon(modelData.level)
                            size: 18
                            color: modelData.level < 20 ? Theme.danger : Theme.accent
                        }

                        Text {
                            textFormat: Text.PlainText
                            anchors.left: devGlyph.right
                            anchors.leftMargin: 12
                            anchors.right: pct.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.bodySize
                        }

                        Rectangle {
                            id: bar
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 90
                            height: 6
                            radius: Tokens.r(3)
                            color: Qt.alpha(Theme.text, 0.12)

                            Rectangle {
                                width: parent.width * modelData.level / 100
                                height: parent.height
                                radius: Tokens.r(3)
                                color: modelData.level < 20 ? Theme.danger : Theme.accent
                            }
                        }

                        Text {
                            textFormat: Text.PlainText
                            id: pct
                            anchors.right: bar.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.level + "%"
                            color: Theme.textSoft
                            font.family: Tokens.fontMono
                            font.pixelSize: Tokens.smallSize
                        }
                    }
                }
            }
        }
    }
}
