import { test } from "node:test"
import assert from "node:assert/strict"
import { DEFAULT_ISLAND, validateIsland, activities, label, joined, custom, SHORTCUTS, shortcutsFor, placeOf, cardHeight, CHAT_APPS, chatOf, isCall, pickActions, takes, hiddenSite, voiceOf, tucked, inUse, status, inCall, ownerOf, nodeKind, streamsOf, nextSession, VOICE_GRACE, voiceWindow, ownsFocus } from "../shell/lib/island.mjs"

const idle = { flash: null, recording: { on: false }, alarm: null, focus: null, next: null, media: { title: "", playing: false } }

test("validateIsland keeps booleans and bounds the flash seconds", () => {
    assert.deepEqual(validateIsland(null), DEFAULT_ISLAND)
    const v = validateIsland({ media: false, notifications: true, seconds: 7, hover: "yes", extra: 1 })
    assert.equal(v.media, false)
    assert.equal(v.notifications, true)
    assert.equal(v.seconds, 7)
    assert.equal(v.hover, true)
    assert.equal(v.extra, 1)
    assert.equal(validateIsland({ seconds: 0 }).seconds, DEFAULT_ISLAND.seconds)
    assert.equal(validateIsland({ seconds: 2.5 }).seconds, DEFAULT_ISLAND.seconds)
    assert.equal(validateIsland({ seconds: 11 }).seconds, DEFAULT_ISLAND.seconds)
})

test("nothing going on means no activity", () => {
    assert.deepEqual(activities(idle, DEFAULT_ISLAND), [])
    assert.deepEqual(activities({}, DEFAULT_ISLAND), [])
})

test("activities come in priority order: flash, recording, alarm, focus, next, media", () => {
    const s = {
        flash: { kind: "volume", value: 0.4, muted: false },
        recording: { on: true, started: true, elapsed: 65000 },
        alarm: { text: "Stand-up" },
        focus: { title: "Write", left: 90000 },
        next: { text: "Lunch", mins: 12 },
        media: { title: "Song", artist: "Band", playing: true }
    }
    assert.deepEqual(activities(s, DEFAULT_ISLAND).map(a => a.kind), ["volume", "recording", "alarm", "focus", "next", "media"])
})

test("switches in the settings drop their activities", () => {
    const s = {
        flash: { kind: "notification", summary: "Hi" },
        recording: { on: true, started: true, elapsed: 1000 },
        alarm: { text: "A" },
        media: { title: "Song", playing: true }
    }
    const cfg = Object.assign({}, DEFAULT_ISLAND, { recording: false, diver: false, media: false })
    assert.deepEqual(activities(s, cfg), [])
    assert.deepEqual(activities(s, Object.assign({}, cfg, { notifications: true })).map(a => a.kind), ["notification"])
    assert.deepEqual(activities({ flash: { kind: "volume", value: 1 } }, Object.assign({}, DEFAULT_ISLAND, { volume: false })), [])
    assert.deepEqual(activities({ flash: { kind: "device", name: "Buds" } }, Object.assign({}, DEFAULT_ISLAND, { devices: false })), [])
})

test("far tasks, an unknown flash and, when asked, paused media stay out", () => {
    const s = { flash: { kind: "nope" }, next: { text: "Later", mins: 40 }, media: { title: "Song", playing: false } }
    assert.deepEqual(activities(s, Object.assign({}, DEFAULT_ISLAND, { keepPaused: false })), [])
    assert.deepEqual(activities(s, DEFAULT_ISLAND).map(a => a.kind), ["media"])
    assert.deepEqual(activities({ media: { title: "", artist: "", playing: false } }, DEFAULT_ISLAND), [])
    assert.equal(validateIsland({}).keepPaused, true)
    assert.deepEqual(activities({ next: { text: "Soon", mins: 15 } }, DEFAULT_ISLAND).map(a => a.kind), ["next"])
})

