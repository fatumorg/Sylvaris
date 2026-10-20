import { test } from "node:test"
import assert from "node:assert/strict"
import { validatePower, commandFor, needsConfirm, byKey, ring, uptime, DEFAULT_POWER } from "../shell/lib/power.mjs"

test("validatePower keeps known actions once and clean commands", () => {
    const p = validatePower({ actions: ["reboot", "nope", "reboot", "lock"], commands: { reboot: "doas reboot", fly: "x", lock: 3 }, countdown: 40 })
    assert.deepEqual(p.actions, ["reboot", "lock"])
    assert.deepEqual(p.commands, { reboot: "doas reboot" })
    assert.equal(p.countdown, DEFAULT_POWER.countdown)
    assert.deepEqual(validatePower({ actions: [] }).actions, DEFAULT_POWER.actions)
    assert.equal(validatePower({ confirm: false }).confirm, false)
})

test("commands come from overrides, the lock command or the defaults", () => {
    const p = validatePower({ commands: { reboot: "doas reboot" } })
    assert.equal(commandFor("reboot", p, "hyprlock"), "doas reboot")
    assert.equal(commandFor("lock", p, "hyprlock"), "hyprlock")
    assert.equal(commandFor("shutdown", p, "hyprlock"), "systemctl poweroff 2>/dev/null || loginctl poweroff")
    assert.equal(commandFor("logout", p, "hyprlock"), "")
})

test("confirmation, key shortcuts, ring layout and uptime", () => {
    assert.equal(needsConfirm("shutdown", validatePower({})), true)
    assert.equal(needsConfirm("lock", validatePower({})), false)
    assert.equal(needsConfirm("shutdown", validatePower({ confirm: false })), false)
    assert.equal(byKey(["lock", "reboot"], "R"), "reboot")
    assert.equal(byKey(["lock"], "r"), "")
    const top = ring(4, 0, 100, 50, 0)
    assert.ok(Math.abs(top.x) < 1e-9 && Math.abs(top.y + 50) < 1e-9)
    assert.ok(Math.abs(ring(4, 1, 100, 50, 0).x - 100) < 1e-9)
    assert.equal(uptime(59), "0m")
    assert.equal(uptime(3 * 3600 + 120), "3h 2m")
    assert.equal(uptime(2 * 86400 + 5 * 3600), "2d 5h")
})

test("suspend, hibernate, restart and shut down fall back to elogind's loginctl without systemd", () => {
    const p = validatePower({})
    assert.equal(commandFor("suspend", p, ""), "systemctl suspend 2>/dev/null || loginctl suspend")
    assert.equal(commandFor("hibernate", p, ""), "systemctl hibernate 2>/dev/null || loginctl hibernate")
    assert.equal(commandFor("reboot", p, ""), "systemctl reboot 2>/dev/null || loginctl reboot")
})
