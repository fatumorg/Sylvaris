import { test } from "node:test"
import assert from "node:assert/strict"
import { pamService, sessionPath, isLockSignal, DEFAULT_LOCK, validateLock } from "../shell/lib/lock.mjs"

test("pamService honours the setting, else picks the first installed service", () => {
    assert.equal(pamService("custom", []), "custom")
    assert.equal(pamService("", ["login", "hyprlock", "sylvaris"]), "sylvaris")
    assert.equal(pamService("", ["login", "swaylock"]), "swaylock")
    assert.equal(pamService("", []), "login")
})

test("sessionPath escapes the session id like systemd does", () => {
    assert.equal(sessionPath("2"), "/org/freedesktop/login1/session/_32")
    assert.equal(sessionPath("c1"), "/org/freedesktop/login1/session/c1")
    assert.equal(sessionPath("a-b"), "/org/freedesktop/login1/session/a_2db")
    assert.equal(sessionPath(""), "/org/freedesktop/login1/session/auto")
})

test("isLockSignal matches only a Lock signal for our session", () => {
    const p = sessionPath("2")
    assert.equal(isLockSignal(p + ": org.freedesktop.login1.Session.Lock ()", p), true)
    assert.equal(isLockSignal(p + ": org.freedesktop.login1.Session.Unlock ()", p), false)
    assert.equal(isLockSignal("/org/freedesktop/login1/session/_33: org.freedesktop.login1.Session.Lock ()", p), false)
})

test("validateLock keeps a safe service name and booleans", () => {
    assert.deepEqual(validateLock({}), DEFAULT_LOCK)
    assert.equal(validateLock({ pam: "hyprlock" }).pam, "hyprlock")
    assert.equal(validateLock({ pam: "../etc/shadow" }).pam, "")
    assert.equal(validateLock({ logind: true }).logind, true)
    assert.equal(validateLock({ logind: "yes" }).logind, false)
    assert.equal(validateLock({}).seconds, false)
    assert.equal(validateLock({ seconds: true }).seconds, true)
    assert.equal(validateLock({ seconds: "yes" }).seconds, false)
    assert.equal(validateLock({}).face, "default")
    assert.equal(validateLock({ face: "flip" }).face, "flip")
    assert.equal(validateLock({ face: "orbit" }).face, "default")
})
