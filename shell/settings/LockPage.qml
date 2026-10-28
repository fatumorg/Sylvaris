import QtQuick
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons
import "../lib/lock.mjs" as L

Column {
    id: root

    readonly property var cfg: Settings.shown.lock

    signal lockRequested

    spacing: 24

    Card {
        title: "Lock screen"
        note: "Lock with “sylvaris lock”, the Lock action in SylPower or a key you bind to it. Your password is checked by PAM, the same way the login screen does."

        Item {
            width: parent.width
            height: 190
            clip: true

            Glass {
                anchors.fill: parent
                radius: Tokens.radiusCard
                inner: true
            }

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(new Date(), root.cfg.seconds ? "HH:mm:ss" : "HH:mm")
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: 44
                    font.weight: Font.Light
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(new Date(), "dddd, d MMMM")
                    color: Theme.textSoft
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 44
                    height: 44
                    radius: Tokens.r(22)
                    color: "transparent"
                    border.width: 2
                    border.color: Qt.alpha(Theme.accentHi, 0.7)

                    Glyph {
                        anchors.centerIn: parent
                        text: Icons.GLYPHS.lock
                        size: 18
                        color: Theme.accent
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 180
                    height: 28
                    radius: Tokens.r(14)
                    color: Theme.tintMid
                    border.width: 1
                    border.color: Theme.cardLine

                    Text {
                        textFormat: Text.PlainText
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "••••••"
                        color: Theme.textDim
                        font.pixelSize: Tokens.smallSize
                    }
                }
            }
        }

        SettingRow {
            title: "PAM service"
            key: "lock.pam"
            advanced: true
            subtitle: root.cfg.pam === "" ? "Automatic: the first of sylvaris, hyprlock, swaylock or login that is installed" : "Uses /etc/pam.d/" + root.cfg.pam

            Segmented {
                width: 300
                options: [
                    {
                        key: "",
                        label: "Automatic"
                    },
                    {
                        key: "sylvaris",
                        label: "sylvaris"
                    },
                    {
                        key: "login",
                        label: "login"
                    }
                ]
                current: root.cfg.pam
                onPicked: key => Settings.put("lock.pam", key)
            }
        }

        SettingRow {
            title: "Clock face"
            key: "lock.face"
            subtitle: "The same faces as the clock widget"
        }

        Flow {
            width: parent.width
            spacing: 6
            bottomPadding: 8

            Repeater {
                model: L.LOCK_FACES

                delegate: Chip {
                    required property string modelData
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    lit: root.cfg.face === modelData
                    onClicked: Settings.put("lock.face", modelData)
                }
            }
        }

        SettingRow {
            title: "Show seconds"
            key: "lock.seconds"
            subtitle: "On the lock screen clock"

            Toggle {
                checked: root.cfg.seconds
                onToggled: v => Settings.put("lock.seconds", v)
            }
        }

        SettingRow {
            title: "Lock when the system asks"
            key: "lock.logind"
            advanced: true
            subtitle: "Also lock on “loginctl lock-session”, for example from an idle daemon. Turn off any other locker first."

            Toggle {
                checked: root.cfg.logind
                onToggled: v => Settings.put("lock.logind", v)
            }
        }

        SettingRow {
            title: "Lock now"
            key: "lock.now"
            subtitle: "Try it out"
            last: true

            RowButton {
                icon: Icons.GLYPHS.lock
                label: "Lock"
                onClicked: root.lockRequested()
            }
        }
    }
}
