import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { bluezCardName, parseCards, profileKind, profileLabel, cardProfile, streamName, appStreams, withIdle } from "../shell/lib/audio.mjs"

const cards = parseCards(readFileSync(new URL("./fixtures/pactl-cards.json", import.meta.url), "utf8"))

test("bluezCardName upper-cases and underscores the address", () => {
    assert.equal(bluezCardName("74:3f:8e:90:8e:4b"), "bluez_card.74_3F_8E_90_8E_4B")
})

test("parseCards returns an empty list for bad input", () => {
    assert.deepEqual(parseCards("nope"), [])
    assert.deepEqual(parseCards("{}"), [])
    assert.equal(cards.length, 3)
})

test("profileKind and profileLabel classify profiles", () => {
    assert.equal(profileKind("a2dp-sink-sbc"), "hifi")
    assert.equal(profileKind("headset-head-unit"), "headset")
    assert.equal(profileKind("off"), "off")
    assert.equal(profileLabel("hifi"), "Hi-Fi (A2DP)")
    assert.equal(profileLabel("headset"), "Headset (HFP)")
    assert.equal(profileLabel("off"), "Off")
})

test("cardProfile proposes the headset profile from hi-fi", () => {
    assert.deepEqual(cardProfile(cards, "00:11:22:33:44:01"), {
        card: "bluez_card.00_11_22_33_44_01",
        active: "a2dp-sink",
        kind: "hifi",
        label: "Hi-Fi (A2DP)",
        next: "headset-head-unit"
    })
})

test("cardProfile skips unavailable profiles", () => {
    const p = cardProfile(cards, "00:11:22:33:44:05")
    assert.equal(p.kind, "headset")
    assert.equal(p.next, "a2dp-sink-sbc")
})

test("cardProfile returns null for unknown devices", () => {
    assert.equal(cardProfile(cards, "AA:BB:CC:DD:EE:FF"), null)
})

test("streamName unwraps ALSA and Nix wrapper names and falls back when empty", () => {
    assert.equal(streamName("Firefox", "x"), "Firefox")
    assert.equal(streamName("PipeWire ALSA [.aplay-wrapped]", "x"), "aplay")
    assert.equal(streamName("PipeWire ALSA [hl2_linux]", "x"), "hl2_linux")
    assert.equal(streamName(".game-wrapped", "x"), "game")
    assert.equal(streamName("", "pw-play"), "pw-play")
    assert.equal(streamName(undefined, "alsa_playback.x"), "alsa_playback.x")
})

const node = (id, cls, props, extra) => Object.assign({ id: id, cls: cls, name: props["node.name"] || "", props: props, volume: 0.5, muted: false }, extra)

test("appStreams lists playing and recording apps with their title and device, like pavucontrol", () => {
    const nodes = [
        node(1, "Stream/Output/Audio", { "application.name": "Firefox", "application.process.binary": "firefox", "media.name": "Song - YouTube" }),
        node(2, "Stream/Input/Audio", { "application.name": "WEBRTC VoiceEngine", "application.process.binary": "Discord", "media.name": "recStream" }),
        node(3, "Stream/Output/Audio", { "node.name": "sylvaris_eq_out", "media.name": "Sylvaris Equalizer" }),
        node(4, "Stream/Input/Audio/Internal", { "node.name": "bluez_capture_internal.x" }),
        node(5, "Audio/Sink", { "node.name": "alsa_output.x" }),
        node(6, "Stream/Output/Audio", { "application.process.binary": "hl2_linux", "node.name": "alsa_playback.hl2", "media.name": "ALSA Playback" }, { volume: 0.2, muted: true }),
        node(7, "Stream/Output/Audio", { "application.name": "Spotify", "application.process.binary": "spotify", "media.name": "Spotify" })
    ]
    const links = [{ source: 1, target: 5 }, { source: 9, target: 2 }]
    assert.deepEqual(appStreams(nodes, links), [
        { key: "1", kind: "play", app: "Firefox", title: "Song - YouTube", volume: 0.5, muted: false, device: 5, live: true },
        { key: "2", kind: "record", app: "Discord", title: "recStream", volume: 0.5, muted: false, device: 9, live: true },
        { key: "6", kind: "play", app: "Hl2_linux", title: "ALSA Playback", volume: 0.2, muted: true, device: null, live: true },
        { key: "7", kind: "play", app: "Spotify", title: "", volume: 0.5, muted: false, device: null, live: true }
    ])
})

test("appStreams falls back to the stream's own name instead of hiding an app", () => {
    const got = appStreams([node(1, "Stream/Output/Audio", { "application.name": "sylstack", "application.process.binary": ".sylstack-wrapped", "node.name": "x" })], [])
    assert.equal(got[0].app, "sylstack")
})

test("withIdle keeps closed apps with their last volume after the live ones", () => {
    const live = [{ key: "1", kind: "play", app: "Firefox", title: "t", volume: 0.5, muted: false, device: 5, live: true }]
    const first = withIdle(live, {})
    assert.deepEqual(first.rows, live)
    const later = withIdle([], first.seen)
    assert.deepEqual(later.rows, [{ key: "play:Firefox", kind: "play", app: "Firefox", title: "", volume: 0.5, muted: false, device: null, live: false }])
    const back = withIdle([Object.assign({}, live[0], { key: "8", volume: 0.9 })], later.seen)
    assert.deepEqual(back.rows.map(r => r.key), ["8"])
    assert.equal(back.seen["play:Firefox"].volume, 0.9)
})
