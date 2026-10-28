import { test } from "node:test"
import assert from "node:assert/strict"
import { TYPES, DEFAULT_WIDGETS, validateWidgets, place, nudge, newId, covered, tooMany, servicesFor, span } from "../shell/lib/widgets.mjs"

const ON = { enabled: { diver: true, temp: true } }

test("an item whose screen is gone stays in settings but has no place", () => {
    const v = validateWidgets({ items: [{ id: "abcd", type: "clock", screen: "HDMI-A-9" }] }, {}).values
    assert.equal(v.items.length, 1)
    assert.equal(place(v.items[0], [{ name: "DP-1", width: 1920, height: 1080 }], 80, 12), null)
    assert.notEqual(place(v.items[0], [{ name: "HDMI-A-9", width: 1920, height: 1080 }], 80, 12), null)
})

test("hand edited junk drops with one error each and the rest loads", () => {
    const r = validateWidgets({
        items: [
            { type: "toaster" },
            { id: "aaaa", type: "clock", w: -3, h: 999 },
            { id: "aaaa", type: "weather" },
            "nope",
            { type: "photos", anchor: "middle", layer: "sky", options: { mode: "hologram", interval: -5 } }
        ]
    }, {})
    assert.equal(r.values.items.length, 3)
    assert.equal(r.errors.length, 3)
    const [clock, weather, photos] = r.values.items
    assert.equal(clock.id, "aaaa")
    assert.notEqual(weather.id, "aaaa")
    assert.match(weather.id, /^[a-z0-9]{4}$/)
    assert.deepEqual([clock.w, clock.h], [TYPES.clock.sizes.min[0], TYPES.clock.sizes.max[1]])
    assert.equal(photos.anchor, "top-left")
    assert.equal(photos.layer, "desktop")
    assert.equal(photos.options.mode, "single")
    assert.equal(photos.options.interval, 3)
})

test("defaults are valid as they are", () => {
    assert.deepEqual(validateWidgets(DEFAULT_WIDGETS, {}).values, DEFAULT_WIDGETS)
    assert.deepEqual(validateWidgets(undefined, {}).values, DEFAULT_WIDGETS)
})

test("place keeps a far widget on a small screen", () => {
    const r = place({ screen: "eDP-1", anchor: "top-left", col: 40, row: 0, w: 4, h: 2 }, [{ name: "eDP-1", width: 1366, height: 768 }], 80, 12)
    assert.equal(r.w, span(4, 80, 12))
    assert.equal(r.x, 1366 - r.w)
    assert.equal(r.y, 12)
})

test("anchors count from their own corner", () => {
    const s = [{ name: "a", width: 1000, height: 800 }]
    const r = place({ screen: "a", anchor: "bottom-right", col: 0, row: 0, w: 2, h: 2 }, s, 80, 12)
    assert.deepEqual(r, { x: 1000 - 12 - 172, y: 800 - 12 - 172, w: 172, h: 172 })
    const c = place({ screen: "a", anchor: "center", col: 0, row: 0, w: 2, h: 2 }, s, 80, 12)
    assert.deepEqual([c.x, c.y], [414, 314])
})

test("nudge moves the second of two stacked items down by whole cells", () => {
    const s = { name: "a", width: 1920, height: 1080 }
    const items = [
        { id: "aaaa", screen: "a", anchor: "top-left", col: 0, row: 0, w: 2, h: 2 },
        { id: "bbbb", screen: "a", anchor: "top-left", col: 0, row: 0, w: 2, h: 2 },
        { id: "cccc", screen: "b", anchor: "top-left", col: 0, row: 0, w: 2, h: 2 }
    ]
    const out = nudge(items, s, 80, 12)
    assert.equal(out[0].row, 0)
    assert.equal(out[1].row, 2)
    assert.equal(out[2], items[2])
})

test("plugin widgets validate but sleep while their plugin is off", () => {
    const raw = { items: [{ type: "diver" }, { type: "temp" }, { type: "clock" }] }
    assert.deepEqual(validateWidgets(raw, {}).values.items.map(i => i.inactive), [true, true, false])
    assert.deepEqual(validateWidgets(raw, ON).values.items.map(i => i.inactive), [false, false, false])
})

test("widgets bring only the services their items need", () => {
    assert.deepEqual(servicesFor({ items: [{ type: "weather" }] }, {}), ["Weather", "Sky"])
    assert.deepEqual(servicesFor({ items: [] }, {}), [])
    assert.deepEqual(servicesFor({ items: [{ type: "temp" }] }, {}), [])
    assert.deepEqual(servicesFor({ items: [{ type: "stack", children: [{ type: "temp" }] }] }, ON), ["Temps"])
})

