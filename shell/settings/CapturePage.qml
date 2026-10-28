import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons
import "../lib/capture.mjs" as K

Column {
    id: root

    readonly property var cfg: Settings.shown.capture
    readonly property var shotChoices: [
        {
            key: "format",
            title: "File format",
            subtitle: "PNG keeps every pixel; JPEG makes much smaller files",
            options: [["png", "PNG"], ["jpeg", "JPEG"]]
        },
        {
            key: "scale",
            title: "Scale",
            subtitle: "Automatic uses the sharpest scale of your screens",
            options: [[0, "Auto"], [0.5, "½×"], [1, "1×"], [2, "2×"]]
        },
        {
            key: "after",
            title: "After taking one",
            subtitle: "What happens once the screenshot is taken",
            options: [["notify", "Notify"], ["edit", "Open editor"], ["none", "Nothing"]]
        },
        {
            key: "delay",
            title: "Delay",
            subtitle: "Time to open a menu before the shot",
            options: K.DELAYS.map(d => [d, d === 0 ? "None" : d + " s"])
        }
    ]
    readonly property var videoChoices: [
        {
            key: "fps",
            title: "Frame rate",
            subtitle: "Auto records only when the screen changes, at most 60 per second, which keeps files small and uploadable",
            options: K.FPS.map(f => [f, f === 0 ? "Auto" : String(f)])
        },
        {
            key: "resolution",
            title: "Resolution",
            subtitle: "Scales the video down to this height",
            options: K.RESOLUTIONS.map(r => [r, r === "native" ? "Native" : r + "p"])
        },
        {
            key: "codec",
            title: "Codec",
            subtitle: root.cfg.codec === "vaapi" ? "Encodes on the GPU with VA-API (H.264); lightest on the CPU" : root.cfg.codec === "vp9" ? "VP9 saves as WebM" : "H.265 is smaller than H.264 but plays in fewer places",
            options: [["h264", "H.264"], ["h265", "H.265"], ["vp9", "VP9"], ["vaapi", "GPU"]]
        },
        {
            key: "container",
            title: "File type",
            subtitle: root.cfg.codec === "vp9" ? "VP9 always saves as WebM" : "MKV survives a crash mid-recording",
            options: [["mp4", "MP4"], ["mkv", "MKV"]]
        },
        {
            key: "videoQuality",
            title: "Quality",
            subtitle: "Higher quality means bigger files",
            options: [["high", "High"], ["balanced", "Balanced"], ["small", "Small"]]
        },
        {
            key: "countdown",
            title: "Countdown",
            subtitle: "Waits after you pick the area, with the time shown on screen",
            options: K.DELAYS.map(d => [d, d === 0 ? "None" : d + " s"])
        },
        {
            key: "limit",
            title: "Stop automatically",
            subtitle: "Ends the recording after this long",
            options: K.LIMITS.map(m => [m, m === 0 ? "Never" : m + " min"])
        }
    ]

    function example(): string {
        return K.fileName("shot", new Date(), root.cfg);
    }

    spacing: 24

    component Choice: SettingRow {
        id: choice

        required property var modelData
        required property int index

        title: modelData.title
        key: "capture." + choice.modelData.key
        subtitle: modelData.subtitle
        last: false

        Segmented {
            width: Math.min(360, 86 * choice.modelData.options.length)
            options: choice.modelData.options.map(o => ({
                        key: String(o[0]),
                        label: o[1]
                    }))
            current: String(root.cfg[choice.modelData.key])
            onPicked: key => {
                const hit = choice.modelData.options.find(o => String(o[0]) === key);
                Settings.put("capture." + choice.modelData.key, hit[0]);
            }
        }
    }

    Card {
        title: "Screenshots"
        note: "Open the capture panel with “sylvaris capture toggle”, or bind keys straight to “sylvaris capture shot area”, “… shot window”, “… shot screen”."

        Item {
            width: parent.width
            height: 110

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusCard
                inner: true
            }

            Row {
                anchors.centerIn: parent
                spacing: 12

                Repeater {
                    model: [
                        {
                            glyph: Icons.GLYPHS.region,
                            label: "Area"
                        },
                        {
                            glyph: Icons.GLYPHS.windowPick,
                            label: "Window"
                        },
                        {
                            glyph: Icons.GLYPHS.displays,
                            label: "Screen"
                        }
                    ]

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: 86
                        height: 78

                        Glass {
                            anchors.fill: parent
                            radius: Tokens.radiusRow
                            inner: true
                            lit: index === 0
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Glyph {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.glyph
                                size: 22
                                color: index === 0 ? Theme.onAccent : Theme.accent
                            }

                            Text {
                                textFormat: Text.PlainText
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label + (index === 0 && root.cfg.delay > 0 ? " · " + root.cfg.delay + " s" : "")
                                color: index === 0 ? Theme.onAccent : Theme.text
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.tinySize
                            }
                        }
                    }
                }
            }
        }

        SettingRow {
            title: "Copy to the clipboard"
            key: "capture.copy"
            subtitle: "Screenshots as images, recordings as a file you can paste into chats and uploads"

            Toggle {
                checked: root.cfg.copy
                onToggled: v => Settings.put("capture.copy", v)
            }
        }

        SettingRow {
            title: "Save to a file"
            key: "capture.save"
            subtitle: root.cfg.folder

            Toggle {
                checked: root.cfg.save
                onToggled: v => Settings.put("capture.save", v)
            }
        }

        SettingRow {
            title: "Screenshots folder"
            key: "capture.folder"
            subtitle: "Where screenshots are saved; ~ is your home"

            TextBox {
                width: 260
                text: root.cfg.folder
                placeholder: "~/Pictures/Screenshots"
                onAccepted: Settings.put("capture.folder", text.trim() === "" ? "~/Pictures/Screenshots" : text.trim())
            }
        }

        SettingRow {
            title: "JPEG quality"
            key: "capture.quality"
            advanced: true
            subtitle: "Only used for JPEG files"
            visible: root.cfg.format === "jpeg"

            Stepper {
                value: root.cfg.quality
                from: 10
                to: 100
                step: 5
                suffix: " %"
                onStepped: v => Settings.put("capture.quality", v)
            }
        }

        SettingRow {
            title: "Include the pointer"
            key: "capture.cursor"

            Toggle {
                checked: root.cfg.cursor
                onToggled: v => Settings.put("capture.cursor", v)
            }
        }

        Repeater {
            model: root.shotChoices

            delegate: Choice {}
        }

        SettingRow {
            title: "File name"
            key: "capture.pattern"
            advanced: true
            subtitle: "{kind}, {date} and {time} are filled in: " + root.example()
            last: true

            TextBox {
                width: 260
                text: root.cfg.pattern
                placeholder: "{kind} {date} {time}"
                onAccepted: Settings.put("capture.pattern", text.trim() === "" ? "{kind} {date} {time}" : text)
            }
        }
    }

    Card {
        title: "Editing"
        note: "“sylvaris capture edit” opens the last screenshot, or any image you name, in the editor: pen, highlighter, line, arrow, rectangle, ellipse, text, pixelate and crop, with undo. Keys: P H L A R E T X C pick a tool, 1–3 the width, Ctrl+Z undo, Ctrl+Shift+Z redo, Ctrl+C copy, Ctrl+S saves a copy next to the original, Esc closes."

        RowButton {
            icon: Icons.GLYPHS.imageEdit
            label: "Edit the last screenshot"
            onClicked: Ipc.run(["capture", "edit"])
        }
    }

    Card {
        title: "Screen recording"
        note: "Start with “sylvaris capture record area” or “… record screen” and stop with “sylvaris capture stop” or the red button that shows while recording. Videos go to " + root.cfg.videos + "."

        SettingRow {
            title: "Videos folder"
            key: "capture.videos"
            subtitle: "Where recordings are saved; ~ is your home"

            TextBox {
                width: 260
                text: root.cfg.videos
                placeholder: "~/Videos/Recordings"
                onAccepted: Settings.put("capture.videos", text.trim() === "" ? "~/Videos/Recordings" : text.trim())
            }
        }

        Repeater {
            model: root.videoChoices

            delegate: Choice {}
        }

        SettingRow {
            title: "Steady frame rate"
            key: "capture.constant"
            advanced: true
            subtitle: "Records every frame even when nothing moves; smoother in editors, bigger files"

            Toggle {
                checked: root.cfg.constant
                onToggled: v => Settings.put("capture.constant", v)
            }
        }

        SettingRow {
            title: "Record sound"
            key: "capture.audio"
            subtitle: "Needs PipeWire or PulseAudio"

            Toggle {
                checked: root.cfg.audio
                onToggled: v => Settings.put("capture.audio", v)
            }
        }

        SettingRow {
            title: "Sound from"
            key: "capture.audioSource"
            advanced: true
            last: true
            visible: root.cfg.audio

            Segmented {
                width: 260
                options: [
                    {
                        key: "output",
                        label: "Speakers"
                    },
                    {
                        key: "mic",
                        label: "Microphone"
                    }
                ]
                current: root.cfg.audioSource
                onPicked: key => Settings.put("capture.audioSource", key)
            }
        }
    }
}
