pragma Singleton

import QtQuick
import SylStack

Singleton {
    id: root

    readonly property bool plugged: Settings.values.plugins.enabled.airpods === true
    readonly property var device: root.findDevice()
    readonly property string address: root.device === null ? "" : root.device.key
    readonly property string name: root.device === null ? "" : root.device.name
    property bool connected: Demo.enabled
    property var battery: Demo.enabled ? ({
            left: {
                level: 82,
                charging: false
            },
            right: {
                level: 78,
                charging: false
            },
            case: {
                level: 55,
                charging: true
            }
        }) : ({})
    property string noise: Demo.enabled ? "anc" : ""
    property bool awareness: false
    property var ear: ({})
    property string error: ""
    readonly property var devices: root.batteryDevices()

    function findDevice(): var {
        if (!root.plugged)
            return null;
        if (Demo.enabled)
            return {
                key: "00:11:22:33:44:01",
                name: "AirPods Pro"
            };
        const forced = Settings.values.media.airpods;
        for (const d of BluetoothService.items) {
            if (!d.connected)
                continue;
            if (forced !== "" ? d.key === forced : /airpods|beats/i.test(d.name))
                return d;
        }
        return null;
    }

    function send(obj: var): void {
        if (Demo.enabled || !helper.running)
            return;
        helper.write(JSON.stringify(obj) + "\n");
    }

    function setNoise(mode: string): void {
        if (!root.plugged)
            throw new Error("the AirPods plugin is off; turn it on in SylSettings › Plugins or with: sylvaris plugins enable airpods");
        if (["off", "anc", "transparency", "adaptive"].indexOf(mode) < 0)
            throw new Error("expected off, anc, transparency or adaptive");
        if (!root.connected)
            throw new Error("no AirPods connected");
        root.noise = mode;
        root.send({
            cmd: "noise",
            mode: mode
        });
    }

    function setAwareness(v: bool): void {
        if (!root.plugged)
            throw new Error("the AirPods plugin is off; turn it on in SylSettings › Plugins or with: sylvaris plugins enable airpods");
        if (!root.connected)
            throw new Error("no AirPods connected");
        root.awareness = v;
        root.send({
            cmd: "awareness",
            enabled: v
        });
    }

    function ingest(line: string): void {
        let e;
        try {
            e = JSON.parse(line);
        } catch (x) {
            return;
        }
        if (e.event === "connected") {
            root.connected = true;
            root.error = "";
        } else if (e.event === "battery") {
            root.battery = Object.assign({}, root.battery, e.battery);
        } else if (e.event === "noise") {
            root.noise = e.mode;
        } else if (e.event === "awareness") {
            root.awareness = e.enabled;
        } else if (e.event === "ear") {
            root.ear = {
                primary: e.primary,
                secondary: e.secondary
            };
        } else if (e.event === "disconnected" || e.event === "error") {
            root.error = e.message || "";
        }
    }

    function batteryDevices(): var {
        const out = [];
        if (root.connected) {
            for (const part of ["left", "right", "case"]) {
                const b = root.battery[part];
                if (b)
                    out.push({
                        name: root.name + " · " + part.charAt(0).toUpperCase() + part.slice(1),
                        level: b.level,
                        charging: b.charging,
                        kind: part === "case" ? "case" : "earbud"
                    });
            }
        }
        if (Demo.enabled)
            return out.concat([
                {
                    name: "Mouse",
                    level: 64,
                    charging: false,
                    kind: "mouse"
                },
                {
                    name: "Keyboard",
                    level: 31,
                    charging: false,
                    kind: "keyboard"
                }
            ]);
        for (const d of UPower.devices.values) {
            if (!d.ready || !d.isPresent || d.isLaptopBattery || d.type === UPowerDeviceType.LinePower)
                continue;
            if (root.connected && root.name !== "" && d.model === root.name)
                continue;
            out.push({
                name: d.model || UPowerDeviceType.toString(d.type),
                level: Math.round(d.percentage > 1 ? d.percentage : d.percentage * 100),
                charging: d.state === UPowerDeviceState.Charging,
                kind: UPowerDeviceType.toString(d.type).toLowerCase()
            });
        }
        const lap = UPower.displayDevice;
        if (lap && lap.ready && lap.isLaptopBattery)
            out.push({
                name: "This computer",
                level: Math.round(lap.percentage > 1 ? lap.percentage : lap.percentage * 100),
                charging: lap.state === UPowerDeviceState.Charging,
                kind: "battery"
            });
        return out;
    }

    function state(): var {
        return {
            device: root.name,
            address: root.address,
            connected: root.connected,
            battery: root.battery,
            noise: root.noise,
            awareness: root.awareness,
            ear: root.ear,
            error: root.error,
            devices: root.devices
        };
    }

    onAddressChanged: {
        if (Demo.enabled)
            return;
        root.connected = false;
        root.battery = {};
        root.noise = "";
        helper.running = false;
        if (root.address !== "")
            helper.running = true;
    }

    Process {
        id: helper
        command: ["python3", Qt.resolvedUrl("../helpers/airpods.py").toString().replace("file://", ""), root.address]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.ingest(line)
        }
        onExited: {
            root.connected = false;
            if (root.address !== "")
                retry.restart();
        }
    }

    Timer {
        id: retry
        interval: 5000
        onTriggered: {
            if (root.address !== "" && !helper.running)
                helper.running = true;
        }
    }
}
