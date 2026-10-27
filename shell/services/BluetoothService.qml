pragma Singleton

import QtQuick
import SylStack
import "../lib/icons.mjs" as Icons
import "../lib/audio.mjs" as AudioLib
import "../lib/orbit.mjs" as O

Singleton {
    id: root

    readonly property bool demo: Demo.enabled
    property bool demoEnabled: true
    property bool demoScanning: false
    property var demoDevices: JSON.parse(JSON.stringify(Demo.bluetooth))
    property var demoCards: JSON.parse(JSON.stringify(Demo.cards))
    readonly property var adapter: root.demo ? null : Bluetooth.defaultAdapter
    readonly property bool available: root.demo || root.adapter !== null
    readonly property bool enabled: root.demo ? root.demoEnabled : (root.adapter !== null && root.adapter.enabled)
    readonly property bool scanning: root.demo ? root.demoScanning : (root.adapter !== null && root.adapter.discovering)
    readonly property var devices: root.demo ? root.demoDevices : root.realDevices()
    readonly property var items: root.devices.map(d => ({
                key: d.address,
                name: d.name,
                icon: Icons.bluetoothIcon(d.icon),
                connected: d.connected,
                known: d.paired,
                trusted: d.trusted === true,
                battery: d.batteryAvailable ? Math.round(d.battery * 100) : -1,
                audio: Icons.isAudioDevice(d.icon),
                phase: O.phaseOf(d.state || "", root.pending[d.address], d.paired, d.connected)
            }))
    readonly property string summary: {
        if (!root.available)
            return "Unavailable";
        if (!root.enabled)
            return "Off";
        const moving = root.items.find(i => i.phase !== "");
        if (moving)
            return O.busyLabel(moving.phase);
        const live = root.items.filter(i => i.connected);
        if (live.length === 1)
            return live[0].name;
        if (live.length > 1)
            return live.length + " connected";
        return "On";
    }
    property string error: ""
    property string errorKey: ""
    property var pending: ({})
    property bool pactlInstalled: false
    property var cards: []

    function realDevices(): var {
        const out = [];
        for (const d of Bluetooth.devices.values) {
            out.push({
                address: d.address,
                name: d.name || d.deviceName || d.address,
                icon: d.icon,
                connected: d.connected,
                paired: d.paired,
                trusted: d.trusted,
                batteryAvailable: d.batteryAvailable,
                battery: d.battery,
                state: d.pairing ? "pairing" : d.state === BluetoothDeviceState.Connecting ? "connecting" : d.state === BluetoothDeviceState.Disconnecting ? "disconnecting" : ""
            });
        }
        return out;
    }

    function device(key: string): var {
        if (root.demo)
            return null;
        for (const d of Bluetooth.devices.values) {
            if (d.address === key)
                return d;
        }
        return null;
    }

    function patchDemo(key: string, patch: var): void {
        root.demoDevices = root.demoDevices.map(d => d.address === key ? Object.assign({}, d, patch) : d);
    }

    function setEnabled(v: bool): void {
        if (root.demo)
            root.demoEnabled = v;
        else if (root.adapter !== null)
            root.adapter.enabled = v;
    }

    function scan(v: bool): void {
        if (root.demo)
            root.demoScanning = v;
        else if (root.adapter !== null)
            root.adapter.discovering = v;
        if (v)
            scanStop.restart();
        else
            scanStop.stop();
    }

    function track(key: string, action: string, kicked: bool): void {
        const next = Object.assign({}, root.pending);
        next[key] = {
            action: action,
            until: Date.now() + 15000,
            kicked: kicked
        };
        root.pending = next;
    }

    function fail(key: string, message: string): void {
        root.error = message;
        root.errorKey = key;
        errorTimer.restart();
    }

    function connect(key: string): void {
        if (root.demo) {
            const known = root.demoDevices.some(d => d.address === key && d.paired);
            root.patchDemo(key, {
                state: known ? "connecting" : "pairing"
            });
            demoSettle.key = key;
            demoSettle.restart();
            return;
        }
        const d = root.device(key);
        if (d === null)
            return;
        if (d.paired) {
            d.connect();
            root.track(key, "connect", true);
        } else {
            d.pair();
            root.track(key, "connect", false);
        }
    }

    function disconnect(key: string): void {
        if (root.demo) {
            root.patchDemo(key, {
                connected: false
            });
            return;
        }
        const d = root.device(key);
        if (d === null)
            return;
        d.disconnect();
        root.track(key, "disconnect", true);
    }

    function forget(key: string): void {
        if (root.demo) {
            root.demoDevices = root.demoDevices.filter(d => d.address !== key);
            return;
        }
        const d = root.device(key);
        if (d !== null)
            d.forget();
    }

    function setTrusted(key: string, v: bool): void {
        if (root.demo) {
            root.patchDemo(key, {
                trusted: v
            });
            return;
        }
        const d = root.device(key);
        if (d !== null)
            d.trusted = v;
    }

    function checkPending(): void {
        const next = {};
        const now = Date.now();
        for (const key of Object.keys(root.pending)) {
            const p = root.pending[key];
            const d = root.device(key);
            if (d === null)
                continue;
            if (p.action === "connect") {
                if (d.connected)
                    continue;
                if (d.paired && !d.pairing && !p.kicked) {
                    d.connect();
                    p.kicked = true;
                }
            } else if (!d.connected) {
                continue;
            }
            if (now > p.until) {
                root.fail(key, p.action === "connect" ? "Couldn't connect" : "Couldn't disconnect");
                continue;
            }
            next[key] = p;
        }
        root.pending = next;
    }

    function profile(key: string): var {
        return AudioLib.cardProfile(root.demo ? root.demoCards : root.cards, key);
    }

    function switchProfile(key: string): void {
        const p = root.profile(key);
        if (p === null || p.next === "")
            return;
        if (root.demo) {
            root.demoCards = root.demoCards.map(c => c.name === p.card ? Object.assign({}, c, {
                        active_profile: p.next
                    }) : c);
            return;
        }
        Stack.execDetached(["pactl", "set-card-profile", p.card, p.next]);
        profileRefresh.restart();
    }

    function refreshProfiles(): void {
        if (root.demo || !root.pactlInstalled || cardsProc.running)
            return;
        cardsProc.running = true;
    }

    Timer {
        id: errorTimer
        interval: 4000
        onTriggered: {
            root.error = "";
            root.errorKey = "";
        }
    }

    Timer {
        id: scanStop
        interval: 20000
        onTriggered: root.scan(false)
    }

    Timer {
        interval: 1000
        repeat: true
        running: Object.keys(root.pending).length > 0
        onTriggered: root.checkPending()
    }

    Timer {
        id: demoSettle
        property string key: ""
        interval: 1500
        onTriggered: root.patchDemo(demoSettle.key, {
            connected: true,
            paired: true,
            state: ""
        })
    }

    Timer {
        id: profileRefresh
        interval: 800
        onTriggered: root.refreshProfiles()
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v pactl"]
        running: true
        onExited: code => {
            root.pactlInstalled = code === 0;
            root.refreshProfiles();
        }
    }

    Process {
        id: cardsProc
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: root.cards = AudioLib.parseCards(text)
        }
    }
}