test("label gives the short compact text", () => {
    assert.equal(label({ kind: "volume", value: 0.456, muted: false }), "46%")
    assert.equal(label({ kind: "volume", value: 0.4, muted: true }), "Muted")
    assert.equal(label({ kind: "notification", app: "Mail", summary: "" }), "Mail")
    assert.equal(label({ kind: "notification", app: "Mail", summary: "New mail" }), "New mail")
    assert.equal(label({ kind: "device", name: "Buds", battery: 80 }), "Buds · 80%")
    assert.equal(label({ kind: "device", name: "Mouse", battery: -1 }), "Mouse")
    assert.equal(label({ kind: "recording", started: true, elapsed: 65000 }), "1:05")
    assert.equal(label({ kind: "recording", started: false, wait: 2100 }), "Starts in 3")
    assert.equal(label({ kind: "alarm", title: "Stand-up" }), "Stand-up")
    assert.equal(label({ kind: "focus", title: "Write", left: 3723000 }), "1:02:03")
    assert.equal(label({ kind: "next", text: "Lunch", mins: 0 }), "now")
    assert.equal(label({ kind: "next", text: "Lunch", mins: 7 }), "in 7m")
    assert.equal(label({ kind: "media", title: "Song", artist: "Band" }), "Song")
    assert.equal(label({ kind: "media", title: "", artist: "Band" }), "Band")
})

test("joined finds the device that just connected", () => {
    const before = [{ key: "a", connected: true }, { key: "b", connected: false }]
    const after = [{ key: "a", connected: true }, { key: "b", name: "Buds", connected: true, battery: 70 }, { key: "c", connected: true }]
    assert.equal(joined(before, after).key, "b")
    assert.equal(joined(after, after), null)
    assert.equal(joined([], [{ key: "c", connected: false }]), null)
})

test("custom turns script text into a safe flash", () => {
    assert.deepEqual(custom("  Build   done "), { kind: "custom", text: "Build done" })
    assert.equal(custom("a\u0007b\nc").text, "a b c")
    assert.equal(custom("x".repeat(200)).text.length, 120)
    assert.equal(custom("   "), null)
    assert.equal(custom(undefined), null)
    assert.deepEqual(activities({ flash: custom("Hi") }, Object.assign({}, DEFAULT_ISLAND, { volume: false, notifications: false, devices: false })).map(a => a.kind), ["custom"])
    assert.equal(label(custom("Hi")), "Hi")
})

test("validateIsland checks position, idle and shortcuts", () => {
    const d = validateIsland({})
    assert.equal(d.position, "top-center")
    assert.equal(d.idle, "pill")
    assert.deepEqual(d.shortcuts, ["notify", "center", "media", "screenshot", "record", "dnd"])
    const v = validateIsland({ position: "bottom-left", idle: "clock", shortcuts: ["wifi", "nope", "wifi", "lock", 3] })
    assert.equal(v.position, "bottom-left")
    assert.equal(v.idle, "clock")
    assert.deepEqual(v.shortcuts, ["wifi", "lock"])
    assert.equal(validateIsland({ position: "middle" }).position, "top-center")
    assert.equal(validateIsland({ idle: "x" }).idle, "pill")
    assert.deepEqual(validateIsland({ shortcuts: "wifi" }).shortcuts, d.shortcuts)
    assert.equal(d.reveal, "always")
    assert.equal(validateIsland({ reveal: "hover" }).reveal, "hover")
    assert.equal(validateIsland({ reveal: "peek" }).reveal, "always")
    assert.deepEqual(validateIsland({ shortcuts: [] }).shortcuts, [])
    assert.equal(validateIsland({ shortcuts: Object.keys(SHORTCUTS) }).shortcuts.length, 8)
})

test("every shortcut runs a real command and names what it needs", () => {
    for (const [id, s] of Object.entries(SHORTCUTS)) {
        assert.ok(Array.isArray(s.run) && s.run.length >= 2, id)
        assert.equal(typeof s.label, "string", id)
        assert.equal(typeof s.glyph, "string", id)
        assert.equal(typeof s.needs, "string", id)
    }
})

test("shortcutsFor keeps the chosen ones whose part or service runs", () => {
    const got = shortcutsFor(["clip", "wifi", "notify"], ["notify", "NetworkService"])
    assert.deepEqual(got.map(s => s.id), ["wifi", "notify"])
    assert.deepEqual(got[0].run, ["wifi", "toggle"])
})

