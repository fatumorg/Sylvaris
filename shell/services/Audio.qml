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
    readonly property var streamNodes: root.demo ? [] : Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio && n.name.indexOf("sylvaris_eq") !== 0)
    readonly property var streamKeys: root.demo ? Demo.streams.map(s => String(s.id)) : root.streamNodes.map(n => String(n.id))
    readonly property var streams: root.demo ? Demo.streams.map(s => {
        const l = root.demoStreamLevels[s.id] || {};
        return {
            key: String(s.id),
            name: s.app,
            volume: l.volume === undefined ? s.volume : l.volume,
            muted: l.muted === true
        };
    }) : root.streamNodes.map(n => ({
                key: String(n.id),
                name: AudioLib.streamName(n.properties["application.name"], root.nodeName(n)),
                volume: n.audio.volume,
                muted: n.audio.muted
            }))
    readonly property bool eqActive: !root.demo && root.sink !== null && root.sink.name === "sylvaris_eq"
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
                    current: root.eqActive ? n.name === Equalizer.target : root.sink !== null && n.id === root.sink.id
                });
        }
        return out;
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
        for (const n of root.streamNodes) {
            if (String(n.id) === key)
                n.audio.volume = c;
        }
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
        for (const n of root.streamNodes) {
            if (String(n.id) === key)
                n.audio.muted = !n.audio.muted;
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
        objects: root.demo ? [] : Pipewire.nodes.values.filter(n => n.isStream && n.isSink)
    }
}
