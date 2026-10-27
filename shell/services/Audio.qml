pragma Singleton

import QtQuick
import SylStack
import "../lib/audio.mjs" as AudioLib

Singleton {
    id: root

    readonly property bool demo: Demo.enabled
    property real demoVolume: 0.62
    property bool demoMuted: false
    property string demoDefault: "1"
    property var demoStreamLevels: ({})
    readonly property var sink: root.demo ? null : Pipewire.defaultAudioSink
    readonly property bool available: root.demo || (Pipewire.ready && root.sink !== null)
    readonly property real volume: root.demo ? root.demoVolume : (root.sink !== null && root.sink.audio ? root.sink.audio.volume : 0)
    readonly property bool muted: root.demo ? root.demoMuted : (root.sink !== null && root.sink.audio ? root.sink.audio.muted : false)
    readonly property var sinks: root.demo ? root.demoSinks() : root.realSinks()
    readonly property var sources: root.demo ? [] : root.realSources()
    readonly property var links: root.demo ? [] : Pipewire.linkGroups.values.filter(g => g.source && g.target).map(g => ({
                source: g.source.id,
                target: g.target.id
            }))
    readonly property var liveStreams: root.demo ? Demo.streams.map(s => {
        const l = root.demoStreamLevels[s.id] || {};
        return {
            key: String(s.id),
            kind: "play",
            app: s.app,
            title: "",
            volume: l.volume === undefined ? s.volume : l.volume,
            muted: l.muted === true,
            device: null,
            live: true
        };
    }) : AudioLib.appStreams(Pipewire.nodes.values.filter(n => n.isStream && n.audio).map(n => ({
                id: n.id,
                cls: n.mediaClass,
                name: n.name,
                props: n.properties,
                volume: n.audio.volume,
                muted: n.audio.muted
            })), root.links)
    property var seenApps: ({})
    property var pendingApps: ({})
    readonly property var streams: AudioLib.withIdle(root.liveStreams, root.seenApps).rows
    readonly property var streamKeys: root.streams.map(s => s.key)
    readonly property bool eqActive: !root.demo && root.sink !== null && root.sink.name === "sylvaris_eq"
    readonly property string eqOutput: {
        if (!root.eqActive)
            return "";
        if (Equalizer.target !== "")
            return Equalizer.target;
        const out = Equalizer.outNode === null ? undefined : root.links.find(l => l.source === Equalizer.outNode.id);
        const n = out === undefined ? null : root.nodeById(String(out.target));
        return n === null ? "" : n.name;
    }
    readonly property string outputName: {
        for (const s of root.sinks) {
            if (s.current)
                return s.name;
        }
        return "";
    }

    function nodeName(n: var): string {
        return n.description || n.nickname || n.name;
    }

    function demoSinks(): var {
        return Demo.sinks.map(s => ({
                    key: String(s.id),
                    name: s.description,
                    current: String(s.id) === root.demoDefault
                }));
    }

    function realSinks(): var {
        const out = [];
        for (const n of Pipewire.nodes.values) {
            if (n.isSink && !n.isStream && n.audio && n.name.indexOf("sylvaris_eq") !== 0)
                out.push({
                    key: String(n.id),
                    name: root.nodeName(n),
                    current: root.eqActive ? n.name === root.eqOutput : root.sink !== null && n.id === root.sink.id
                });
        }
        return out;
    }

    function realSources(): var {
        return Pipewire.nodes.values.filter(n => n.mediaClass === "Audio/Source" && n.audio).map(n => ({
                    key: String(n.id),
                    name: root.nodeName(n)
                }));
    }

    function nodeById(key: string): var {
        for (const n of Pipewire.nodes.values) {
            if (String(n.id) === key)
                return n;
        }
        return null;
    }

    function deviceName(id: var): string {
        const n = id === null ? null : root.nodeById(String(id));
        if (n === null)
            return "";
        return n.name === "sylvaris_eq" ? "Equalizer" : n.nickname || root.nodeName(n);
    }

    function cycleDevice(key: string): void {
        const s = root.streams.find(x => x.key === key);
        if (root.demo || s === undefined || !s.live)
            return;
        const options = s.kind === "play" ? (Equalizer.node !== null ? [String(Equalizer.node.id)] : []).concat(root.sinks.map(x => x.key)) : root.sources.map(x => x.key);
        if (options.length === 0)
            return;
        const n = root.nodeById(options[(options.indexOf(String(s.device)) + 1) % options.length]);
        if (n !== null)
            Stack.execDetached(["pw-metadata", key, "target.object", n.name]);
    }

    function setIdle(key: string, patch: var): void {
        if (root.seenApps[key] === undefined)
            return;
        const seen = Object.assign({}, root.seenApps);
        seen[key] = Object.assign({}, seen[key], patch);
        root.seenApps = seen;
        const pending = Object.assign({}, root.pendingApps);
        pending[key] = Object.assign({}, pending[key], patch);
        root.pendingApps = pending;
    }

    function setVolume(v: real): void {
        const c = Math.max(0, Math.min(1, v));
        if (root.demo)
            root.demoVolume = c;
        else if (root.sink !== null && root.sink.audio)
            root.sink.audio.volume = c;
    }

    function toggleMute(): void {
        if (root.demo)
            root.demoMuted = !root.demoMuted;
        else if (root.sink !== null && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    function setStreamVolume(key: string, v: real): void {
        const c = Math.max(0, Math.min(1, v));
        if (root.demo) {
            const next = Object.assign({}, root.demoStreamLevels);
            next[key] = Object.assign({}, next[key], {
                volume: c
            });
            root.demoStreamLevels = next;
            return;
        }
        const n = root.nodeById(key);
        if (n !== null && n.audio)
            n.audio.volume = c;
        else
            root.setIdle(key, {
                volume: c
            });
    }

    function toggleStreamMute(key: string): void {
        if (root.demo) {
            const next = Object.assign({}, root.demoStreamLevels);
            next[key] = Object.assign({}, next[key], {
                muted: !(next[key] && next[key].muted)
            });
            root.demoStreamLevels = next;
            return;
        }
        const n = root.nodeById(key);
        if (n !== null && n.audio)
            n.audio.muted = !n.audio.muted;
        else if (root.seenApps[key] !== undefined)
            root.setIdle(key, {
                muted: !root.seenApps[key].muted
            });
    }

    onLiveStreamsChanged: {
        root.seenApps = AudioLib.withIdle(root.liveStreams, root.seenApps).seen;
        for (const s of root.liveStreams) {
            const id = s.kind + ":" + s.app;
            const want = root.pendingApps[id];
            if (want === undefined)
                continue;
            const pending = Object.assign({}, root.pendingApps);
            delete pending[id];
            root.pendingApps = pending;
            if (want.volume !== undefined)
                root.setStreamVolume(s.key, want.volume);
            if (want.muted !== undefined && want.muted !== s.muted)
                root.toggleStreamMute(s.key);
        }
    }

    function setDefault(key: string): void {
        if (root.demo) {
            root.demoDefault = key;
            return;
        }
        for (const n of Pipewire.nodes.values) {
            if (String(n.id) !== key)
                continue;
            if (Equalizer.enabled)
                Equalizer.retarget(n.name);
            else
                Pipewire.preferredDefaultAudioSink = n;
        }
    }

    PwObjectTracker {
        objects: root.demo || root.sink === null ? [] : [root.sink]
    }

    PwObjectTracker {
        objects: root.demo ? [] : Pipewire.nodes.values.filter(n => n.isStream)
    }
}