test("placeOf splits a position into edge and side", () => {
    assert.deepEqual(placeOf("top-center"), { top: true, side: "center" })
    assert.deepEqual(placeOf("bottom-right"), { top: false, side: "right" })
})

test("cardHeight stacks one row per activity and the shortcut row", () => {
    assert.equal(cardHeight([], false), 0)
    assert.equal(cardHeight([], true), 12 + 52 + 12)
    assert.equal(cardHeight(["recording"], false), 12 + 64 + 12)
    assert.equal(cardHeight(["recording", "media"], true), 12 + 64 + 6 + 108 + 6 + 52 + 12)
})

test("chatOf recognises messaging apps by name, desktop entry or website", () => {
    const n = (appName, extra) => Object.assign({ appName: appName, desktopEntry: "", summary: "Ana", body: "hi" }, extra)
    assert.equal(chatOf(n("Vesktop")).id, "discord")
    assert.equal(chatOf(n("", { desktopEntry: "dev.vencord.Vesktop" })).id, "discord")
    assert.equal(chatOf(n("Ferdium")).id, "ferdium")
    assert.equal(chatOf(n("Signal")).id, "signal")
    assert.equal(chatOf(n("", { desktopEntry: "org.telegram.desktop" })).id, "telegram")
    assert.equal(chatOf(n("AyuGram Desktop")).id, "telegram")
    assert.equal(chatOf(n("ZapZap")).id, "whatsapp")
    assert.equal(chatOf(n("KDE Connect")).id, "phone")
    assert.equal(chatOf(n("Thunderbird")).id, "mail")
    assert.equal(chatOf(n("Firefox", { body: "web.whatsapp.com\nhello" })).id, "whatsapp")
    assert.equal(chatOf(n("Chromium", { summary: "Mia", body: "messenger.com" })).id, "messenger")
    assert.equal(chatOf(n("Firefox", { body: "news.example.com" })), null)
    assert.equal(chatOf(n("Spotify")), null)
    for (const a of CHAT_APPS) {
        assert.equal(typeof a.label, "string", a.id)
        assert.equal(typeof a.glyph, "string", a.id)
    }
})

test("isCall spots calls by category or wording", () => {
    assert.equal(isCall({ summary: "Ana", body: "", category: "call.incoming" }), true)
    assert.equal(isCall({ summary: "Incoming video call", body: "Ana" }), true)
    assert.equal(isCall({ summary: "Ana", body: "is calling you" }), true)
    assert.equal(isCall({ summary: "Ana", body: "call me later" }), false)
    assert.equal(isCall({ summary: "Missed call", body: "Ana", category: "call.unanswered" }), false)
})

test("pickActions finds accept, decline and mark as read", () => {
    const acts = [{ identifier: "default", text: "" }, { identifier: "answer", text: "Answer" }, { identifier: "x", text: "Decline" }, { identifier: "mark", text: "Mark as read" }]
    assert.deepEqual(pickActions(acts), { accept: "answer", decline: "x", read: "mark" })
    assert.deepEqual(pickActions([]), { accept: "", decline: "", read: "" })
})

test("calls come first and messages obey their switches", () => {
    const s = { call: { app: "Signal", sender: "Ana" }, flash: { kind: "message", sender: "Mia", text: "yo" }, media: { title: "Song", playing: true } }
    assert.deepEqual(activities(s, DEFAULT_ISLAND).map(a => a.kind), ["call", "message", "media"])
    assert.deepEqual(activities(s, Object.assign({}, DEFAULT_ISLAND, { calls: false, messages: false })).map(a => a.kind), ["media"])
    assert.equal(label({ kind: "message", sender: "Mia", text: "yo" }), "Mia")
    assert.equal(label({ kind: "call", sender: "Ana" }), "Ana calling")
    assert.equal(validateIsland({ messages: false }).messages, false)
    assert.equal(validateIsland({}).calls, true)
})

