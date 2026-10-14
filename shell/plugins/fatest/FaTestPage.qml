import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.components
import qs.settings
import "../../lib/fatest.mjs" as F
import "../../lib/icons.mjs" as Icons

Column {
    id: page

    required property var host
    property string message: ""
    property bool available: false
    property var last: null
    readonly property string home: Quickshell.env("HOME")

    spacing: 24

    function save(): void {
        if (!page.available || saver.running)
            return;
        const args = F.configArgs(countryBox.text, serverBox.text);
        if (args === null) {
            page.message = "Use a two-letter country code like PL and a numeric server ID, or leave them empty";
            return;
        }
        saver.command = ["fatest"].concat(args);
        saver.running = true;
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v fatest"]
        onExited: code => page.available = code === 0
    }

    Process {
        id: saver
        onExited: code => page.message = code === 0 ? "Saved for FaTest and the fatest command" : "fatest config failed with exit code " + code
    }

    FileView {
        path: page.home + "/.fatest_config.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const c = F.parseConfig(text());
            countryBox.text = c.country;
            serverBox.text = c.server;
        }
    }

    FileView {
        path: page.home + "/.fatest_history.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const h = F.parseHistory(text());
            page.last = h.length > 0 ? h[0] : null;
        }
    }

    Card {
        title: "FaTest"
        note: page.available ? "Internet speed tests run by FaTest. Results land in the same history as the fatest command." : "FaTest is not installed. Install it from github.com/fatumorg/FaTest and it is picked up here."

        SettingRow {
            title: "Last result"
            subtitle: page.last === null ? "No runs yet" : page.last.timestamp.replace("T", " ").slice(0, 16) + " · " + String(page.last.server || "")

            Text {
                textFormat: Text.PlainText
                visible: page.last !== null
                text: page.last === null ? "" : "↓ " + F.speed(page.last.download) + "   ↑ " + F.speed(page.last.upload) + "   " + Math.round(page.last.ping) + " ms"
                color: Theme.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
                font.weight: Font.DemiBold
            }
        }

        SettingRow {
            last: true
            title: "Speed Test"
            subtitle: "“sylvaris fatest run” starts one from anywhere"

            Chip {
                enabled: page.available
                opacity: enabled ? 1 : 0.4
                text: "Open FaTest"
                glyph: Icons.GLYPHS.speed
                onClicked: page.host.hand("fatest", "")
            }
        }
    }

    Card {
        title: "Server"
        note: "Shared with the fatest command. Empty fields let FaTest pick the fastest of the five nearest servers."

        SettingRow {
            title: "Country"
            subtitle: "Two-letter code, e.g. PL"

            TextBox {
                id: countryBox
                width: 120
                placeholder: "auto"
                onAccepted: page.save()
            }
        }

        SettingRow {
            last: true
            title: "Server ID"
            subtitle: page.message !== "" ? page.message : "From “fatest servers”"

            Row {
                spacing: 8

                TextBox {
                    id: serverBox
                    width: 140
                    placeholder: "auto"
                    onAccepted: page.save()
                }

                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: page.available && !saver.running
                    opacity: enabled ? 1 : 0.4
                    text: saver.running ? "Saving…" : "Save"
                    glyph: Icons.GLYPHS.checkCircle
                    onClicked: page.save()
                }
            }
        }
    }
}
