import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import "../lib/icons.mjs" as Icons
import "../lib/settings.mjs" as S
import "../lib/center.mjs" as C
import "../lib/rgb.mjs" as R

Item {
    id: root

    signal openView(string name)
    signal dismiss

    property var peers: ({})

    property date now: new Date()
    readonly property var toggles: Toggles.items
    readonly property var cfg: Settings.values.center
    readonly property var tiles: root.buildTiles().filter(t => root.cfg.hidden.indexOf(t.key) < 0)

    implicitWidth: Tokens.centerCompactWidth
    implicitHeight: column.implicitHeight + Tokens.panelPaddingY * 2

    function toggleTile(t: var): var {
        return {
            key: "toggle:" + t.id,
            icon: t.icon,
            title: t.label,
            subtitle: t.on ? "On" : "Off",
            active: t.on,
            detail: ""
        };
    }

    function buildTiles(): var {
        const out = [];
        if (NetworkService.available)
            out.push({
                key: "wifi",
                icon: NetworkService.enabled ? Icons.GLYPHS.wifi : Icons.GLYPHS.wifiOff,
                title: "Wi-Fi",
                subtitle: NetworkService.summary,
                active: NetworkService.enabled && NetworkService.hasWifi,
                detail: "orbit-wifi"
            });
        if (BluetoothService.available)
            out.push({
                key: "bluetooth",
                icon: BluetoothService.enabled ? Icons.GLYPHS.bluetooth : Icons.GLYPHS.bluetoothOff,
                title: "Bluetooth",
                subtitle: BluetoothService.summary,
                active: BluetoothService.enabled,
                detail: "orbit-bluetooth"
            });
        if (NightLight.available)
            out.push({
                key: "night",
                icon: Icons.GLYPHS.nightLight,
                title: "Night light",
                subtitle: NightLight.enabled ? NightLight.temperature + "K" : "Off",
                active: NightLight.enabled,
                detail: ""
            });
        if (Dnd.available)
            out.push({
                key: "dnd",
                icon: Icons.GLYPHS.dnd,
                title: "DND",
                subtitle: Dnd.enabled ? "On" : "Off",
                active: Dnd.enabled,
                detail: ""
            });
        if (root.toggles.length > 0)
            out.push(root.toggleTile(root.toggles[0]));
        if (Hotspot.available)
            out.push({
                key: "hotspot",
                icon: Icons.GLYPHS.hotspot,
                title: "Hotspot",
                subtitle: Hotspot.active ? Settings.values.hotspot.ssid : "Off",
                active: Hotspot.active,
                detail: "hotspot"
            });
        for (let i = 1; i < root.toggles.length; i++)
            out.push(root.toggleTile(root.toggles[i]));
        for (const e of C.offeredExtras(Settings.values.plugins)) {
            const t = root.cfg.extra.indexOf(e.key) >= 0 ? root.extraTile(e) : null;
            if (t !== null)
                out.push(t);
        }
        return out;
    }

    function extraTile(e: var): var {
        const p = root.peers[e.key === "screenshot" || e.key === "record" ? "capture" : e.key];
        const tile = {
            key: e.key,
            icon: Icons.GLYPHS[e.glyph],
            title: e.label,
            subtitle: "",
            active: false,
            detail: "extra"
        };
        if (e.key === "airpods") {
            if (!Headphones.plugged)
                return null;
            tile.subtitle = C.airpodsLine(Headphones.connected, Headphones.battery);
            tile.active = Headphones.connected && Headphones.noise !== "" && Headphones.noise !== "off";
            return tile;
        }
        if (e.key === "awake") {
            tile.subtitle = Awake.on ? "Screen stays on" : "Off";
            tile.active = Awake.on;
            return tile;
        }
        if (p === undefined || p === null)
            return null;
        if (e.key === "fatest") {
            tile.subtitle = C.speedLine(p.st.phase, p.st.live, p.history.length > 0 ? p.history[0] : null);
            tile.active = p.running;
        } else if (e.key === "rgb") {
            tile.subtitle = R.summary(p.cfg, p.devices.length, p.error);
            tile.active = p.cfg.on && p.error === "";
        } else if (e.key === "record") {
            tile.subtitle = p.recording ? "Recording" : "Select an area";
            tile.active = p.recording;
        } else {
            tile.subtitle = e.key === "screenshot" ? "Select an area" : e.key === "clip" ? "History" : "Lock the screen";
        }
        return tile;
    }

    function extraIcon(key: string): void {
        const cap = root.peers.capture;
        if (key === "fatest") {
            const p = root.peers.fatest;
            if (p.running)
                p.stop();
            else
                p.run();
        } else if (key === "airpods") {
            if (Headphones.connected)
                Headphones.setNoise(Headphones.noise === "anc" ? "transparency" : "anc");
            else
                root.extraOpen(key);
        } else if (key === "rgb") {
            root.peers.rgb.setOn(!root.peers.rgb.cfg.on);
        } else if (key === "awake") {
            Awake.set(!Awake.on);
        } else if (key === "record" && cap.recording) {
            cap.stop();
        } else {
            root.extraOpen(key);
        }
    }

    function extraOpen(key: string): void {
        if (key === "awake") {
            Awake.set(!Awake.on);
            return;
        }
        const cap = root.peers.capture;
        root.dismiss();
        if (key === "fatest")
            root.peers.fatest.open();
        else if (key === "rgb")
            root.peers.rgb.open();
        else if (key === "airpods" && root.peers.media) {
            root.peers.media.openTab("devices");
            root.peers.media.open();
        } else if (key === "screenshot")
            cap.shoot("region");
        else if (key === "record")
            cap.recording ? cap.stop() : cap.record("region");
        else if (key === "clip")
            root.peers.clip.open();
        else if (key === "lock")
            root.peers.lock.lock();
    }

    function iconAction(key: string): void {
        if (key === "wifi")
            NetworkService.setEnabled(!NetworkService.enabled);
        else if (key === "bluetooth")
            BluetoothService.setEnabled(!BluetoothService.enabled);
        else if (key === "night")
            NightLight.setEnabled(!NightLight.enabled);
        else if (key === "dnd")
            Dnd.setEnabled(!Dnd.enabled);
        else if (key === "hotspot") {
            if (Hotspot.active)
                Hotspot.stop();
            else if (Hotspot.profileExists)
                Hotspot.start(Settings.values.hotspot.ssid, "", Settings.values.hotspot.band);
            else
                root.openView("hotspot");
        } else if (C.EXTRAS.some(e => e.key === key)) {
            root.extraIcon(key);
        } else if (key.indexOf("toggle:") === 0) {
            const id = key.slice(7);
            for (const t of root.toggles) {
                if (t.id === id)
                    Toggles.set(id, !t.on);
            }
        }
    }

    function bodyAction(tile: var): void {
        if (tile.detail === "extra")
            root.extraOpen(tile.key);
        else if (tile.detail !== "")
            root.openView(tile.detail);
        else
            root.iconAction(tile.key);
    }

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Column {
        id: column
        x: Tokens.panelPaddingX
        y: Tokens.panelPaddingY
        width: parent.width - Tokens.panelPaddingX * 2
        spacing: Tokens.gap

        Item {
            width: parent.width
            height: clockColumn.implicitHeight

            Column {
                id: clockColumn

                Text {
                    textFormat: Text.PlainText
                    text: Qt.formatTime(root.now, "HH:mm")
                    color: Theme.text
                    font.family: Tokens.fontMono
                    font.pixelSize: Tokens.clockSize
                    font.weight: Font.DemiBold
                    font.letterSpacing: -1

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openView("calendar")
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    text: Qt.formatDate(root.now, "ddd, d MMM")
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.dateSize
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: Tokens.avatarSize
                height: Tokens.avatarSize
                radius: width / 2
                color: Theme.accent

                Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    visible: !avatar.ready
                    text: (Stack.env("USER") || "?").charAt(0).toUpperCase()
                    color: Theme.onAccent
                    font.family: Tokens.fontUi
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                }

                RoundImage {
                    id: avatar
                    anchors.fill: parent
                    source: "file://" + S.expandHome(Config.values.avatar, Stack.env("HOME"))
                }
            }
        }

        Item {
            width: 1
            height: Tokens.headerGap - Tokens.gap
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: text !== ""
            text: Config.notice !== "" ? Config.notice : Settings.notice !== "" ? Settings.notice : Resin.notice !== "" ? Resin.notice : (Theme.errors.length > 0 ? Theme.errors[0] : "")
            wrapMode: Text.WordWrap
            color: Theme.danger
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.smallSize
        }

        Grid {
            width: parent.width
            columns: 2
            spacing: Tokens.gap

            Repeater {
                model: root.tiles
                delegate: Tile {
                    required property var modelData
                    width: (column.width - Tokens.gap) / 2
                    icon: modelData.icon
                    title: modelData.title
                    subtitle: modelData.subtitle
                    active: modelData.active
                    onIconClicked: root.iconAction(modelData.key)
                    onBodyClicked: root.bodyAction(modelData)
                }
            }
        }

        Slider {
            width: parent.width
            visible: Audio.available && root.cfg.volume
            value: Audio.muted ? 0 : Audio.volume
            icon: Audio.muted ? Icons.GLYPHS.volumeMute : Icons.GLYPHS.volume
            label: Math.round(Audio.volume * 100) + "%"
            trailing: Audio.outputName + " ›"
            onMoved: v => Audio.setVolume(v)
            onIconClicked: Audio.toggleMute()
            onTrailingClicked: root.openView("outputs")
        }

        MediaCard {
            width: parent.width
            visible: Media.available && root.cfg.media
            onOpened: root.openView("media")
        }

        Row {
            id: bottomRow

            readonly property real spare: (gear.visible ? gear.width + 10 : 0) + (Displays.available ? 10 : 0)

            width: parent.width
            spacing: 10

            RowButton {
                visible: Displays.available
                width: (bottomRow.width - bottomRow.spare) / 2
                icon: Icons.GLYPHS.displays
                label: "Displays"
                onClicked: root.openView("displays")
            }

            RowButton {
                width: (bottomRow.width - bottomRow.spare) / (Displays.available ? 2 : 1)
                icon: Icons.GLYPHS.theme
                label: "Theme"
                onClicked: root.openView("theme")
            }

            RowButton {
                id: gear
                icon: Icons.GLYPHS.settings
                onClicked: root.openView("settings")
            }
        }
    }
}