test("takes decides which toasts the island shows instead", () => {
    const msg = { appName: "Signal", summary: "Ana", body: "hi" }
    const call = { appName: "Telegram", summary: "Incoming call", body: "Ana" }
    const other = { appName: "Updater", summary: "Done", body: "" }
    assert.equal(takes(msg, DEFAULT_ISLAND, false), true)
    assert.equal(takes(msg, DEFAULT_ISLAND, true), false)
    assert.equal(takes(call, DEFAULT_ISLAND, true), true)
    assert.equal(takes(other, DEFAULT_ISLAND, false), false)
    assert.equal(takes(other, Object.assign({}, DEFAULT_ISLAND, { notifications: true }), false), true)
    assert.equal(takes(msg, Object.assign({}, DEFAULT_ISLAND, { messages: false }), false), false)
    assert.equal(takes(call, Object.assign({}, DEFAULT_ISLAND, { calls: false }), true), false)
})

test("hiddenSite matches a media url against the hidden sites", () => {
    const sites = DEFAULT_ISLAND.hideSites
    assert.equal(hiddenSite("https://www.youtube.com/watch?v=IquV1WL2sbo", sites), true)
    assert.equal(hiddenSite("https://youtu.be/abc", sites), true)
    assert.equal(hiddenSite("https://m.youtube.com/watch?v=1", sites), true)
    assert.equal(hiddenSite("https://music.youtube.com/watch?v=1", sites), false)
    assert.equal(hiddenSite("https://notyoutube.com/x", sites), false)
    assert.equal(hiddenSite("", sites), false)
    assert.equal(hiddenSite("file:///song.mp3", sites), false)
    assert.equal(hiddenSite("https://www.twitch.tv/x", ["twitch.tv"]), true)
})

test("validateIsland checks screens mode and hidden sites", () => {
    assert.equal(validateIsland({}).screens, "focused")
    assert.equal(validateIsland({ screens: "all" }).screens, "all")
    assert.equal(validateIsland({ screens: "x" }).screens, "focused")
    assert.deepEqual(validateIsland({ hideSites: [" Twitch.TV ", "bad site", "twitch.tv", 3, "https://x.com/a"] }).hideSites, ["twitch.tv", "x.com"])
    assert.deepEqual(validateIsland({ hideSites: "x" }).hideSites, DEFAULT_ISLAND.hideSites)
    assert.deepEqual(validateIsland({ hideSites: [] }).hideSites, [])
})

test("media from a hidden site stays out of the island", () => {
    const s = { media: { title: "Video", playing: true, url: "https://www.youtube.com/watch?v=1" } }
    assert.deepEqual(activities(s, DEFAULT_ISLAND), [])
    assert.deepEqual(activities(s, Object.assign({}, DEFAULT_ISLAND, { hideSites: [] })).map(a => a.kind), ["media"])
})

test("ownerOf names the app behind a stream and drops audio plumbing", () => {
    const o = props => ownerOf(props).name
    assert.equal(o({ "application.name": "gsr-combined-77", "application.process.binary": "pipewire-pulse", "node.name": "gsr-combined-77" }), "GPU Screen Recorder")
    assert.equal(o({ "application.name": "gpu-screen-recorder", "application.process.binary": "gpu-screen-recorder" }), "GPU Screen Recorder")
    assert.equal(o({ "application.name": "WEBRTC VoiceEngine", "application.process.binary": ".Discord-wrapped" }), "Discord")
    assert.equal(o({ "application.name": "vesktop", "application.process.binary": "electron" }), "Discord")
    assert.equal(o({ "application.name": "WEBRTC VoiceEngine", "application.process.binary": "electron", "node.name": "vesktop" }), "Discord")
    assert.equal(o({ "application.id": "com.discordapp.Discord", "application.process.binary": "Discord" }), "Discord")
    assert.equal(o({ "application.name": "Firefox", "application.process.binary": ".firefox-wrapped" }), "Firefox")
    assert.equal(o({ "application.name": "ALSA plug-in [audacity]", "application.process.binary": "audacity" }), "Audacity")
    assert.equal(o({ "application.name": "loopback-1234-56", "application.process.binary": "pipewire" }), "")
    assert.equal(o({ "application.name": "sylstack", "application.process.binary": ".sylstack-wrapped" }), "")
    assert.equal(o({ "application.name": "", "application.process.binary": "" }), "")
    assert.equal(o({ "application.name": "OBS", "application.process.binary": "obs" }), "OBS Studio")
    assert.equal(ownerOf({ "application.name": "Firefox", "application.process.binary": "firefox" }).browser, true)
    assert.equal(ownerOf({ "application.name": "vesktop", "application.process.binary": "electron" }).chat.id, "discord")
})

