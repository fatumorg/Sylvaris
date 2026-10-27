import { test } from "node:test"
import assert from "node:assert/strict"
import { PRESETS, parseVnc, parseAddresses, rightOf, presetLabel, vncConfigCommand } from "../shell/lib/virtual.mjs"
import { execFileSync } from "node:child_process"
import { mkdtempSync, writeFileSync, readFileSync, statSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

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
    assert.deepEqual(rightOf(Object.assign({ virtual: { enabled: true, x: 6400, y: 0, scale: 2, width: 2388, height: 1668 } }, snap), "virtual"), { x: 4480, y: 0 })
    assert.deepEqual(rightOf({ a: { enabled: true, x: 0, y: 0, scale: 2, width: 2388, height: 1668 } }), { x: 1194, y: 0 })
})

const runVnc = file => {
    const argv = vncConfigCommand(file)
    execFileSync(argv[0], argv.slice(1))
    return readFileSync(file, "utf8")
}

test("vncConfigCommand creates a private config with a 128-bit password", () => {
    const file = join(mkdtempSync(join(tmpdir(), "syl-vnc-")), "wayvnc", "config")
    const text = runVnc(file)
    assert.match(text, /^password=[0-9a-f]{32}$/m)
    assert.match(text, /^username=sylvaris$/m)
    assert.match(text, /^rsa_private_key_file=rsa_key\.pem$/m)
    assert.equal(statSync(file).mode & 0o777, 0o600)
    assert.match(readFileSync(join(file, "..", "rsa_key.pem"), "utf8"), /BEGIN RSA PRIVATE KEY/)
})

test("vncConfigCommand replaces only a short password and keeps the key and other lines", () => {
    const dir = mkdtempSync(join(tmpdir(), "syl-vnc-"))
    const file = join(dir, "config")
    writeFileSync(join(dir, "rsa_key.pem"), "KEY")
    writeFileSync(file, "use_relative_paths=true\naddress=0.0.0.0\nenable_auth=true\nusername=sylvaris\npassword=0a1b2c3d\nrsa_private_key_file=rsa_key.pem\nport=5901\n")
    const text = runVnc(file)
    const pw = text.match(/^password=(.*)$/m)[1]
    assert.match(pw, /^[0-9a-f]{32}$/)
    assert.equal(text, "use_relative_paths=true\naddress=0.0.0.0\nenable_auth=true\nusername=sylvaris\npassword=" + pw + "\nrsa_private_key_file=rsa_key.pem\nport=5901\n")
    assert.equal(readFileSync(join(dir, "rsa_key.pem"), "utf8"), "KEY")
    assert.equal(runVnc(file), text)
})

test("vncConfigCommand leaves a config without username=sylvaris alone", () => {
    const file = join(mkdtempSync(join(tmpdir(), "syl-vnc-")), "config")
    const mine = "address=127.0.0.1\nusername=me\npassword=short\n"
    writeFileSync(file, mine)
    assert.equal(runVnc(file), mine)
})
