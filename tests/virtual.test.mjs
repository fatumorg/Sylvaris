import { test } from "node:test"
import assert from "node:assert/strict"
import { PRESETS, parseVnc, parseAddresses, rightOf, presetLabel } from "../shell/lib/virtual.mjs"

test("PRESETS start with the iPad Pro 11 inch size", () => {
    assert.deepEqual(PRESETS[0], { label: "iPad Pro 11″", width: 2388, height: 1668 })
    assert.ok(PRESETS.every(p => Number.isInteger(p.width) && Number.isInteger(p.height)))
})

test("presetLabel names known sizes and falls back to the size", () => {
    assert.equal(presetLabel(2388, 1668), "iPad Pro 11″")
    assert.equal(presetLabel(1000, 700), "1000×700")
})

test("parseVnc reads user, password and port", () => {
    assert.deepEqual(parseVnc("address=0.0.0.0\nusername = ipad\npassword=ab=cd\nport=5901\n"), { username: "ipad", password: "ab=cd", port: 5901 })
    assert.deepEqual(parseVnc(""), { username: "", password: "", port: 5900 })
    assert.deepEqual(parseVnc("port=nope"), { username: "", password: "", port: 5900 })
})

test("parseAddresses lists global IPv4 addresses", () => {
    const text = "2: enp6s0    inet 192.168.0.209/24 brd 192.168.0.255 scope global dynamic enp6s0\\       valid_lft 1 preferred_lft 1\n4: wlp16s0    inet 10.42.0.1/24 brd 10.42.0.255 scope global wlp16s0\\       valid_lft forever\n"
    assert.deepEqual(parseAddresses(text), ["192.168.0.209", "10.42.0.1"])
    assert.deepEqual(parseAddresses(""), [])
})

test("rightOf places a new screen right of the rightmost one", () => {
    const snap = {
        "DP-5": { enabled: true, x: 0, y: 500, scale: 1, width: 1920, height: 1080 },
        "DP-6": { enabled: true, x: 1920, y: 0, scale: 1, width: 2560, height: 1440 },
        "HDMI-A-2": { enabled: false }
    }
    assert.deepEqual(rightOf(snap), { x: 4480, y: 0 })
    assert.deepEqual(rightOf({}), { x: 0, y: 0 })
    assert.deepEqual(rightOf({ a: { enabled: true, x: 0, y: 0, scale: 2, width: 2388, height: 1668 } }), { x: 1194, y: 0 })
})