test("nodeKind tells a microphone from a speaker monitor, a virtual source and another stream", () => {
    assert.equal(nodeKind({ stream: false, sink: false, props: { "media.class": "Audio/Source", "node.name": "alsa_input.usb-mic", "device.id": "51" } }), "mic")
    assert.equal(nodeKind({ stream: false, sink: false, props: { "media.class": "Audio/Source", "node.name": "bluez_input.AA_BB" } }), "mic")
    assert.equal(nodeKind({ stream: false, sink: false, props: { "media.class": "Audio/Source/Virtual", "node.name": "gsr-combined-77" } }), "virtual")
    assert.equal(nodeKind({ stream: false, sink: true, props: { "media.class": "Audio/Sink", "node.name": "alsa_output.pci" } }), "monitor")
    assert.equal(nodeKind({ stream: true, sink: false, props: { "media.class": "Stream/Output/Audio" } }), "stream")
    assert.equal(nodeKind({ stream: false, sink: false, props: { "media.class": "Video/Source", "node.name": "v4l2_input.cam" } }), "camera")
    assert.equal(nodeKind({ stream: false, sink: false, props: {} }), "other")
})

test("streamsOf marks only streams fed by a real microphone as using it", () => {
    const mic = { stream: false, sink: false, props: { "media.class": "Audio/Source", "node.name": "alsa_input.mic", "device.id": "4" } }
    const speakers = { stream: false, sink: true, props: { "media.class": "Audio/Sink", "node.name": "alsa_output.pci" } }
    const virtual = { stream: false, sink: false, props: { "media.class": "Audio/Source/Virtual", "node.name": "gsr-combined-77" } }
    const captures = [
        { id: 10, audio: true, muted: false, props: { "application.name": "WEBRTC VoiceEngine", "application.process.binary": ".Discord-wrapped" } },
        { id: 11, audio: true, muted: false, props: { "application.name": "gpu-screen-recorder", "application.process.binary": "gpu-screen-recorder" } },
        { id: 12, audio: true, muted: false, props: { "application.name": "gsr-combined-77", "application.process.binary": "pipewire-pulse" } },
        { id: 13, audio: true, muted: false, props: { "application.name": "pavucontrol", "application.process.binary": "pavucontrol", "stream.monitor": "true" } },
        { id: 14, audio: false, muted: false, props: { "application.name": "Firefox", "application.process.binary": "firefox" } }
    ]
    const links = [{ target: 10, source: mic }, { target: 11, source: speakers }, { target: 11, source: virtual }, { target: 12, source: mic }, { target: 13, source: mic }]
    assert.deepEqual(streamsOf(captures, links).map(s => [s.id, s.owner, s.mic, s.video, s.monitor, s.peak]), [
        [10, "Discord", true, false, false, false],
        [11, "GPU Screen Recorder", false, false, true, false],
        [12, "GPU Screen Recorder", true, false, false, false],
        [13, "Pavucontrol", true, false, false, true],
        [14, "Firefox", false, true, false, false]
    ])
    assert.deepEqual(streamsOf(undefined, undefined), [])
})

test("voiceOf finds a call app and all of its streams in a fixed order", () => {
    const s = (id, owner, extra) => Object.assign({ id: id, owner: owner, chat: null, browser: false, mic: true, video: false, monitor: false, peak: false, muted: false }, extra || {})
    const discord = { id: "discord", label: "Discord", glyph: "speech" }
    const zoom = { id: "zoom", label: "Zoom", glyph: "voice" }
    assert.deepEqual(voiceOf([s(7, "Zoom", { chat: zoom }), s(3, "Discord", { chat: discord }), s(4, "Discord", { chat: discord, muted: true })]), { app: "Discord", glyph: "speech", ids: [3, 4], muted: false })
    assert.deepEqual(voiceOf([s(4, "Discord", { chat: discord, muted: true })]), { app: "Discord", glyph: "speech", ids: [4], muted: true })
    assert.deepEqual(voiceOf([s(2, "Firefox", { browser: true })]), { app: "Firefox", glyph: "voice", ids: [2], muted: false })
    assert.equal(voiceOf([s(2, "Firefox", { browser: true, monitor: true })]), null)
    assert.equal(voiceOf([s(5, "Discord", { chat: discord, peak: true })]), null)
    assert.equal(voiceOf([s(1, "OBS Studio")]), null)
    assert.equal(voiceOf([]), null)
})

