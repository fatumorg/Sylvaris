import QtQuick
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
            key: "motion.scale"
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
            key: "motion.preset"
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
            title: "Opening"
            key: "motion.open"
            subtitle: "How panels appear: grow from their corner, morph out of the button you clicked, drop in, unfold, come into focus or swing down"

            Segmented {
                width: 460
                options: [
                    {
                        key: "grow",
                        label: "Grow"
                    },
                    {
                        key: "morph",
                        label: "Morph"
                    },
                    {
                        key: "drop",
                        label: "Drop"
                    },
                    {
                        key: "unfold",
                        label: "Unfold"
                    },
                    {
                        key: "blur",
                        label: "Focus"
                    },
                    {
                        key: "swing",
                        label: "Swing"
                    }
                ]
                current: Settings.shown.motion.open
                onPicked: key => Settings.put("motion.open", key)
            }
        }

        SettingRow {
            title: "Stagger"
            key: "motion.stagger"
            advanced: true
            subtitle: "How far apart the pieces of a panel arrive, from all at once to one after another"

            Slider {
                width: 300
                value: Settings.shown.motion.stagger / 0.9
                label: Settings.shown.motion.stagger === 0 ? "Together" : Math.round(Settings.shown.motion.stagger / 0.9 * 100) + "%"
                onMoved: v => Settings.put("motion.stagger", Math.round(v * 0.9 * 20) / 20)
            }
        }

        SettingRow {
            title: "Springiness"
            key: "motion.springiness"
            advanced: true
            subtitle: Settings.shown.motion.springiness < 0 ? "Follows the style above; drag to set your own bounce" : "How much buttons and badges overshoot before they settle"

            Slider {
                width: 300
                value: Settings.shown.motion.springiness < 0 ? 0.67 : Settings.shown.motion.springiness
                label: Settings.shown.motion.springiness < 0 ? "Style" : Math.round(Settings.shown.motion.springiness * 100) + "%"
                onMoved: v => Settings.put("motion.springiness", Math.round(v * 20) / 20)
            }
        }

        SettingRow {
            title: "Background reveal"
            key: "motion.reveal"
            advanced: true
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
            key: "motion.reduced"
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
            key: "performance"
            subtitle: "Auto pauses ambient movement while a full-screen window has focus, such as a game, and keeps the look. On also drops blur and sheen, shortens animations and turns off compositor animations, blur, shadows and gaps"
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
