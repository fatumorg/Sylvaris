import { test } from "node:test"
import assert from "node:assert/strict"
import { DEFAULT_CORNERS, validateCorners, cornerAction, cornersOn } from "../shell/lib/corners.mjs"

test("hot corners are off until asked for", () => {
    assert.deepEqual(validateCorners(undefined), DEFAULT_CORNERS)
    assert.equal(validateCorners({ enabled: "yes" }).enabled, false)
})

test("only real corners with an action or a command survive", () => {
    const v = validateCorners({
        enabled: true,
        dwell: 99999,
        actions: {
            "*:top-left": "pad toggle",
            "DP-1:bottom-right": { command: ["kitty"] },
            "DP-1:middle": "pad toggle",
            "top-right": "center toggle",
            "*:bottom-left": "  ",
            "*:top-right": { command: [] },
            "HDMI-A-1:top-right": { command: ["notify-send", 3] }
        }
    })
    assert.equal(v.dwell, 2000)
    assert.deepEqual(Object.keys(v.actions).sort(), ["*:top-left", "DP-1:bottom-right"])
})

test("a screen's own corner beats the one for every screen", () => {
    const actions = { "*:top-left": "pad toggle", "DP-1:top-left": "center toggle", "*:bottom-right": { command: ["kitty"] } }
    assert.equal(cornerAction(actions, "DP-1", "top-left"), "center toggle")
    assert.equal(cornerAction(actions, "DP-2", "top-left"), "pad toggle")
    assert.equal(cornerAction(actions, "DP-2", "top-right"), null)
    assert.deepEqual(cornersOn(actions, "DP-2"), ["top-left", "bottom-right"])
})