test("voiceWindow finds the window of the app in the call", () => {
    const wins = [{ appId: "kitty", title: "zsh" }, { appId: "vesktop", title: "Discord | #general" }, { appId: "firefox", title: "Meet — Mozilla Firefox" }]
    assert.equal(voiceWindow(wins, "Discord"), wins[1])
    assert.equal(voiceWindow(wins, "Firefox"), wins[2])
    assert.equal(voiceWindow(wins, "Zoom"), null)
    assert.equal(voiceWindow(undefined, "Discord"), null)
})

test("nextSession keeps one start per call app and rides out a stream that drops for a moment", () => {
    const v = { app: "Discord", glyph: "speech", ids: [3], muted: false }
    const a = nextSession(null, v, 1000)
    assert.deepEqual(a, { app: "Discord", glyph: "speech", ids: [3], muted: false, since: 1000, gone: 0 })
    const b = nextSession(a, Object.assign({}, v, { ids: [9] }), 5000)
    assert.equal(b.since, 1000)
    const c = nextSession(b, null, 6000)
    assert.deepEqual([c.since, c.gone, c.ids], [1000, 6000, []])
    assert.equal(nextSession(c, null, 6000 + VOICE_GRACE - 1).since, 1000)
    assert.equal(nextSession(nextSession(c, null, 7000), v, 8000).since, 1000)
    assert.equal(nextSession(c, null, 6000 + VOICE_GRACE), null)
    assert.equal(nextSession(a, Object.assign({}, v, { app: "Zoom" }), 9000).since, 9000)
    assert.equal(nextSession(null, null, 1), null)
})

test("an ongoing voice chat comes right after an incoming call and follows the calls switch", () => {
    const voice = { id: 296, app: "Discord", glyph: "speech", muted: false, elapsed: 65000 }
    const s = Object.assign({}, idle, { voice: voice, media: { title: "Song", playing: true } })
    assert.deepEqual(activities(s, DEFAULT_ISLAND).map(a => a.kind), ["voice", "media"])
    assert.deepEqual(activities(Object.assign({}, s, { call: { app: "Signal", sender: "Ola" } }), DEFAULT_ISLAND).map(a => a.kind), ["call", "voice", "media"])
    assert.deepEqual(activities(s, Object.assign({}, DEFAULT_ISLAND, { calls: false })).map(a => a.kind), ["media"])
    assert.equal(label(Object.assign({ kind: "voice" }, voice)), "Discord · 1:05")
    assert.equal(label(Object.assign({ kind: "voice" }, voice, { muted: true })), "Discord · muted")
})

test("tucked hides the island at the edge only in hover mode and while nothing needs it", () => {
    const calm = { hot: false, pinned: false, alert: false }
    assert.equal(tucked("always", calm), false)
    assert.equal(tucked("hover", calm), true)
    assert.equal(tucked("hover", Object.assign({}, calm, { hot: true })), false)
    assert.equal(tucked("hover", Object.assign({}, calm, { pinned: true })), false)
    assert.equal(tucked("hover", Object.assign({}, calm, { alert: true })), false)
})

test("privacy mode stays in the island with an undo and hides the apps-in-use row", () => {
    const s = { privacy: { combo: "SUPER+SHIFT+P" }, inuse: { apps: ["Firefox"], mic: true, camera: false }, media: { title: "Song", playing: true } }
    assert.deepEqual(activities(s, DEFAULT_ISLAND).map(a => a.kind), ["privacy", "media"])
    assert.deepEqual(activities({ inuse: s.inuse }, DEFAULT_ISLAND).map(a => a.kind), ["inuse"])
    assert.deepEqual(activities(s, Object.assign({}, DEFAULT_ISLAND, { privacy: false })).map(a => a.kind), ["media"])
    assert.equal(label({ kind: "privacy" }), "Mic and cameras off")
    assert.equal(label({ kind: "inuse", apps: ["Firefox"], mic: true, camera: true }), "Firefox · mic and camera")
    assert.equal(validateIsland({ privacy: "yes" }).privacy, true)
})

