import QtQuick
import qs
import qs.services
import qs.components

Column {
    required property var host

    spacing: 24

    Card {
        title: "Motion"
        note: "Every panel opens, moves and closes with the same motion. Speed stretches or shortens all of it at once."

        MotionPreview {}

        SettingRow {
            title: "Animation speed"
            subtitle: Settings.shown.motion.scale === 1 ? "Default" : Settings.shown.motion.scale < 1 ? "Faster" : "Slower"

            Slider {
                width: 300
                value: (Settings.shown.motion.scale - 0.25) / 1.75
                label: "×" + (1 / Settings.shown.motion.scale).toFixed(2)
                onMoved: v => Settings.put("motion.scale", Math.round((0.25 + v * 1.75) * 20) / 20)
            }
        }

        SettingRow {
            title: "Style"
            subtitle: "How every panel moves: calm and slow, smooth, quick and tight, or springy with a little overshoot"

            Segmented {
                width: 340
                options: [
                    {
                        key: "calm",
                        label: "Calm"
                    },
                    {
                        key: "smooth",
                        label: "Smooth"
                    },
                    {
                        key: "snappy",
                        label: "Snappy"
                    },
                    {
                        key: "playful",
                        label: "Playful"
                    }
                ]
                current: Settings.shown.motion.preset
                onPicked: key => Settings.put("motion.preset", key)
            }
        }

        SettingRow {
            title: "Background reveal"
            subtitle: "How the blurred background of SylSettings, SylPad and SylPower spreads when they open and close"

            Segmented {
                width: 300
                options: [
                    {
                        key: "edges",
                        label: "Edges in"
                    },
                    {
                        key: "center",
                        label: "Center out"
                    },
                    {
                        key: "fade",
                        label: "Fade"
                    }
                ]
                current: Settings.shown.motion.reveal
                onPicked: key => Settings.put("motion.reveal", key)
            }
        }

        SettingRow {
            title: "Reduce motion"
            subtitle: "Panels appear and disappear without moving"
            last: true

            Toggle {
                checked: Settings.shown.motion.reduced
                onToggled: v => Settings.put("motion.reduced", v)
            }
        }
    }

    Card {
        title: "Performance"
        note: "Also a tile in SylCenter. Nothing to install: Sylvaris trims itself and, when on, the compositor too on Hyprland and sway."

        SettingRow {
            title: "Performance mode"
            subtitle: "Auto drops blur, sheen and ambient movement while a full-screen window has focus, such as a game. On does it always and also turns off compositor animations, blur, shadows and gaps"
            last: true

            Segmented {
                width: 240
                options: [
                    {
                        key: "off",
                        label: "Off"
                    },
                    {
                        key: "auto",
                        label: "Auto"
                    },
                    {
                        key: "on",
                        label: "On"
                    }
                ]
                current: Settings.shown.performance
                onPicked: key => Settings.put("performance", key)
            }
        }
    }
}
