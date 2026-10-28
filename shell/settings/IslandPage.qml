import QtQuick
import qs
import qs.services
import qs.components
import qs.island
import "../lib/island.mjs" as I
import "../lib/icons.mjs" as Icons

Column {
    id: root

    readonly property var cfg: Settings.shown.island
    readonly property bool on: Settings.shown.parts.island
    readonly property var sample: I.activities({
        flash: null,
        recording: {
            on: true,
            started: true,
            elapsed: 83000
        },
        alarm: null,
        focus: {
            title: "Draft the release notes",
            left: 1417000
        },
        next: null,
        media: {
            title: Media.title || "Night Drive",
            artist: Media.artist || "Hollow Coast",
            art: Media.art,
            playing: true
        }
    }, root.cfg)

    spacing: 24

    function flip(id: string): void {
        const next = root.cfg.shortcuts.slice();
        const i = next.indexOf(id);
        if (i >= 0)
            next.splice(i, 1);
        else if (next.length < I.MAX_SHORTCUTS)
            next.push(id);
        Settings.put("island.shortcuts", next);
    }

    Card {
        title: "Island"
        note: "A pill on the focused screen that shows what is going on: music from any MPRIS player, screen recordings, Diver focus timers and alarms, volume changes, new Bluetooth devices and, if you like, notifications. Hover to expand it: every activity gets its own row and controls, so you can stop a recording and skip a song side by side. Click a row to open its panel, scroll on the island to change the volume, and hover the preview below to try it. Scripts can post to it with “sylvaris island show <text>”."

        Item {
            width: parent.width
            height: 270

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusCard
                inner: true
            }

            IslandBody {
                id: preview
                anchors.horizontalCenter: parent.horizontalCenter
                y: I.placeOf(root.cfg.position).top ? 16 : parent.height - height - 16
                items: root.sample
                shortcuts: I.shortcutsFor(root.cfg.shortcuts, Object.keys(I.SHORTCUTS).map(k => I.SHORTCUTS[k].needs)).map(s => Object.assign({}, s, {
                        lit: s.id === "dnd"
                    }))
                expanded: previewHover.hovered
                atTop: I.placeOf(root.cfg.position).top
                idle: root.cfg.idle
                time: Qt.formatTime(new Date(), "HH:mm")
                progress: 0.42
                position: 89
                length: 212
                opacity: root.on ? 1 : 0.5

                HoverHandler {
                    id: previewHover
                }
            }
        }

        SettingRow {
            title: "Show the island"
            key: "parts.island"
            subtitle: "Off by default. The same switch: sylvaris set parts.island true"

            Toggle {
                checked: root.on
                onToggled: v => Settings.put("parts.island", v)
            }
        }

        SettingRow {
            title: "Show on"
            key: "island.screens"
            subtitle: "Every screen gets its own island that expands on its own"

            Segmented {
                width: 300
                options: [
                    {
                        key: "focused",
                        label: "Focused screen"
                    },
                    {
                        key: "all",
                        label: "Every screen"
                    }
                ]
                current: root.cfg.screens
                onPicked: key => Settings.put("island.screens", key)
            }
        }

        SettingRow {
            title: "Edge"
            key: "island.position"
            subtitle: "Top or bottom of the focused screen"

            Segmented {
                width: 240
                options: [
                    {
                        key: "top",
                        label: "Top"
                    },
                    {
                        key: "bottom",
                        label: "Bottom"
                    }
                ]
                current: I.placeOf(root.cfg.position).top ? "top" : "bottom"
                onPicked: key => Settings.put("island.position", key + "-" + I.placeOf(root.cfg.position).side)
            }
        }

        SettingRow {
            title: "Side"
            key: "island.position"

            Segmented {
                width: 300
                options: [
                    {
                        key: "left",
                        label: "Left"
                    },
                    {
                        key: "center",
                        label: "Center"
                    },
                    {
                        key: "right",
                        label: "Right"
                    }
                ]
                current: I.placeOf(root.cfg.position).side
                onPicked: key => Settings.put("island.position", (I.placeOf(root.cfg.position).top ? "top-" : "bottom-") + key)
            }
        }

        SettingRow {
            title: "Visibility"
            key: "island.reveal"
            subtitle: "Reveal on hover tucks it into the edge like the deck; calls and alerts still slide out"

            Segmented {
                width: 300
                options: [
                    {
                        key: "always",
                        label: "Always visible"
                    },
                    {
                        key: "hover",
                        label: "Reveal on hover"
                    }
                ]
                current: root.cfg.reveal
                onPicked: key => Settings.put("island.reveal", key)
            }
        }

        SettingRow {
            title: "When nothing is going on"
            key: "island.idle"
            subtitle: "A pill keeps your shortcuts one hover away"

            Segmented {
                width: 300
                options: [
                    {
                        key: "hide",
                        label: "Hide"
                    },
                    {
                        key: "pill",
                        label: "Pill"
                    },
                    {
                        key: "clock",
                        label: "Clock"
                    }
                ]
                current: root.cfg.idle
                onPicked: key => Settings.put("island.idle", key)
            }
        }

        SettingRow {
            title: "Expand on hover"
            key: "island.hover"
            subtitle: "Otherwise click the island to expand it"

            Toggle {
                checked: root.cfg.hover
                enabled: root.on
                onToggled: v => Settings.put("island.hover", v)
            }
        }

        SettingRow {
            title: "Seconds for short alerts"
            key: "island.seconds"
            advanced: true
            subtitle: "How long volume, device and notification alerts stay"
            last: true

            Stepper {
                value: root.cfg.seconds
                from: 1
                to: 10
                suffix: " s"
                onStepped: v => Settings.put("island.seconds", v)
            }
        }
    }

    Card {
        title: "Shortcuts"
        note: "Buttons along the bottom of the expanded island, up to " + I.MAX_SHORTCUTS + ". Panels close the island, switches stay. Scripts: sylvaris island run <name>"

        SettingRow {
            title: "Buttons"
            key: "island.shortcuts"
            subtitle: "Click to add or remove, in the order you pick them"
            last: true

            Flow {
                width: 420
                spacing: 8

                Repeater {
                    model: Object.keys(I.SHORTCUTS)

                    delegate: Chip {
                        required property string modelData
                        text: I.SHORTCUTS[modelData].label
                        glyph: Icons.GLYPHS[I.SHORTCUTS[modelData].glyph]
                        lit: root.cfg.shortcuts.indexOf(modelData) >= 0
                        onClicked: root.flip(modelData)
                    }
                }
            }
        }
    }

    Card {
        title: "Hidden sites"
        note: "Media playing from these sites stays out of the island, so a YouTube video does not take it over. The bar and SylMedia still show it. Separate sites with commas, press Enter to save."

        SettingRow {
            title: "Sites"
            key: "island.hideSites"
            advanced: true
            subtitle: "music.youtube.com is not youtube.com, so YouTube Music still shows"
            last: true

            TextBox {
                id: sitesBox
                width: 320
                text: root.cfg.hideSites.join(", ")
                placeholder: "youtube.com, twitch.tv"
                onAccepted: Settings.put("island.hideSites", sitesBox.text.split(",").map(s => s.trim()).filter(s => s !== ""))
            }
        }
    }

    Card {
        title: "What it shows"
        note: "Recordings replace the separate recording pill. Messages, calls and notifications taken by the island skip the usual toasts; other critical ones still pop up. Apps are recognised from their notifications, including web apps in a browser. FaceTime has no Linux app, so only facetime.apple.com calls in a browser can show up."

        Repeater {
            model: [
                {
                    key: "media",
                    title: "Music and video",
                    subtitle: "Any player that speaks MPRIS: Cider, Spotify, browsers, mpv, VLC"
                },
                {
                    key: "keepPaused",
                    title: "Keep paused music",
                    subtitle: "A paused song stays in the island with a play button until its player closes"
                },
                {
                    key: "recording",
                    title: "Screen recording",
                    subtitle: "Elapsed time and a stop button"
                },
                {
                    key: "diver",
                    title: "Diver",
                    subtitle: "Alarms, focus timers and tasks starting within 15 minutes"
                },
                {
                    key: "volume",
                    title: "Volume changes",
                    subtitle: "From keys, apps or any mixer"
                },
                {
                    key: "devices",
                    title: "Bluetooth devices",
                    subtitle: "When one connects, with its battery"
                },
                {
                    key: "messages",
                    title: "Messages",
                    subtitle: "Discord and Vesktop, Signal, Telegram, WhatsApp, Messenger, Ferdium, Slack, Element, Teams and more, with reply where the app allows it"
                },
                {
                    key: "calls",
                    title: "Calls",
                    subtitle: "Stay on top with answer and decline until the app ends them"
                },
                {
                    key: "pinCalls",
                    title: "Keep calls in view",
                    subtitle: "During an incoming or ongoing call the island stays out, even in hover mode and over full-screen apps and games"
                },
                {
                    key: "privacy",
                    title: "Microphone and camera",
                    subtitle: "Which apps are using them, and privacy mode (sylvaris privacy) while it is on"
                },
                {
                    key: "status",
                    title: "Switch changes",
                    subtitle: "Do not disturb, night light, performance mode, Wi-Fi, Bluetooth and the network going up or down"
                },
                {
                    key: "notifications",
                    title: "Notifications",
                    subtitle: "Instead of toasts"
                }
            ]

            delegate: SettingRow {
                required property var modelData
                required property int index
                title: modelData.title
                key: "island." + modelData.key
                subtitle: modelData.subtitle
                last: index === 8

                Toggle {
                    checked: root.cfg[modelData.key]
                    onToggled: v => Settings.put("island." + modelData.key, v)
                }
            }
        }
    }
}
