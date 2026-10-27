pragma Singleton

import QtQuick
import QtQml
import QtQml.Models
import SylStack
import "../lib/icons.mjs" as Icons
import "../lib/orbit.mjs" as O

Singleton {
    id: root

    readonly property bool demo: Demo.enabled
    property bool demoEnabled: true
    property bool demoScanning: false
    property var demoNetworks: JSON.parse(JSON.stringify(Demo.wifi))
    readonly property var wifiDevice: root.demo ? null : root.findDevice(DeviceType.Wifi)
    readonly property bool wiredConnected: !root.demo && root.anyWired()
    readonly property bool available: root.demo || Networking.backend === NetworkBackendType.NetworkManager
    readonly property bool hasWifi: root.demo || root.wifiDevice !== null
    readonly property bool enabled: root.demo ? root.demoEnabled : Networking.wifiEnabled
    readonly property bool scanning: root.demo ? root.demoScanning : (root.wifiDevice !== null && root.wifiDevice.scannerEnabled)
    readonly property var networks: root.demo ? root.demoNetworks : root.realNetworks()
    readonly property var items: root.networks.map(n => ({
                key: n.name,
                name: n.name,
                icon: Icons.wifiIcon(n.signal),
                connected: n.connected,
                known: n.known,
                signal: Icons.normalizeSignal(n.signal),
                security: n.security,
                open: n.open,
                phase: O.phaseOf(n.state || "", undefined, true)
            }))
    readonly property string summary: {
        if (!root.available)
            return root.wiredConnected ? "Wired" : "Unavailable";
        if (!root.enabled || !root.hasWifi)
            return root.wiredConnected ? "Wired" : "Off";
        const moving = root.items.find(i => i.phase !== "");
        if (moving)
            return O.busyLabel(moving.phase);
        for (const i of root.items) {
            if (i.connected)
                return i.name;
        }
        return root.wiredConnected ? "Wired" : "Not connected";
    }
    property string error: ""
    property string errorKey: ""

    function findDevice(type: var): var {
        for (const d of Networking.devices.values) {
            if (d.type === type)
                return d;
        }
        return null;
    }

    function anyWired(): bool {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wired && d.connected)
                return true;
        }
        return false;
    }

    function realNetworks(): var {
        if (root.wifiDevice === null)
            return [];
        const out = [];
        for (const n of root.wifiDevice.networks.values) {
            out.push({
                name: n.name,
                signal: n.signalStrength,
                security: WifiSecurityType.toString(n.security),
                open: n.security === WifiSecurityType.Open,
                connected: n.connected,
                known: n.known,
                state: n.stateChanging ? (n.connected ? "disconnecting" : "connecting") : ""
            });
        }
        return out;
    }

    function network(key: string): var {
        if (root.wifiDevice === null)
            return null;
        for (const n of root.wifiDevice.networks.values) {
            if (n.name === key)
                return n;
        }
        return null;
    }

    function item(key: string): var {
        for (const i of root.items) {
            if (i.key === key)
                return i;
        }
        return null;
    }

    function setEnabled(v: bool): void {
        if (root.demo)
            root.demoEnabled = v;
        else
            Networking.wifiEnabled = v;
    }

    function scan(v: bool): void {
        if (root.demo)
            root.demoScanning = v;
        else if (root.wifiDevice !== null)
            root.wifiDevice.scannerEnabled = v;
        if (v)
            scanStop.restart();
        else
            scanStop.stop();
    }

    function needsPassword(key: string): bool {
        const i = root.item(key);
        return i !== null && !i.open && !i.known;
    }

    function connect(key: string): void {
        if (root.demo) {
            root.demoNetworks = root.demoNetworks.map(n => n.name === key ? Object.assign({}, n, {
                        state: "connecting"
                    }) : n);
            demoSettle.key = key;
            demoSettle.restart();
            return;
        }
        const n = root.network(key);
        if (n !== null)
            n.connect();
    }

    function connectWithPsk(key: string, psk: string): void {
        if (root.demo) {
            root.connect(key);
            return;
        }
        const n = root.network(key);
        if (n !== null)
            n.connectWithPsk(psk);
    }

    function disconnect(key: string): void {
        if (root.demo) {
            root.demoNetworks = root.demoNetworks.map(n => n.name === key ? Object.assign({}, n, {
                        connected: false
                    }) : n);
            return;
        }
        const n = root.network(key);
        if (n !== null)
            n.disconnect();
    }

    function forget(key: string): void {
        if (root.demo) {
            root.demoNetworks = root.demoNetworks.map(n => n.name === key ? Object.assign({}, n, {
                        connected: false,
                        known: false
                    }) : n);
            return;
        }
        const n = root.network(key);
        if (n !== null)
            n.forget();
    }

    function reasonText(reason: var): string {
        if (reason === ConnectionFailReason.NoSecrets)
            return "Wrong or missing password";
        if (reason === ConnectionFailReason.WifiAuthTimeout)
            return "Authentication timed out";
        if (reason === ConnectionFailReason.WifiNetworkLost)
            return "Network lost";
        return "Couldn't connect";
    }

    function fail(key: string, message: string): void {
        root.error = message;
        root.errorKey = key;
        errorTimer.restart();
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

    Instantiator {
        model: root.wifiDevice !== null ? root.wifiDevice.networks : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason: var): void {
                root.fail(modelData.name, root.reasonText(reason));
            }
        }
    }

    Timer {
        id: demoSettle
        property string key: ""
        interval: 1500
        onTriggered: root.demoNetworks = root.demoNetworks.map(n => Object.assign({}, n, {
                    connected: n.name === demoSettle.key,
                    known: n.known || n.name === demoSettle.key,
                    state: ""
                }))
    }
}
