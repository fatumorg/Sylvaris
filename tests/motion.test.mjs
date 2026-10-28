import { test } from "node:test"
import assert from "node:assert/strict"
import { origin, scaledRect, rise, stagger, grow, PRESETS, presetTokens, OPEN_STYLES, openFrame, frameRect, springCurve, tapOrigin, placedRect } from "../shell/lib/motion.mjs"

test("panels grow out of the corner they are anchored to", () => {
    assert.deepEqual(origin("top-right"), { h: 1, v: 0 })
    assert.deepEqual(origin("bottom-left"), { h: 0, v: 1 })
    assert.deepEqual(origin("center"), { h: 0.5, v: 0.5 })
    assert.deepEqual(scaledRect(0, 0, 100, 200, "top-right", 0.5, 0), { x: 50, y: 0, w: 50, h: 100 })
    assert.deepEqual(scaledRect(10, 10, 100, 100, "center", 0.5, -4), { x: 35, y: 31, w: 50, h: 50 })
    assert.equal(rise("bottom-center"), 1)
    assert.equal(rise("top-left"), -1)
})

test("stagger delays later items and still ends at one", () => {
    assert.equal(stagger(0, 0, 4), 0)
    assert.equal(stagger(1, 3, 4), 1)
    assert.ok(stagger(0.3, 0, 4) > stagger(0.3, 3, 4))
    assert.equal(stagger(0.1, 3, 4, 0.35), 0)
})

test("a panel opened from the island grows out of it from far smaller", () => {
    assert.equal(grow(0, false), 0.94)
    assert.equal(grow(1, false), 1)
    assert.equal(grow(0, true), 0.3)
    assert.equal(grow(1, true), 1)
    assert.ok(grow(0.5, true) < grow(0.5, false))
})

test("smooth keeps today's motion and every preset has a full set of curves", () => {
    assert.deepEqual(PRESETS, ["calm", "smooth", "snappy", "playful"])
    assert.deepEqual(presetTokens("smooth"), {
        pace: 1,
        enter: [0.05, 0.7, 0.1, 1, 1, 1],
        exit: [0.3, 0, 0.8, 0.15, 1, 1],
        move: [0.2, 0, 0, 1, 1, 1],
        spring: [0.34, 1.4, 0.64, 1, 1, 1]
    })
    for (const name of PRESETS) {
        const t = presetTokens(name)
        assert.ok(t.pace > 0, name)
        for (const k of ["enter", "exit", "move", "spring"])
            assert.equal(t[k].length, 6, name + " " + k)
    }
    assert.ok(presetTokens("calm").pace > 1)
    assert.ok(presetTokens("snappy").pace < 1)
    assert.ok(presetTokens("playful").enter[1] > 1)
    assert.deepEqual(presetTokens("nope"), presetTokens("smooth"))
})

test("every open style ends at rest and grow keeps the 1.1 motion", () => {
    const rest = { sx: 1, sy: 1, dx: 0, dy: 0, opacity: 1, blur: 0, angle: 0 }
    for (const style of OPEN_STYLES) {
        for (const corner of ["top-right", "bottom-left", "center"]) {
            const f = openFrame(style, 1, corner, { origin: { x: 0.2, y: 0 } })
            assert.deepEqual(Object.assign({}, f, { ox: undefined, oy: undefined }), Object.assign({}, rest, { ox: undefined, oy: undefined }), style)
        }
    }
    const g = openFrame("grow", 0.5, "top-right", {})
    assert.equal(g.sx, grow(0.5, false))
    assert.equal(g.dy, 0.5 * 10 * rise("top-right"))
    assert.equal(g.opacity, Math.min(1, 0.5 * 1.6))
    assert.equal(openFrame("grow", 0, "top-right", { emerging: true }).sx, grow(0, true))
})