test("stacks hold widgets but not other stacks", () => {
    const r = validateWidgets({ items: [{ type: "stack", children: [{ type: "clock" }, { type: "stack" }] }] }, {})
    assert.equal(r.values.items[0].children.length, 1)
    assert.equal(r.errors.length, 1)
})

test("items without an id get the same id every time they load", () => {
    const raw = { items: [{ type: "clock" }, { id: "w000", type: "weather" }, { type: "photos" }] }
    const ids = validateWidgets(raw, {}).values.items.map(i => i.id)
    assert.deepEqual(validateWidgets(raw, {}).values.items.map(i => i.id), ids)
    assert.equal(new Set(ids).size, 3)
    assert.equal(ids[1], "w000")
})

test("newId is short and fresh", () => {
    const taken = []
    for (let i = 0; i < 200; i++)
        taken.push(newId(taken))
    assert.equal(new Set(taken).size, 200)
    assert.ok(taken.every(id => /^[a-z0-9]{4}$/.test(id)))
})

test("covered means fullscreen or maximized on that screen", () => {
    assert.equal(covered([{ screen: "a", maximized: true }], "a"), true)
    assert.equal(covered([{ screen: "b", fullscreen: true }], "a"), false)
    assert.equal(covered([{ screen: "a" }], "a"), false)
    assert.equal(tooMany(new Array(25).fill({})), true)
    assert.equal(tooMany(new Array(24).fill({})), false)
})

import { zoneTime, snap, guides, resizeTo, begin, apply, undo, commit, wordClock, stackIndex, kittyOk, kittyArgs, moveArgs, shouldRestart, splitCommand, cavaConfig, parseBars, batteryRings, photoList, nextPhoto } from "../shell/lib/widgets.mjs"

test("snap rounds pixels to whole cells", () => {
    assert.equal(snap(170, 80, 12), 2)
    assert.equal(snap(-50, 80, 12), 0)
})

test("guides find a shared left edge", () => {
    const g = guides({ x: 102, y: 300, w: 100, h: 100 }, [{ x: 100, y: 0, w: 300, h: 50 }])
    assert.ok(g.some(x => x.axis === "x" && x.at === 100))
    assert.equal(guides({ x: 500, y: 500, w: 10, h: 10 }, [{ x: 0, y: 0, w: 10, h: 10 }]).length, 0)
})

test("resizeTo stays inside the type's sizes", () => {
    const r = resizeTo({ type: "clock", w: 4, h: 2 }, 99, 0)
    assert.deepEqual([r.w, r.h], [TYPES.clock.sizes.max[0], TYPES.clock.sizes.min[1]])
})

test("an edit session undoes a move and commits nudged", () => {
    const items = [
        { id: "aaaa", type: "clock", screen: "a", anchor: "top-left", col: 0, row: 0, w: 2, h: 2 },
        { id: "bbbb", type: "clock", screen: "a", anchor: "top-left", col: 4, row: 0, w: 2, h: 2 }
    ]
    let s = apply(begin(items), { kind: "move", id: "bbbb", dc: -4 })
    assert.equal(s.items[1].col, 0)
    assert.equal(undo(s).items[1].col, 4)
    const out = commit(s, [{ name: "a", width: 1920, height: 1080 }], 80, 12)
    assert.equal(out[1].row, 2)
    s = apply(s, { kind: "remove", id: "aaaa" })
    assert.equal(s.items.length, 1)
    assert.equal(undo(begin(items)).items, items)
})

test("moving right goes right whichever corner the item hangs from", () => {
    const item = { id: "aaaa", type: "clock", screen: "a", anchor: "top-right", col: 2, row: 1, w: 2, h: 2 }
    const screen = [{ name: "a", width: 1920, height: 1080 }]
    const before = place(item, screen, 80, 12)
    const after = place(apply(begin([item]), { kind: "move", id: "aaaa", dc: 1, dr: 1 }).items[0], screen, 80, 12)
    assert.equal(after.x - before.x, 92)
    assert.equal(after.y - before.y, 92)
})

test("the word clock lights the right words", () => {
    const w = wordClock(10, 30)
    assert.ok(w.includes("HALF") && w.includes("TEN"))
    assert.deepEqual(wordClock(10, 45).slice(-2), ["TO", "ELEVEN"])
    assert.deepEqual(wordClock(0, 0), ["IT", "IS", "TWELVE", "OCLOCK"])
    assert.deepEqual(wordClock(3, 59).slice(-2), ["FOUR", "OCLOCK"])
})

