import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import qs
import qs.services
import qs.plugins.diver
import "../lib/island.mjs" as I
import "../lib/notify.mjs" as N
import "../lib/privacy.mjs" as P

Scope {
    id: root

    readonly property var cfg: Settings.at(root.focusedName).island
    property var peers: ({})
    property var live: []
    property var avoid: null
    property string pinned: ""
    property string hoverScreen: ""
    property string pendingScreen: ""
    property string hotScreen: ""
    readonly property bool hovered: root.hoverScreen !== ""
    readonly property string focusedName: Compositor.focusedName()
    property var flash: null
    property bool armed: false
    property real now: Date.now()
    property string time: Qt.formatTime(new Date(), "HH:mm")
    property int lastNote: -1
    property var devicesBefore: []
    property int replyTo: -1
    property var session: null
    property var cameraUsers: []
    readonly property bool performance: Settings.values.performance
    property string netAnnounced: ""
    readonly property string netName: {
        for (const i of NetworkService.items) {
            if (i.connected)
                return i.name;
        }
        return NetworkService.wiredConnected ? "Wired" : "";
    }
    readonly property var captures: Demo.enabled || !root.cfg.calls && !root.cfg.privacy ? [] : Pipewire.nodes.values.filter(n => n.isStream && !n.isSink)
    readonly property var feeds: {
        const ids = root.captures.map(n => n.id);
        return ids.length === 0 ? [] : Pipewire.linkGroups.values.filter(g => g.source !== null && g.target !== null && ids.indexOf(g.target.id) >= 0);
    }
    readonly property var streams: I.streamsOf(root.captures.map(n => ({
                id: n.id,
                props: n.properties,
                audio: n.audio !== null,
                muted: n.audio !== null && n.audio.muted
            })), root.feeds.map(g => ({
                target: g.target.id,
                source: {
                    stream: g.source.isStream,
                    sink: g.source.isSink,
                    props: g.source.properties
                }
            })))
    readonly property var voiceNow: I.voiceOf(root.streams)
    readonly property var inuse: root.cfg.privacy ? I.inUse(root.streams, root.cameraUsers, root.session === null ? [] : root.session.ids) : null
    readonly property var screenInfo: Compositor.screenFor(Compositor.focusedName())
    readonly property var capture: root.peers.capture === undefined ? null : root.peers.capture
    readonly property bool recording: root.capture !== null && root.capture.recording
    readonly property real inset: {
        const h = I.cardHeight(root.items.map(a => a.kind), root.shortcutsOf(root.cfg.shortcuts).length > 0);
        return (h > 0 ? h : 38) + 8;
    }
    readonly property bool covered: root.avoid !== null && !root.avoid.docked && root.avoid.corner === root.cfg.position && root.screenInfo !== null && root.avoid.screen === root.screenInfo.name
    readonly property bool docked: root.avoid !== null && root.avoid.docked === true && root.screenInfo !== null && root.avoid.screen === root.screenInfo.name
    readonly property var call: {
        if (!root.cfg.calls)
            return null;
        for (const e of Notifications.list) {
            const f = Notifications.facts(e.n);
            if (I.isCall(f))
                return root.chatItem(e, f, "call");
        }
        return null;
    }
    readonly property var items: I.activities({
        call: root.call,
        voice: root.session === null ? null : {
            app: root.session.app,
            glyph: root.session.glyph,
            ids: root.session.ids,
            muted: root.session.muted,
            elapsed: root.now - root.session.since
        },
        flash: root.flash,
        privacy: Privacy.active ? {
            combo: Keybinds.wanted["privacy toggle"] || Keybinds.external["privacy toggle"] || ""
        } : null,
        inuse: root.inuse,
        recording: root.capture === null ? null : {
            on: root.capture.recording,
            started: root.capture.started,
            elapsed: root.now - root.capture.recordStart,
            wait: root.capture.waitUntil - root.now
        },
        alarm: Diver.alarm === null ? null : {
            id: Diver.alarm.id,
            title: Diver.alarm.title
        },
        focus: Diver.focusEnd > root.now ? {
            title: Diver.focusTitle,
            left: Diver.focusEnd - root.now
        } : null,
        next: Diver.active && Diver.next !== null ? {
            text: Diver.plain(Diver.next.task.text),
            mins: Math.round((Diver.next.start - root.now) / 60000)
        } : null,
        media: {
            title: Media.title,
            artist: Media.artist,
            art: Media.art,
            player: Media.identity,
            url: Media.url,
            playing: Media.playing
        }
    }, root.cfg)
    readonly property bool expanded: root.pinned !== "" || root.hotScreen !== ""

    signal requested(string part)

    function chatItem(e: var, f: var, kind: string): var {
        const app = I.chatOf(f);
        const desktop = e.n.desktopEntry ? Apps.entry(e.n.desktopEntry) : null;
        const picture = N.isPicture(e.n.image) ? N.iconSource(e.n.image, name => "") : "";
        const icon = N.iconSource(e.n.appIcon !== "" ? e.n.appIcon : desktop ? desktop.icon : "", name => Quickshell.iconPath(name, true));
        const acts = I.pickActions(e.n.actions.map(a => ({
                        identifier: a.identifier,
                        text: a.text
                    })));
        return {
            kind: kind,
            id: e.id,
            app: app !== null ? app.label : e.n.appName,
            sender: e.n.summary,
            text: f.body,
            art: picture !== "" ? picture : icon,
            reply: e.n.hasInlineReply === true || e.n.actions.some(x => x.identifier === "default"),
            inline: e.n.hasInlineReply === true,
            placeholder: e.n.summary !== "" ? "Reply to " + e.n.summary : e.n.inlineReplyPlaceholder || "Reply",
            accept: acts.accept,
            decline: acts.decline,
            read: acts.read,
            more: Notifications.list.filter(x => x.id !== e.id && I.chatOf(Notifications.facts(x.n)) !== null).length
        };
    }

    function shortcutsOf(ids: var): var {
        return I.shortcutsFor(ids, root.live).map(s => Object.assign({}, s, {
                    lit: root.litOf(s.id),
                    badge: s.id === "notify" ? Notifications.count : 0
                }));
    }

    function litOf(id: string): bool {
        switch (id) {
        case "dnd":
            return Notifications.dnd;
        case "wifi":
            return NetworkService.enabled;
        case "bluetooth":
            return BluetoothService.enabled;
        case "night":
            return NightLight.enabled;
        case "privacy":
            return Privacy.active;
        case "record":
            return root.recording;
        default:
            return false;
        }
    }

    function close(): void {
        root.pinned = "";
    }

    function open(): void {
        root.pinned = root.focusedName;
    }

    function toggle(): void {
        root.pin(root.focusedName);
    }

    function pin(name: string): void {
        root.pinned = root.pinned === name ? "" : name;
    }

    function hover(name: string, on: bool): void {
        if (on) {
            root.hoverScreen = name;
            root.pendingScreen = name;
            leaveTimer.stop();
            enterTimer.restart();
        } else if (root.hoverScreen === name) {
            root.hoverScreen = "";
            enterTimer.stop();
            leaveTimer.restart();
        }
    }

    function toggleOn(screen: var): void {
        root.toggle();
    }

    function show(f: var): void {
        root.flash = f;
        flashTimer.restart();
    }

    function say(text: string): void {
        const f = I.custom(text);
        if (f === null)
            throw new Error("usage: island show <text>");
        root.show(f);
    }

    function runShortcut(id: string): void {
        const s = I.SHORTCUTS[id];
        if (s === undefined)
            throw new Error("unknown shortcut: " + id + "; one of " + Object.keys(I.SHORTCUTS).join(", "));
        if (s.needs.toLowerCase() === s.needs) {
            root.close();
            root.hotScreen = "";
            const p = root.peers[s.run[0]];
            if (p !== undefined && p.toggleFrom !== undefined && ["toggle", "open"].indexOf(s.run[1]) >= 0) {
                root.requested(s.run[0]);
                return;
            }
        }
        const words = id === "record" && root.recording ? ["capture", "stop"] : s.run;
        const out = Ipc.run(words);
        if (out.indexOf("error:") === 0)
            root.say(out.slice(6).trim());
    }

    function partFor(kind: string): string {
        return ({
                media: "media",
                volume: "center",
                device: "center",
                notification: "notify",
                message: "notify",
                call: "notify",
                voice: "",
                alarm: "clock",
                focus: "clock",
                next: "clock",
                recording: "capture"
            })[kind] || "";
    }

    function act(kind: string, what: string): void {
        const a = root.items.find(x => x.kind === kind) || null;
        if (kind === "voice") {
            root.voice(a, what);
            return;
        }
        if (what === "open") {
            const part = root.partFor(kind);
            root.close();
            root.hotScreen = "";
            if (part !== "")
                root.requested(part);
            return;
        }
        if (kind === "message" || kind === "call") {
            root.chat(a, what);
            return;
        }

        if (what.indexOf("seek:") === 0) {
            const x = Number(what.slice(5));
            if (kind === "volume")
                Audio.setVolume(x);
            else
                Media.seekTo(x * Media.length);
            return;
        }
        if (kind === "media")
            what === "previous" ? Media.previous() : what === "next" ? Media.next() : Media.toggle();
        else if (kind === "recording" && root.capture !== null)
            root.capture.stop();
        else if (kind === "focus")
            Diver.stopFocus();
        else if (kind === "alarm" && a !== null)
            what === "done" ? Diver.done(a.id) : Diver.snooze(a.id, 10);
        else if (kind === "volume")
            Audio.toggleMute();
        else if (kind === "privacy" || kind === "inuse")
            Privacy.set(kind === "inuse");
        else if (kind === "notification" && a !== null) {
            Notifications.dismiss(a.id);
            root.flash = null;
        }
    }

    function voice(a: var, what: string): void {
        if (a === null)
            return;
        if (what === "mute") {
            const nodes = root.captures.filter(x => a.ids.indexOf(x.id) >= 0 && x.audio !== null);
            const to = !nodes.every(x => x.audio.muted);
            for (const n of nodes)
                n.audio.muted = to;
            return;
        }
        const w = I.voiceWindow(Compositor.windows, a.app);
        if (w !== undefined) {
            root.close();
            root.hotScreen = "";
            Compositor.activate(w);
        }
    }

    function chat(a: var, what: string): void {
        if (what === "cancel" || a === null || Notifications.entry(a.id) === null) {
            root.replyTo = -1;
            if (a !== null && root.flash !== null && root.flash.id === a.id && what !== "cancel")
                root.flash = null;
            return;
        }
        if (what === "reply") {
            root.replyTo = a.id;
            root.pinned = root.hotScreen !== "" ? root.hotScreen : root.focusedName;
            return;
        }
        if (what.indexOf("send:") === 0) {
            const text = what.slice(5).trim();
            if (text !== "" && a.inline)
                Notifications.entry(a.id).n.sendInlineReply(text);
            else if (text !== "") {
                Notifications.invoke(a.id, "default");
                Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wtype -s 700 -k Shift_L - -k Return", "sh", text]);
            }
            root.replyTo = -1;
            root.flash = null;
            root.pinned = "";
            return;
        }
        const action = ({
                accept: a.accept,
                decline: a.decline,
                read: a.read,
                openapp: "default"
            })[what];
        if (action !== undefined && action !== "")
            Notifications.invoke(a.id, action);
        else
            Notifications.dismiss(a.id);
        if (a.kind === "message")
            root.flash = null;
    }

    function state(): var {
        return {
            expanded: root.expanded,
            reveal: root.cfg.reveal,
            covered: root.covered,
            docked: root.docked,
            calling: I.inCall(root.cfg, {
                call: root.call,
                voice: root.session
            }),
            replying: root.replyTo >= 0,
            position: root.cfg.position,
            screen: root.screenInfo ? root.screenInfo.name : "",
            screens: root.cfg.screens,
            shortcuts: root.shortcutsOf(root.cfg.shortcuts).map(s => s.id),
            items: root.items.map(a => ({
                        kind: a.kind,
                        label: I.label(a)
                    }))
        };
    }

    function syncVoice(): void {
        const t = Date.now();
        const next = I.nextSession(root.session, root.voiceNow, t);
        if (JSON.stringify(next) === JSON.stringify(root.session))
            return;
        if (root.session === null && next !== null)
            root.now = t;
        root.session = next;
    }

    onVoiceNowChanged: root.syncVoice()

    PwObjectTracker {
        objects: root.captures.concat(root.feeds.map(g => g.source))
    }

    onFlashChanged: {
        if (root.replyTo >= 0 && (root.flash === null || root.flash.id !== root.replyTo))
            root.replyTo = -1;
    }

    Timer {
        id: enterTimer
        interval: 90
        onTriggered: root.hotScreen = root.pendingScreen
    }

    Timer {
        id: leaveTimer
        interval: 320
        onTriggered: root.hotScreen = ""
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: {
            root.devicesBefore = BluetoothService.items;
            root.lastNote = Notifications.list.length > 0 ? Notifications.list[0].id : -1;
            root.netAnnounced = root.netName;
            root.armed = true;
        }
    }

    Timer {
        id: flashTimer
        interval: (root.cfg.seconds + (root.flash !== null && root.flash.kind === "message" ? 5 : 0)) * 1000
        onTriggered: {
            if (root.hovered || root.replyTo >= 0)
                flashTimer.restart();
            else
                root.flash = null;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording || root.session !== null || root.cfg.diver && (Diver.focusEnd > root.now || Diver.next !== null)
        onTriggered: {
            root.now = Date.now();
            if (root.session !== null)
                root.syncVoice();
        }
    }

    Timer {
        interval: 10000
        repeat: true
        triggeredOnStart: true
        running: root.cfg.idle === "clock"
        onTriggered: root.time = Qt.formatTime(new Date(), "HH:mm")
    }

    Timer {
        interval: 1000
        repeat: true
        running: Media.playing && (root.expanded || root.items.some(a => a.kind === "media"))
        onTriggered: Media.tick()
    }

    Connections {
        target: Audio
        enabled: root.armed

        function onVolumeChanged() {
            root.show({
                kind: "volume",
                value: Audio.volume,
                muted: Audio.muted
            });
        }

        function onMutedChanged() {
            root.show({
                kind: "volume",
                value: Audio.volume,
                muted: Audio.muted
            });
        }
    }

    Connections {
        target: Notifications
        enabled: root.armed

        function onListChanged() {
            if (root.flash !== null && (root.flash.kind === "message" || root.flash.kind === "notification") && Notifications.entry(root.flash.id) === null)
                root.flash = null;
            const e = Notifications.list.length > 0 ? Notifications.list[0] : null;
            if (e === null || e.id === root.lastNote)
                return;
            root.lastNote = e.id;
            if (Notifications.centerOpen || Notifications.dnd && e.n.urgency !== NotificationUrgency.Critical)
                return;
            const f = Notifications.facts(e.n);
            if (I.isCall(f))
                return;
            if (root.cfg.messages && I.chatOf(f) !== null) {
                root.show(root.chatItem(e, f, "message"));
                return;
            }
            if (!root.cfg.notifications)
                return;
            root.show({
                kind: "notification",
                id: e.id,
                app: e.n.appName,
                summary: e.n.summary,
                body: N.plainText(e.n.body)
            });
        }
    }

    Connections {
        target: Privacy
        enabled: root.armed

        function onActiveChanged() {
            root.show(I.status("privacy", Privacy.active));
        }
    }

    Connections {
        target: Dnd
        enabled: root.armed

        function onEnabledChanged() {
            root.show(I.status("dnd", Dnd.enabled));
        }
    }

    Connections {
        target: NightLight
        enabled: root.armed

        function onEnabledChanged() {
            root.show(I.status("night", NightLight.enabled));
        }
    }

    Connections {
        target: NetworkService
        enabled: root.armed

        function onEnabledChanged() {
            root.show(I.status("wifi", NetworkService.enabled));
        }
    }

    onPerformanceChanged: {
        if (root.armed)
            root.show(I.status("performance", root.performance));
    }
    onNetNameChanged: netTimer.restart()

    Timer {
        id: netTimer
        interval: 2000
        onTriggered: {
            if (!root.armed || root.netName === root.netAnnounced) {
                root.netAnnounced = root.netName;
                return;
            }
            if (root.netName !== "")
                root.show(I.status("network", true, root.netName));
            else if (NetworkService.enabled)
                root.show(I.status("network", false, root.netAnnounced));
            root.netAnnounced = root.netName;
        }
    }

    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: root.cfg.privacy && !Demo.enabled && !Privacy.active
        onTriggered: {
            if (!usersProc.running)
                usersProc.running = true;
        }
        onRunningChanged: {
            if (!running)
                root.cameraUsers = [];
        }
    }

    Process {
        id: usersProc
        command: P.cameraUsersArgs("")
        stdout: StdioCollector {
            onStreamFinished: root.cameraUsers = P.parseUsers(text)
        }
    }

    Connections {
        target: BluetoothService
        enabled: root.armed

        function onEnabledChanged() {
            root.show(I.status("bluetooth", BluetoothService.enabled));
        }

        function onItemsChanged() {
            const d = I.joined(root.devicesBefore, BluetoothService.items);
            root.devicesBefore = BluetoothService.items;
            if (d !== null)
                root.show({
                    kind: "device",
                    name: d.name,
                    battery: d.battery,
                    audio: d.audio
                });
        }
    }

    Variants {
        model: root.cfg.screens === "all" ? Quickshell.screens : root.screenInfo !== null ? [root.screenInfo] : []

        PanelWindow {
            id: win

            required property var modelData
            readonly property string name: win.modelData.name
            readonly property var wcfg: Settings.at(win.name).island
            readonly property var place: I.placeOf(win.wcfg.position)
            readonly property bool covered: root.avoid !== null && !root.avoid.docked && root.avoid.corner === win.wcfg.position && root.avoid.screen === win.name
            readonly property bool docked: root.avoid !== null && root.avoid.docked === true && root.avoid.corner === win.wcfg.position && root.avoid.screen === win.name
            readonly property bool calling: I.inCall(win.wcfg, {
                call: root.call,
                voice: root.session
            })
            readonly property bool edge: win.wcfg.reveal === "hover"
            readonly property real inset: win.edge ? Tokens.edgeMargin : 0
            readonly property bool hovering: bodyHover.hovered || stripArea.containsMouse
            readonly property bool tucked: I.tucked(win.wcfg.reveal, {
                hot: root.hotScreen === win.name,
                pinned: root.pinned === win.name,
                alert: root.call !== null || root.flash !== null || win.docked || win.calling
            })
            property real reveal: win.tucked ? 0 : 1
            readonly property bool onSurface: body.visible && body.y + body.height > 1 && body.y < win.height - 1

            Behavior on reveal {
                NumberAnimation {
                    duration: Math.round((win.tucked ? 300 : 460) * Tokens.pace)
                    easing.type: win.tucked ? Easing.InOutCubic : Easing.OutQuint
                }
            }

            onHoveringChanged: root.hover(win.name, win.hovering)

            visible: body.shown && !win.covered
            screen: win.modelData
            anchors.top: win.place.top
            anchors.bottom: !win.place.top
            anchors.left: win.place.side === "left"
            anchors.right: win.place.side === "right"
            margins.top: win.edge ? 0 : Tokens.edgeMargin
            margins.bottom: win.edge ? 0 : Tokens.edgeMargin
            margins.left: Tokens.edgeMargin
            margins.right: Tokens.edgeMargin
            implicitWidth: body.cardWidth + body.pillHeight + 16
            implicitHeight: 540
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0
            WlrLayershell.layer: win.docked || win.calling ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.namespace: "sylisland"
            WlrLayershell.keyboardFocus: root.replyTo >= 0 && root.pinned === win.name ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            mask: Region {
                item: win.edge ? strip : body

                Region {
                    item: win.edge ? body : null
                }
            }
            BackgroundEffect.blurRegion: Resin.enabled && win.onSurface ? blur : null

            Region {
                id: blur

                Region {
                    item: body.pill
                    radius: Math.min(body.pill.height / 2, Tokens.radiusPanel)
                }

                Region {
                    item: body.bubble ? body.side : null
                    radius: body.pillHeight / 2
                }
            }

            Item {
                id: strip
                z: 1
                visible: win.edge
                x: Math.max(0, Math.min(parent.width - width, body.x + (body.pill.width - width) / 2))
                y: win.place.top ? 0 : parent.height - height
                width: Math.max(body.pill.width, 120)
                height: win.inset + 2

                MouseArea {
                    id: stripArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: win.place.top ? 2 : parent.height - height - 2
                    width: stripArea.containsMouse ? 72 : 48
                    height: 4
                    radius: 2
                    color: root.items.length > 0 ? Theme.accent : Qt.alpha(Theme.text, 0.5)
                    opacity: (1 - win.reveal) * 0.85

                    Behavior on width {
                        NumberAnimation {
                            duration: Tokens.stateDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            IslandBody {
                id: body
                x: win.place.side === "left" ? 0 : win.place.side === "right" ? parent.width - width : (parent.width - body.pill.width) / 2
                y: Math.round(win.place.top ? win.inset - (1 - win.reveal) * (height + win.inset + 4) : parent.height - height - win.inset + (1 - win.reveal) * (height + win.inset + 4))
                items: root.items
                shortcuts: root.shortcutsOf(win.wcfg.shortcuts)
                expanded: win.docked || root.pinned === win.name || root.cfg.hover && root.hotScreen === win.name
                atTop: win.place.top
                idle: win.wcfg.idle
                time: root.time
                replying: root.pinned === win.name ? root.replyTo : -1
                progress: Media.length > 0 ? Media.position / Media.length : 0
                position: Media.position
                length: Media.length
                unread: Notifications.count
                quiet: Notifications.dnd
                onAct: (kind, what) => root.act(kind, what)
                onRun: id => root.runShortcut(id)
                onPin: root.pin(win.name)
                onWheel: steps => Audio.setVolume(Audio.volume + steps * 0.05)

                HoverHandler {
                    id: bodyHover
                }
            }
        }
    }
}
