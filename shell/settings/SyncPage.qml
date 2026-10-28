import QtQuick
import qs
import qs.services
import qs.components
import "../lib/sync.mjs" as S

Column {
    id: root

    readonly property var cfg: Settings.shown.sync
    readonly property var pal: S.palette(Theme.theme.colors)

    function statusFor(id: string): string {
        return root.cfg.enabled && root.cfg.targets[id] ? S.summary(Sync.results, id) : "";
    }

    spacing: 24

    Card {
        title: "SylSync"
        note: "Writes your theme's colours into other apps' own theme files, and again whenever you switch themes. Nothing outside those files is touched."

        Item {
            width: parent.width
            height: 76

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusCard
                inner: true
            }

            Column {
                anchors.centerIn: parent
                spacing: 8

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    Repeater {
                        model: [root.pal.bg, root.pal.bg2, root.pal.deep, root.pal.accent, root.pal.hi, root.pal.dim, root.pal.soft, root.pal.fg]

                        delegate: Rectangle {
                            required property string modelData
                            width: 26
                            height: 26
                            radius: Tokens.r(8)
                            color: modelData
                            border.width: 1
                            border.color: Theme.line
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 3

                    Repeater {
                        model: S.ansi(root.pal)

                        delegate: Rectangle {
                            required property string modelData
                            width: 14
                            height: 14
                            radius: Tokens.r(4)
                            color: modelData
                        }
                    }
                }
            }
        }

        SettingRow {
            title: "Match apps to the theme"
            subtitle: root.cfg.enabled ? (Sync.last > 0 ? "Last synced " + Qt.formatTime(new Date(Sync.last), "HH:mm") : "Syncing…") : "Off"
            last: true

            Toggle {
                checked: root.cfg.enabled
                onToggled: v => Settings.put("sync.enabled", v)
            }
        }
    }

    Card {
        title: "Apps"
        opacity: root.cfg.enabled ? 1 : 0.5

        Repeater {
            model: S.TARGETS

            delegate: SettingRow {
                required property var modelData
                required property int index
                readonly property string status: root.statusFor(modelData.id)
                title: modelData.label
                subtitle: modelData.about + (status === "" ? "" : " · " + status.toLowerCase())
                last: index === S.TARGETS.length - 1

                Toggle {
                    checked: root.cfg.targets[modelData.id]
                    onToggled: v => Settings.put("sync.targets." + modelData.id, v)
                }
            }
        }
    }
}
