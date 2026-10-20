import { test } from "node:test"
import assert from "node:assert/strict"
import { kelvinRgb, hasMirror } from "../shell/lib/night.mjs"

test("kelvinRgb is neutral at 6500 K and warmer below it", () => {
    for (const c of kelvinRgb(6500))
        assert.ok(Math.abs(c - 1) < 0.02, String(c))
    const [r, g, b] = kelvinRgb(4000)
    assert.equal(r, 1)
    assert.ok(g < 1 && b < g)
    assert.ok(kelvinRgb(3000)[2] < b)
    for (const c of kelvinRgb(1000))
        assert.ok(c >= 0 && c <= 1)
})

test("hasMirror spots a mirrored Hyprland monitor", () => {
    assert.equal(hasMirror([{ name: "HDMI-A-2", mirrorOf: "1" }, { name: "DP-5", mirrorOf: "none" }]), true)
    assert.equal(hasMirror([{ name: "DP-5", mirrorOf: "none" }]), false)
    assert.equal(hasMirror([]), false)
    assert.equal(hasMirror([{ name: "HDMI-A-2", mirrorOf: "1", disabled: true }]), false)
    assert.equal(hasMirror("nope"), false)
})
