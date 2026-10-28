import { test } from "node:test"
import assert from "node:assert/strict"
import { EXTRAS, offeredExtras, airpodsLine, speedLine, layoutBento } from "../shell/lib/center.mjs"
import { validateSettings } from "../shell/lib/settings.mjs"

test("extra tiles are opt-in and plugin tiles need their plugin", () => {
    assert.deepEqual(EXTRAS.map(e => e.key), ["fatest", "airpods", "rgb", "awake", "screenshot", "record", "clip", "lock"])
    const none = offeredExtras({ enabled: {} }).map(e => e.key)
    assert.deepEqual(none, ["screenshot", "record", "clip", "lock"])
    const both = offeredExtras({ enabled: { fatest: true, airpods: true } }).map(e => e.key)
    assert.deepEqual(both, ["fatest", "airpods", "screenshot", "record", "clip", "lock"])
    assert.deepEqual(offeredExtras(undefined).map(e => e.key), none)
})

test("center.extra keeps known extras once, in order given", () => {
    assert.deepEqual(validateSettings({}).center.extra, [])
    assert.deepEqual(validateSettings({ center: { extra: ["lock", "fatest", "lock", "nope", 1] } }).center.extra, ["lock", "fatest"])
    assert.deepEqual(validateSettings({ center: { extra: "lock" } }).center.extra, [])
})

test("tile subtitles for AirPods and speed tests", () => {
    assert.equal(airpodsLine(false, {}), "Not connected")
    assert.equal(airpodsLine(true, { left: { level: 82 }, right: { level: 78 } }), "L 82% · R 78%")
    assert.equal(airpodsLine(true, { left: { level: 40 } }), "L 40%")
    assert.equal(airpodsLine(true, {}), "Connected")
    assert.equal(speedLine("download", 120.4, null), "Testing · 120 Mbps")
    assert.equal(speedLine("server", 0, null), "Finding a server")
    assert.equal(speedLine("idle", 0, { download: 318.7, upload: 43.8 }), "↓ 319 · ↑ 44 Mbps")
    assert.equal(speedLine("idle", 0, null), "Not run yet")
    assert.equal(speedLine("error", 0, null), "Failed")
})

test("bento puts two wide tiles first, small tiles three to a row, and fills the last row", () => {
    const ids = ["wifi", "bluetooth", "night", "dnd", "hotspot", "toggle:a", "toggle:b"]
    const cells = layoutBento(ids)
    assert.deepEqual(cells.slice(0, 2).map(c => [c.col, c.row, c.w, c.small]), [[0, 0, 3, false], [3, 0, 3, false]])
    assert.deepEqual(cells.slice(2).map(c => [c.col, c.row, c.w, c.small]), [[0, 1, 2, true], [2, 1, 2, true], [4, 1, 2, true], [0, 2, 3, true], [3, 2, 3, true]])
    assert.deepEqual(layoutBento(["a", "b", "c"]).slice(2).map(c => [c.col, c.w]), [[0, 6]])
    for (let n = 0; n < 12; n++) {
        const seen = new Set()
        const all = layoutBento(Array.from({ length: n }, (_, i) => "t" + i))
        assert.equal(all.length, n)
        for (const c of all) {
            assert.ok(c.col + c.w <= 6)
            for (let x = c.col; x < c.col + c.w; x++) {
                assert.ok(!seen.has(c.row + ":" + x))
                seen.add(c.row + ":" + x)
            }
        }
        const rows = new Set(all.filter(c => c.small).map(c => c.row))
        for (const r of rows)
            assert.equal(all.filter(c => c.row === r).reduce((s, c) => s + c.w, 0), 6)
    }
    assert.deepEqual(layoutBento(["a"]).map(c => c.w), [3])
    assert.equal(validateSettings({ center: { layout: "bento" } }).center.layout, "bento")
    assert.equal(validateSettings({ center: { layout: "x" } }).center.layout, "grid")
})