test("stacks turn around both ends", () => {
    assert.equal(stackIndex(0, 3, -1), 2)
    assert.equal(stackIndex(2, 3, 1), 0)
    assert.equal(stackIndex(0, 0, 1), 0)
})

test("kitty 0.42 or newer runs the terminal widget", () => {
    assert.equal(kittyOk("kitty 0.41.9 created by Kovid Goyal"), false)
    assert.equal(kittyOk("kitty 0.42.0 created by Kovid Goyal"), true)
    assert.equal(kittyOk("kitty 1.0.0"), true)
    assert.equal(kittyOk(""), false)
})

test("kitty gets the command as argv, never through a shell", () => {
    const item = { id: "k3f9", layer: "desktop", options: Object.assign({}, TYPES.terminal.defaults, { command: "cava" }) }
    const rect = { x: 10, y: 20, w: 400, h: 200 }
    const a = kittyArgs(item, rect, "DP-1", "/run/s.sock")
    assert.deepEqual(a.slice(-1), ["cava"])
    assert.ok(a.includes("--edge=none"))
    assert.equal(a[a.indexOf("--layer") + 1], "bottom")
    assert.equal(a[a.indexOf("--focus-policy") + 1], "not-allowed")
    const shell = kittyArgs(Object.assign({}, item, { options: TYPES.terminal.defaults }), rect, "DP-1", "/run/s.sock")
    assert.equal(shell[shell.length - 1].startsWith("window_padding_width="), true)
    assert.deepEqual(splitCommand("btop --utf-force 'a b' \"\""), ["btop", "--utf-force", "a b", ""])
    assert.ok(moveArgs(rect, "/run/s.sock").includes("--action=os-panel"))
})

test("a terminal that keeps dying stops after three quick exits", () => {
    assert.equal(shouldRestart([1000], 2000), true)
    assert.equal(shouldRestart([1000, 2000], 3000), true)
    assert.equal(shouldRestart([1000, 2000, 3000], 4000), false)
    assert.equal(shouldRestart([1000, 2000, 3000], 30000), true)
})

test("cava speaks raw ascii bars", () => {
    assert.match(cavaConfig({ bars: 3, fps: 60, smoothing: 0.5 }), /method = raw/)
    assert.deepEqual(parseBars("0;500;1000;", 3), [0, 0.5, 1])
    assert.equal(parseBars("0;500;", 3), null)
    assert.equal(parseBars("x;y;z;", 3), null)
})

test("batteries split airpods into left, right and case", () => {
    const demo = [
        { name: "AirPods · Left", level: 82, charging: false, kind: "earbud", part: "left" },
        { name: "AirPods · Right", level: 78, charging: false, kind: "earbud", part: "right" },
        { name: "AirPods · Case", level: 55, charging: true, kind: "case", part: "case" },
        { name: "This computer", level: 40, kind: "battery" }
    ]
    const r = batteryRings(demo, {})
    assert.deepEqual(r.slice(0, 3).map(x => x.kind), ["bud-left", "bud-right", "case"])
    assert.equal(r[3].kind, "laptop")
    assert.deepEqual(batteryRings([], { hideEmpty: true }), [])
})

test("photoList keeps pictures only and caps the list", () => {
    assert.deepEqual(photoList("b.png\nnotes.txt\na.jpg\n"), ["a.jpg", "b.png"])
    assert.equal(photoList(Array.from({ length: 600 }, (_, i) => i + ".png").join("\n")).length, 500)
})

test("nextPhoto never repeats the same photo", () => {
    for (let i = 0; i < 5; i++)
        assert.notEqual(nextPhoto(i, 5, true, 7), i)
    assert.equal(nextPhoto(4, 5, false, 0), 0)
    assert.equal(nextPhoto(0, 1, true, 0), 0)
})

test("zoneTime reads a label and a UTC offset and rejects the rest", () => {
    const utc = new Date(Date.UTC(2026, 9, 28, 22, 15))
    const z = zoneTime(utc, "Tokyo +9", true)
    assert.equal(z.label, "Tokyo")
    assert.equal(z.time, "07:15")
    assert.equal(zoneTime(utc, "Mumbai +5:30", true).time, "03:45")
    assert.equal(zoneTime(utc, "-5", false).time, "5:15")
    assert.equal(zoneTime(utc, "-5", false).label, "UTC-5")
    assert.equal(zoneTime(utc, "Europe/Paris", true), null)
    assert.equal(zoneTime(utc, "Mars +30", true), null)
})
