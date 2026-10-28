import QtQuick
import SylStack
import qs
import qs.services
import qs.components
import qs.settings
import "../../lib/rgb.mjs" as R
import "../../lib/icons.mjs" as Icons

Popup {
    id: root

    readonly property var cfg: Settings.values.rgb
    readonly property string helper: Stack.shellDir + "/helpers/rgb.py"
    readonly property string accent: R.hex(Theme.accent.toString())
    readonly property string themeRgb: Theme.theme.colors.rgb || ""
    readonly property string sharedColor: R.shared(root.cfg, root.accent, root.themeRgb)
    readonly property string reactTargets: root.armed && root.error === "" ? JSON.stringify(R.reactTargets(root.devices, root.cfg, root.accent, root.themeRgb)) : "[]"
    property bool reactUp: true
    property int reactRetries: 0
    property var devices: []
    property var profiles: []
    property string error: ""
    property bool checked: false
    property bool armed: false
    property string selected: ""
    property string notice: ""
    property bool reapply: false
    property bool watchUp: true
    property int watchRetries: 0

    namespace: "sylrgb"
    corner: root.local.placement.rgb
    panelWidth: Tokens.rgbWidth
    panelHeight: Tokens.rgbHeight

    function refresh(): void {
        if (lister.running)
            lister.again = true;
        else
            lister.running = true;
    }

    function apply(): void {
        const ops = R.plan(root.devices, root.cfg, root.accent, root.themeRgb);
        if (ops.length === 0)
            return;
        applier.ops = JSON.stringify(ops);
        if (applier.running)
            applier.again = true;
        else
            applier.running = true;
    }

    function own(name: string): var {
        return root.cfg.devices[name] || {
            off: false,
            color: "",
            mode: "",
            press: ""
        };
    }

    function patch(name: string, change: var): void {
        const next = Object.assign({}, root.cfg.devices);
        const entry = Object.assign({}, root.own(name), change);
        if (!entry.off && entry.color === "" && entry.mode === "" && entry.press === "")
            delete next[name];
        else
            next[name] = entry;
        Settings.set("rgb.devices", next);
    }

    function named(words: var): string {
        const name = words.join(" ").trim();
        if (name === "")
            return "";
        const hit = root.devices.find(d => d.name.toLowerCase() === name.toLowerCase());
        if (hit === undefined)
            throw new Error("no device called " + name + "; `sylvaris rgb list` shows them");
        return hit.name;
    }

    function setColor(value: string, words: var): string {
        const c = R.hex(value);
        if (c === "")
            throw new Error("give a colour like ff8800 or #ff8800");
        const name = root.named(words || []);
        if (name === "") {
            Settings.set("rgb.follow", false);
            Settings.set("rgb.color", c);
        } else {
            root.patch(name, {
                color: c,
                off: false
            });
        }
        Settings.set("rgb.on", true);
        return name === "" ? "every device " + c : name + " " + c;
    }

    function setMode(mode: string, words: var): string {
        const name = root.named(words || []);
        const targets = name === "" ? root.devices : root.devices.filter(d => d.name === name);
        const fit = targets.filter(d => d.modes.some(m => m.name.toLowerCase() === String(mode).toLowerCase()));
        if (fit.length === 0)
            throw new Error("no device has an effect called " + mode);
        for (const d of fit)
            root.patch(d.name, {
                mode: d.modes.find(m => m.name.toLowerCase() === String(mode).toLowerCase()).name,
                off: false
            });
        Settings.set("rgb.on", true);
        return fit.map(d => d.name).join(", ");
    }

    function setOn(on: bool): void {
        Settings.set("rgb.on", on);
    }

    function restart(): void {
        if (restarter.running)
            return;
        root.notice = "Restarting OpenRGB…";
        restarter.running = true;
    }

    function setFollow(on: bool): void {
        Settings.set("rgb.follow", on);
        Settings.set("rgb.on", true);
    }

    function setBrightness(v: real): void {
        Settings.set("rgb.brightness", Math.round(Math.max(0, Math.min(100, v))));
    }

    function loadProfile(name: string): void {
        if (root.profiles.indexOf(name) < 0)
            throw new Error("OpenRGB has no profile called " + name);
        Settings.set("rgb.color", "");
        Settings.set("rgb.follow", false);
        Settings.set("rgb.devices", ({}));
        Settings.set("rgb.on", true);
        loader.command = ["python3", root.helper, root.cfg.host, String(root.cfg.port), "load", name];
        loader.running = true;
    }

    function state(): var {
        return {
            open: root.shown,
            on: root.cfg.on,
            color: root.sharedColor,
            follow: root.cfg.follow,
            vivid: root.cfg.vivid,
            brightness: root.cfg.brightness,
            error: root.error,
            profiles: root.profiles,
            devices: root.devices.map(d => ({
                        name: d.name,
                        type: d.type,
                        mode: d.mode,
                        color: d.color,
                        modes: d.modes.map(m => m.name),
                        own: root.cfg.devices[d.name] || null
                    }))
        };
    }

    onOpened: root.refresh()
    onCfgChanged: {
        if (root.armed)
            later.restart();
    }
    onAccentChanged: {
        if (root.armed && root.cfg.follow)
            later.restart();
    }
    onThemeRgbChanged: {
        if (root.armed && root.cfg.follow)
            later.restart();
    }
    onReactTargetsChanged: {
        if (reactor.running)
            reactor.signal(15);
    }

    function setPress(value: string, words: var): string {
        const name = root.named(words || []);
        const mice = name === "" ? root.devices.filter(d => d.type === "mouse") : root.devices.filter(d => d.name === name);
        if (mice.length === 0)
            throw new Error("no mouse found; name the device: sylvaris rgb press ffffff \"Device name\"");
        const c = value === "off" ? "" : R.hex(value);
        if (value !== "off" && c === "")
            throw new Error("give a colour like ffffff, or off");
        for (const d of mice)
            root.patch(d.name, {
                press: c
            });
        return mice.map(d => d.name).join(", ") + (c === "" ? " press flash off" : " flashes " + c);
    }

    Timer {
        id: later
        interval: 250
        onTriggered: root.apply()
    }

    Process {
        id: lister
        property bool again: false
        running: true
        command: ["python3", root.helper, root.cfg.host, String(root.cfg.port), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = null;
                try {
                    r = JSON.parse(text);
                } catch (e) {}
                root.checked = true;
                if (r === null || !r.ok) {
                    root.error = r === null ? "the RGB helper did not answer" : r.error;
                    root.devices = [];
                    return;
                }
                root.error = "";
                root.devices = r.devices;
                root.profiles = r.profiles;
                const again = root.armed ? root.reapply : root.cfg.restore;
                root.armed = true;
                root.reapply = false;
                if (again)
                    root.apply();
            }
        }
        onExited: {
            if (lister.again) {
                lister.again = false;
                lister.running = true;
            }
        }
    }

    Process {
        id: applier
        property string ops: "[]"
        property bool again: false
        command: ["python3", root.helper, root.cfg.host, String(root.cfg.port), "apply"]
        stdinEnabled: true
        onStarted: {
            write(applier.ops);
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    const bad = r.ok ? r.results.filter(x => !x.ok) : [];
                    root.notice = !r.ok ? r.error : bad.length > 0 ? bad[0].error : "";
                } catch (e) {
                    root.notice = "the RGB helper did not answer";
                }
            }
        }
        onExited: {
            stdinEnabled = true;
            if (applier.again) {
                applier.again = false;
                applier.running = true;
            } else if (root.shown) {
                root.refresh();
            }
        }
    }

    Process {
        id: restarter
        command: ["sh", "-c", "if systemctl --user cat openrgb.service >/dev/null 2>&1; then systemctl --user restart openrgb.service; elif systemctl cat openrgb.service >/dev/null 2>&1; then systemctl restart openrgb.service; else exit 3; fi"]
        onExited: code => {
            root.notice = code === 0 ? "" : code === 3 ? "OpenRGB does not run as a systemd service here; restart it yourself" : "OpenRGB could not be restarted";
            if (code === 0) {
                root.reapply = true;
                restartedLater.restart();
            }
        }
    }

    Timer {
        id: restartedLater
        interval: 2500
        onTriggered: {
            root.reapply = true;
            root.refresh();
        }
    }

    Process {
        id: loader
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.notice = r.ok ? "" : r.error;
                } catch (e) {}
                root.refresh();
            }
        }
    }

    Timer {
        id: watchAgain
        interval: Math.min(60000, 2000 * Math.pow(2, root.watchRetries))
        onTriggered: {
            root.watchRetries++;
            root.watchUp = true;
        }
    }

    Timer {
        id: reactAgain
        interval: Math.min(60000, 2000 * Math.pow(2, root.reactRetries))
        onTriggered: {
            root.reactRetries++;
            root.reactUp = true;
        }
    }

    Process {
        id: reactor
        property string sent: "[]"
        running: root.reactUp && root.reactTargets !== "[]"
        command: ["python3", root.helper, root.cfg.host, String(root.cfg.port), "react"]
        stdinEnabled: true
        onStarted: {
            reactor.sent = root.reactTargets;
            write(root.reactTargets + "\n");
        }
        onExited: {
            root.reactUp = false;
            if (root.reactTargets === "[]" || reactor.sent !== root.reactTargets)
                Qt.callLater(() => root.reactUp = true);
            else
                reactAgain.restart();
        }
        stdout: SplitParser {
            onRead: line => {
                if (line === "ready") {
                    root.reactRetries = 0;
                    return;
                }
                try {
                    const r = JSON.parse(line);
                    if (!r.ok)
                        root.notice = r.error;
                } catch (e) {}
            }
        }
    }

    Process {
        running: root.watchUp
        command: ["python3", root.helper, root.cfg.host, String(root.cfg.port), "watch"]
        onExited: {
            root.watchUp = false;
            watchAgain.restart();
        }
        stdout: SplitParser {
            onRead: line => {
                if (line === "ready") {
                    if (root.watchRetries > 0 || root.error !== "") {
                        root.reapply = root.cfg.restore;
                        root.refresh();
                    }
                    root.watchRetries = 0;
                } else if (line === "changed") {
                    root.reapply = root.cfg.restore;
                    root.refresh();
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body
            width: parent.width
            spacing: 18

            Row {
                width: parent.width
                spacing: 10

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.GLYPHS.rgb
                    size: 20
                    color: root.cfg.on ? (root.sharedColor !== "" ? root.sharedColor : Theme.accent) : Theme.textDim
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30 - onToggle.width - 10

                    Text {
                        textFormat: Text.PlainText
                        text: "Lighting"
                        color: Theme.text
                        font.family: Tokens.fontDisplay
                        font.pixelSize: Tokens.titleSize
                        font.weight: Tokens.titleWeight
                    }

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        elide: Text.ElideRight
                        text: !root.checked ? "Looking for OpenRGB…" : R.summary(root.cfg, root.devices.length, root.error)
                        color: Theme.textDim
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.smallSize
                    }
                }

                Toggle {
                    id: onToggle
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.cfg.on
                    onToggled: v => root.setOn(v)
                }
            }

            Row {
                width: parent.width
                spacing: 8

                RowButton {
                    width: (parent.width - 8) / 2
                    icon: root.cfg.on ? Icons.GLYPHS.power : Icons.GLYPHS.rgb
                    label: root.cfg.on ? "Turn all lighting off" : "Turn lighting on"
                    onClicked: root.setOn(!root.cfg.on)
                }

                RowButton {
                    width: (parent.width - 8) / 2
                    icon: Icons.GLYPHS.restart
                    label: restarter.running ? "Restarting…" : "Restart OpenRGB"
                    onClicked: root.restart()
                }
            }

            Text {
                textFormat: Text.PlainText
                visible: root.error !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: root.error
                color: Theme.danger
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }

            Card {
                title: "Every device"
                note: root.cfg.follow ? "Following your theme's accent colour." : ""
                visible: root.error === ""

                Swatches {
                    current: root.cfg.follow ? "theme" : root.cfg.color
                    onPicked: c => c === "theme" ? root.setFollow(true) : root.setColor(c, [])
                }

                Item {
                    width: parent.width
                    height: 52

                    Slider {
                        anchors.centerIn: parent
                        width: parent.width - 32
                        value: root.cfg.brightness / 100
                        icon: Icons.GLYPHS.brightness
                        label: root.cfg.brightness + "%"
                        onMoved: v => root.setBrightness(v * 100)
                    }
                }
            }

            Repeater {
                model: root.devices

                delegate: DeviceRow {
                    required property var modelData
                    device: modelData
                }
            }

            Card {
                title: "OpenRGB profiles"
                note: "Loading one hands the lights back to that profile and clears the colours picked here."
                visible: root.profiles.length > 0 && root.error === ""

                Flow {
                    x: 16
                    width: parent.width - 32
                    spacing: 6
                    bottomPadding: 12

                    Repeater {
                        model: root.profiles

                        delegate: Chip {
                            required property string modelData
                            text: modelData
                            glyph: Icons.GLYPHS.palette
                            onClicked: root.loadProfile(modelData)
                        }
                    }
                }
            }

            Text {
                textFormat: Text.PlainText
                visible: root.notice !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: root.notice
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }
        }
    }

    component Swatches: Flow {
        id: sw

        property string current: ""
        property bool offerTheme: true
        property bool offerShared: false
        property string sharedLabel: "Same as all"

        signal picked(string c)

        x: 16
        width: parent.width - 32
        spacing: 8
        topPadding: 4
        bottomPadding: 8

        Chip {
            visible: sw.offerShared
            text: sw.sharedLabel
            lit: sw.current === ""
            onClicked: sw.picked("")
        }

        Chip {
            visible: sw.offerTheme
            text: "Theme"
            glyph: Icons.GLYPHS.theme
            lit: sw.current === "theme"
            onClicked: sw.picked("theme")
        }

        Repeater {
            model: R.PRESETS

            delegate: Item {
                id: dot
                required property string modelData
                width: 32
                height: 32

                Rectangle {
                    anchors.centerIn: parent
                    width: dotArea.containsMouse ? 28 : 24
                    height: width
                    radius: width / 2
                    color: dot.modelData
                    border.width: sw.current === dot.modelData ? 3 : 1
                    border.color: sw.current === dot.modelData ? Theme.text : Qt.alpha(Theme.text, 0.25)

                    Behavior on width {
                        NumberAnimation {
                            duration: Tokens.stateDuration
                        }
                    }
                }

                MouseArea {
                    id: dotArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sw.picked(dot.modelData)
                }
            }
        }

        TextBox {
            width: 118
            height: 32
            placeholder: "#hex"
            text: sw.current === "theme" ? "" : sw.current
            onAccepted: {
                const c = R.hex(text);
                if (c !== "")
                    sw.picked(c);
            }
        }
    }

    component DeviceRow: Item {
        id: row

        property var device: null
        readonly property var mine: root.own(row.device.name)
        readonly property bool open: root.selected === row.device.name

        width: parent.width
        height: head.height + (row.open ? extra.implicitHeight + 8 : 0)
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Tokens.moveDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.moveCurve
            }
        }

        Glass {
            anchors.fill: parent
            radius: Tokens.radiusRow
            inner: true
            offColor: Theme.tintMid
            hot: headArea.containsMouse
        }

        Item {
            id: head
            width: parent.width
            height: 60

            MouseArea {
                id: headArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected = row.open ? "" : row.device.name
            }

            Glyph {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.GLYPHS[R.glyphOf(row.device.type)]
                size: 20
                color: row.mine.off || !root.cfg.on ? Theme.textDim : Theme.accent
            }

            Column {
                x: 52
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 52 - 110

                Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.device.name
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.bodySize
                }

                Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.mine.off ? "Off" : row.mine.mode !== "" ? row.mine.mode : row.mine.color !== "" ? "Own colour" : row.device.mode
                    color: Theme.textDim
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize
                }
            }

            Rectangle {
                anchors.right: devToggle.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: Tokens.r(7)
                visible: row.device.color !== ""
                color: row.device.color !== "" ? row.device.color : "transparent"
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.3)
            }

            Toggle {
                id: devToggle
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                checked: !row.mine.off
                onToggled: v => root.patch(row.device.name, {
                        off: !v
                    })
            }
        }

        Column {
            id: extra
            y: head.height
            width: parent.width
            spacing: 6
            visible: row.open

            Text {
                textFormat: Text.PlainText
                x: 16
                text: "Colour"
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.tinySize
            }

            Swatches {
                offerTheme: false
                offerShared: true
                current: row.mine.color
                onPicked: c => root.patch(row.device.name, {
                        color: c,
                        off: false
                    })
            }

            Text {
                textFormat: Text.PlainText
                x: 16
                visible: row.device.type === "mouse"
                text: "When a button is pressed"
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.tinySize
            }

            Swatches {
                visible: row.device.type === "mouse"
                offerTheme: false
                offerShared: true
                sharedLabel: "No flash"
                current: row.mine.press
                onPicked: c => root.patch(row.device.name, {
                        press: c
                    })
            }

            Text {
                textFormat: Text.PlainText
                x: 16
                text: "Effect"
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.tinySize
            }

            Flow {
                x: 16
                width: parent.width - 32
                spacing: 6
                bottomPadding: 8

                Chip {
                    text: "Plain colour"
                    lit: row.mine.mode === ""
                    onClicked: root.patch(row.device.name, {
                        mode: ""
                    })
                }

                Repeater {
                    model: row.device.modes.filter(m => ["direct", "custom", "static", "off"].indexOf(m.name.toLowerCase()) < 0)

                    delegate: Chip {
                        required property var modelData
                        text: modelData.name
                        lit: row.mine.mode.toLowerCase() === modelData.name.toLowerCase()
                        onClicked: root.patch(row.device.name, {
                            mode: modelData.name,
                            off: false
                        })
                    }
                }
            }
        }
    }
}