test("morph without a click point is grow", () => {
    assert.deepEqual(openFrame("morph", 0.3, "top-right", { origin: null }), openFrame("grow", 0.3, "top-right", {}))
    const m = openFrame("morph", 0.3, "top-right", { origin: { x: 0.25, y: 0 } })
    assert.equal(m.ox, 0.25)
    assert.ok(m.sx < 0.5)
})

test("blur starts blurred, drop and swing start away from rest", () => {
    assert.ok(openFrame("blur", 0, "top-right", {}).blur > 0)
    assert.ok(openFrame("drop", 0, "top-right", {}).dy < 0)
    assert.ok(openFrame("drop", 0, "bottom-right", {}).dy > 0)
    assert.notEqual(openFrame("swing", 0, "top-right", {}).angle, 0)
    assert.ok(openFrame("unfold", 0, "top-right", {}).sy < 0.1)
    assert.equal(openFrame("nope", 0.5, "top-right", {}).sx, openFrame("grow", 0.5, "top-right", {}).sx)
})

test("reduced motion only fades", () => {
    for (const style of OPEN_STYLES) {
        for (const phase of [0, 0.4, 1]) {
            const f = openFrame(style, phase, "top-left", { reduced: true, origin: { x: 0.5, y: 0 } })
            assert.deepEqual([f.sx, f.sy, f.dx, f.dy, f.blur, f.angle], [1, 1, 0, 0, 0, 0], style)
        }
    }
})

test("frameRect follows the frame for the blur region", () => {
    assert.deepEqual(frameRect(0, 0, 100, 200, openFrame("grow", 1, "top-right", {})), { x: 0, y: 0, w: 100, h: 200 })
    const r = frameRect(0, 0, 100, 100, { sx: 0.5, sy: 0.5, dx: 0, dy: 4, ox: 1, oy: 0, angle: 0 })
    assert.deepEqual(r, { x: 50, y: 4, w: 50, h: 50 })
    assert.ok(frameRect(0, 0, 100, 100, openFrame("swing", 0.2, "top-left", {})).h < 100)
})

test("springCurve goes from no overshoot to the playful spring", () => {
    assert.ok(springCurve(0)[1] <= 1)
    assert.deepEqual(springCurve(1), presetTokens("playful").spring)
    assert.equal(springCurve(5)[1], springCurve(1)[1])
    assert.equal(springCurve(2 / 3)[1], presetTokens("smooth").spring[1])
})

test("tapOrigin turns a recent bar click into a point on the panel", () => {
    const screen = { name: "DP-1", w: 1000, h: 800 }
    const panel = { x: 500, y: 40, w: 400, h: 600 }
    assert.deepEqual(tapOrigin({ screen: "DP-1", x: 690, y: 15, w: 980, h: 30, at: 100 }, screen, panel, 300), { x: 0.5, y: 0 })
    assert.equal(tapOrigin({ screen: "DP-1", x: 690, y: 15, w: 980, h: 30, at: 100 }, screen, panel, 2000), null)
    assert.equal(tapOrigin({ screen: "DP-2", x: 690, y: 15, w: 980, h: 30, at: 100 }, screen, panel, 300), null)
    assert.equal(tapOrigin(null, screen, panel, 0), null)
    assert.deepEqual(tapOrigin({ screen: "DP-1", x: 20, y: 390, w: 40, h: 780, at: 0 }, screen, { x: 60, y: 100, w: 300, h: 600 }, 10), { x: 0, y: 0.5 })
})

test("placedRect puts a panel in its corner of the screen", () => {
    assert.deepEqual(placedRect("top-right", 1000, 800, 400, 600, 12), { x: 588, y: 12, w: 400, h: 600 })
    assert.deepEqual(placedRect("bottom-left", 1000, 800, 400, 600, 12), { x: 12, y: 188, w: 400, h: 600 })
    assert.deepEqual(placedRect("center", 1000, 800, 400, 600, 12), { x: 300, y: 100, w: 400, h: 600 })
})
