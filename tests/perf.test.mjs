import { test } from "node:test"
import assert from "node:assert/strict"
import { liteFor, perfArgs } from "../shell/lib/perf.mjs"

test("perfArgs trims the compositor and a reload brings the config back", () => {
    assert.deepEqual(perfArgs("hyprland", true, false), ["hyprctl", "reload"])
    assert.equal(perfArgs("hyprland", true, true)[1], "eval")
    assert.ok(perfArgs("hyprland", true, true)[2].includes("animations = { enabled = false }"))
    assert.ok(perfArgs("hyprland", false, true)[2].startsWith("keyword animations:enabled 0 ; "))
    assert.deepEqual(perfArgs("sway", false, false), ["swaymsg", "reload"])
    assert.equal(perfArgs("niri", false, true), null)
})

test("liteFor follows the mode, a custom performance toggle and a focused full-screen window in auto", () => {
    const game = { fullscreen: true, activated: true, minimized: false }
    assert.equal(liteFor("on", false, []), true)
    assert.equal(liteFor("off", false, [game]), false)
    assert.equal(liteFor("off", true, []), true)
    assert.equal(liteFor("auto", false, [game]), true)
    assert.equal(liteFor("auto", false, []), false)
    assert.equal(liteFor("auto", false, [{ fullscreen: true, activated: false, minimized: false }]), false)
    assert.equal(liteFor("auto", false, [{ fullscreen: true, activated: true, minimized: true }]), false)
    assert.equal(liteFor("auto", false, [{ fullscreen: false, activated: true, minimized: false }]), false)
})
