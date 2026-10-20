import { test } from "node:test"
import assert from "node:assert/strict"
import { origin, scaledRect, rise, stagger, grow, PRESETS, presetTokens } from "../shell/lib/motion.mjs"

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
