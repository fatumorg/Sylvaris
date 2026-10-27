pragma Singleton

import QtQuick
import SylStack

Singleton {
    id: root

    readonly property bool demo: Demo.enabled
    property bool demoPlaying: Demo.player.playing
    property real demoPosition: 74
    property string chosen: ""
    readonly property var players: root.demo ? [] : Mpris.players.values
    readonly property var player: root.demo ? null : root.pick(root.players)
    readonly property bool available: root.demo || root.player !== null
    readonly property string title: root.demo ? Demo.player.title : (root.player !== null ? root.player.trackTitle : "")
    readonly property string artist: root.demo ? Demo.player.artist : (root.player !== null ? root.player.trackArtist : "")
    readonly property string album: root.demo ? "Example Album" : (root.player !== null ? root.player.trackAlbum : "")
    readonly property string art: root.demo ? Demo.player.art : (root.player !== null ? root.player.trackArtUrl : "")
    readonly property string url: root.player !== null && root.player.metadata ? String(root.player.metadata["xesam:url"] || "") : ""
    readonly property string identity: root.demo ? Demo.player.identity : (root.player !== null ? root.player.identity : "")
    readonly property bool playing: root.demo ? root.demoPlaying : (root.player !== null && root.player.isPlaying)
    readonly property real length: root.demo ? 212 : (root.player !== null && root.player.lengthSupported ? root.player.length : 0)
    readonly property real position: root.demo ? root.demoPosition : (root.player !== null && root.player.positionSupported ? root.player.position : 0)
    readonly property bool canSeek: root.demo || (root.player !== null && root.player.canSeek && root.length > 0)
    readonly property bool shuffle: root.player !== null && root.player.shuffleSupported && root.player.shuffle
    readonly property bool shuffleSupported: root.player !== null && root.player.shuffleSupported
    readonly property bool loopSupported: root.player !== null && root.player.loopSupported
    readonly property int loopState: root.player !== null && root.player.loopSupported ? root.player.loopState : MprisLoopState.None
    readonly property bool volumeSupported: root.player !== null && root.player.volumeSupported
    readonly property real volume: root.volumeSupported ? root.player.volume : 1

    function pick(list: var): var {
        for (const p of list) {
            if (p.dbusName === root.chosen)
                return p;
        }
        for (const p of list) {
            if (p.isPlaying)
                return p;
        }
        return list.length > 0 ? list[0] : null;
    }

    function choose(p: var): void {
        root.chosen = p ? p.dbusName : "";
    }

    function toggle(): void {
        if (root.demo)
            root.demoPlaying = !root.demoPlaying;
        else if (root.player !== null && root.player.canTogglePlaying)
            root.player.togglePlaying();
    }

    function next(): void {
        if (!root.demo && root.player !== null && root.player.canGoNext)
            root.player.next();
    }

    function previous(): void {
        if (!root.demo && root.player !== null && root.player.canGoPrevious)
            root.player.previous();
    }

    function seekTo(seconds: real): void {
        const s = Math.max(0, Math.min(root.length, seconds));
        if (root.demo)
            root.demoPosition = s;
        else if (root.canSeek)
            root.player.position = s;
    }

    function setShuffle(v: bool): void {
        if (root.shuffleSupported)
            root.player.shuffle = v;
    }

    function cycleLoop(): void {
        if (!root.loopSupported)
            return;
        root.player.loopState = root.loopState === MprisLoopState.None ? MprisLoopState.Playlist : root.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
    }

    function setVolume(v: real): void {
        if (root.volumeSupported)
            root.player.volume = Math.max(0, Math.min(1, v));
    }

    function raise(): void {
        if (root.player !== null && root.player.canRaise)
            root.player.raise();
    }

    function tick(): void {
        if (root.player !== null && root.player.positionSupported)
            root.player.positionChanged();
    }

    function state(): var {
        return {
            available: root.available,
            player: root.identity,
            players: root.players.map(p => p.identity),
            title: root.title,
            artist: root.artist,
            album: root.album,
            playing: root.playing,
            position: Math.round(root.position),
            length: Math.round(root.length)
        };
    }
}
