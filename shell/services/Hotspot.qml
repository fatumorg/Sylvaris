pragma Singleton

import QtQuick
import SylStack

Singleton {
    id: root

    readonly property bool demo: Demo.enabled
    readonly property string conName: "sylvaris-hotspot"
    property bool installed: false
    readonly property bool available: root.demo || (root.installed && NetworkService.hasWifi)
    property bool active: false
    property bool profileExists: false
    property string error: ""

    function refresh(): void {
        if (root.demo || !root.installed || query.running)
            return;
        query.running = true;
    }

    readonly property string script: "c=$1; s=$2; b=$3; ch=''; [ \"$b\" = a ] && ch=36; IFS= read -r pw || pw=''; if [ \"$(nmcli radio wifi)\" != enabled ]; then nmcli radio wifi on || exit 1; echo radio; fi; dev=''; i=0; while [ $i -lt 20 ]; do dev=$(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$2 == \"wifi\" && $3 != \"unavailable\" { print $1; exit }'); [ -n \"$dev\" ] && break; sleep 0.5; i=$((i + 1)); done; [ -n \"$dev\" ] || { echo 'No Wi-Fi device is available' >&2; exit 1; }; if nmcli -t -f NAME connection show | grep -qxF \"$c\"; then nmcli connection modify \"$c\" connection.interface-name \"$dev\" 802-11-wireless.ssid \"$s\" 802-11-wireless.band \"$b\" 802-11-wireless.channel \"$ch\" || exit 1; else nmcli connection add type wifi ifname \"$dev\" con-name \"$c\" autoconnect no ssid \"$s\" 802-11-wireless.mode ap 802-11-wireless.band \"$b\" 802-11-wireless.channel \"$ch\" ipv4.method shared ipv6.method ignore wifi-sec.key-mgmt wpa-psk wifi-sec.proto rsn wifi-sec.pairwise ccmp wifi-sec.group ccmp >/dev/null || exit 1; fi; if [ -n \"$pw\" ]; then printf 'set wifi-sec.psk %s\\nsave persistent\\nquit\\n' \"$pw\" | nmcli connection edit \"$c\" >/dev/null || exit 1; fi; nmcli -w 25 connection up \"$c\" >/dev/null && exit 0; [ \"$b\" = a ] || exit 1; nmcli connection modify \"$c\" 802-11-wireless.band bg 802-11-wireless.channel '' && nmcli -w 25 connection up \"$c\" >/dev/null && echo fallback"
    property bool radioOwned: false
    readonly property bool busy: startProc.running || downProc.running

    function start(ssid: string, password: string, band: string): void {
        if (root.busy)
            return;
        if (ssid.trim() === "" || ssid.length > 32) {
            root.error = "The network name needs 1 to 32 characters";
            return;
        }
        if (password.length < 8 && !(password === "" && root.profileExists)) {
            root.error = "The password needs at least 8 characters";
            return;
        }
        root.error = "";
        Settings.set("hotspot.ssid", ssid);
        Settings.set("hotspot.band", band);
        if (root.demo) {
            root.active = true;
            root.profileExists = true;
            return;
        }
        startProc.password = password;
        startProc.command = ["sh", "-c", root.script, "sylvaris-hotspot", root.conName, ssid, band === "a" ? "a" : "bg"];
        startProc.running = true;
    }

    function stop(): void {
        if (root.demo) {
            root.active = false;
            return;
        }
        downProc.command = ["sh", "-c", "nmcli connection down \"$1\"; [ \"$2\" = 1 ] && nmcli radio wifi off; exit 0", "sylvaris-hotspot", root.conName, root.radioOwned ? "1" : "0"];
        root.radioOwned = false;
        downProc.running = true;
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v nmcli"]
        running: true
        onExited: code => {
            root.installed = code === 0;
            root.refresh();
        }
    }

    Process {
        id: query
        command: ["nmcli", "-t", "-f", "NAME,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                let exists = false;
                let active = false;
                for (const line of text.split("\n")) {
                    const i = line.lastIndexOf(":");
                    if (i < 0 || line.slice(0, i) !== root.conName)
                        continue;
                    exists = true;
                    active = line.slice(i + 1) === "yes";
                }
                root.profileExists = exists;
                root.active = active;
            }
        }
    }

    Process {
        id: startProc
        property string password: ""
        stdinEnabled: true
        onStarted: {
            write(startProc.password + "\n");
            startProc.password = "";
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            id: startOut
        }
        stderr: StdioCollector {
            id: startErr
        }
        onExited: code => {
            stdinEnabled = true;
            const out = startOut.text.split("\n");
            if (out.indexOf("radio") >= 0)
                root.radioOwned = true;
            if (code !== 0)
                root.error = (startErr.text.trim().split("\n").pop() || "nmcli could not start the hotspot") + (Settings.values.hotspot.band === "a" ? ". 5 GHz needs a Wi-Fi country to be set; 2.4 GHz works everywhere" : "");
            else if (out.indexOf("fallback") >= 0) {
                Settings.set("hotspot.band", "bg");
                root.error = "5 GHz is blocked because no Wi-Fi country is set, so the hotspot runs on 2.4 GHz";
            }
            root.refresh();
        }
    }

    Process {
        id: downProc
        onExited: root.refresh()
    }
}