test("inUse names the apps really using the microphone or a camera, once each", () => {
    const s = (id, owner, extra) => Object.assign({ id: id, owner: owner, chat: null, browser: false, mic: false, video: false, monitor: false, peak: false, muted: false }, extra || {})
    const streams = [
        s(1, "Firefox", { mic: true }),
        s(2, "cava", { monitor: true }),
        s(3, "", { mic: true }),
        s(4, "Discord", { mic: true }),
        s(5, "OBS Studio", { video: true }),
        s(6, "GPU Screen Recorder", { mic: true }),
        s(7, "GPU Screen Recorder", { monitor: true }),
        s(8, "Pavucontrol", { mic: true, peak: true }),
        s(9, "Firefox", { mic: true })
    ]
    assert.deepEqual(inUse(streams, ["zoom"], [4]), { apps: ["Firefox", "OBS Studio", "GPU Screen Recorder", "zoom"], mic: true, camera: true })
    assert.deepEqual(inUse([], ["Firefox"], []), { apps: ["Firefox"], mic: false, camera: true })
    assert.equal(inUse(streams.slice(1, 4), [], [4]), null)
    assert.equal(inUse([s(7, "GPU Screen Recorder", { monitor: true })], [], []), null)
})

test("status flashes a switch change and privacy on is left to its own row", () => {
    assert.deepEqual(status("dnd", true), { kind: "status", id: "dnd", on: true, text: "Do not disturb", glyph: "dnd", state: "On" })
    assert.equal(status("network", false, "Home").state, "Disconnected")
    assert.equal(status("network", true, "Home").text, "Home")
    assert.equal(status("nope", true), null)
    assert.deepEqual(activities({ flash: status("wifi", false) }, DEFAULT_ISLAND).map(a => a.kind), ["status"])
    assert.deepEqual(activities({ flash: status("wifi", false) }, Object.assign({}, DEFAULT_ISLAND, { status: false })), [])
    assert.deepEqual(activities({ flash: status("privacy", true) }, DEFAULT_ISLAND), [])
    assert.deepEqual(activities({ flash: status("privacy", false) }, DEFAULT_ISLAND).map(a => a.kind), ["status"])
    assert.equal(label(status("night", true)), "Night light on")
    assert.deepEqual(SHORTCUTS.privacy.run, ["privacy", "toggle"])
})

test("inCall keeps the island up for an incoming or ongoing call unless pinCalls or calls is off", () => {
    assert.equal(DEFAULT_ISLAND.pinCalls, true)
    assert.equal(inCall(DEFAULT_ISLAND, { call: { sender: "Mia" }, voice: null }), true)
    assert.equal(inCall(DEFAULT_ISLAND, { call: null, voice: { app: "Discord" } }), true)
    assert.equal(inCall(DEFAULT_ISLAND, { call: null, voice: null }), false)
    assert.equal(inCall(validateIsland({ pinCalls: false }), { call: { sender: "Mia" } }), false)
    assert.equal(inCall(validateIsland({ calls: false }), { voice: { app: "Discord" } }), false)
    assert.equal(validateIsland({ pinCalls: 1 }).pinCalls, true)
})

test("ownsFocus matches the focused app id, or its last dot segment, against the desktop entry or app name", () => {
    assert.equal(ownsFocus("org.telegram.desktop", "org.telegram.desktop", "Telegram"), true)
    assert.equal(ownsFocus("firefox", "", "Firefox"), true)
    assert.equal(ownsFocus("org.mozilla.firefox", "", "firefox"), true)
    assert.equal(ownsFocus("Signal", "signal", ""), true)
    assert.equal(ownsFocus("foot", "", "firefox"), false)
    assert.equal(ownsFocus("org.telegram.desktop", "", "desktop2"), false)
    assert.equal(ownsFocus("", "", ""), false)
    assert.equal(ownsFocus(undefined, "", "firefox"), false)
})
