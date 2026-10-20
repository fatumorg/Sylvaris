import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { DEFAULT_ACCESS, FILTERS, validateAccess, hyprCommands, supports, tintShader } from "../shell/lib/access.mjs"

test("validateAccess keeps values in range", () => {
    assert.deepEqual(validateAccess({}), DEFAULT_ACCESS)
    assert.equal(validateAccess({ zoom: 9 }).zoom, 1)
    assert.equal(validateAccess({ zoom: 2.5 }).zoom, 2.5)
    assert.equal(validateAccess({ filter: "sepia" }).filter, "none")
    assert.equal(validateAccess({ filter: "deuteranopia" }).filter, "deuteranopia")
    assert.equal(validateAccess({ text: 1.3 }).text, 1.3)
    assert.equal(validateAccess({ text: 4 }).text, 1)
    assert.equal(validateAccess({ cursor: 48 }).cursor, 48)
    assert.equal(validateAccess({ cursor: 7 }).cursor, 0)
    assert.ok(FILTERS.indexOf("grayscale") >= 0)
})

test("hyprCommands speak Lua or classic config and clear the shader for no filter", () => {
    const a = Object.assign({}, DEFAULT_ACCESS, { zoom: 2, filter: "grayscale" })
    assert.deepEqual(hyprCommands(true, a, "/s"), [
        ["eval", "hl.config({ cursor = { zoom_factor = 2 } })"],
        ["eval", "hl.config({ decoration = { screen_shader = \"/s/grayscale.frag\" } })"]
    ])
    assert.deepEqual(hyprCommands(false, DEFAULT_ACCESS, "/s"), [
        ["keyword", "cursor:zoom_factor", "1"],
        ["keyword", "decoration:screen_shader", "[[EMPTY]]"]
    ])
    assert.deepEqual(hyprCommands(true, DEFAULT_ACCESS, "/s")[1], ["eval", "hl.config({ decoration = { screen_shader = \"\" } })"])
})

test("supports tells which compositor can zoom and filter", () => {
    assert.deepEqual(supports("hyprland"), { zoom: true, filter: true })
    assert.deepEqual(supports("sway"), { zoom: false, filter: false })
    assert.deepEqual(supports("niri"), { zoom: false, filter: false })
})

test("tintShader warms the plain screen or any filter by multiplying the final colour", () => {
    const plain = tintShader("", [1, 0.8, 0.6])
    assert.ok(plain.startsWith("#version 300 es"))
    assert.ok(plain.includes("fragColor.rgb *= vec3(1.0000, 0.8000, 0.6000);"))
    for (const f of FILTERS.filter(f => f !== "none")) {
        const src = readFileSync(new URL("../shell/assets/shaders/" + f + ".frag", import.meta.url), "utf8")
        const out = tintShader(src, [1, 0.5, 0.25])
        assert.ok(out.includes("fragColor.rgb *= vec3(1.0000, 0.5000, 0.2500);"), f)
        assert.ok(out.trimEnd().endsWith("}"), f)
        assert.ok(out.indexOf("fragColor.rgb *=") > out.lastIndexOf("fragColor ="), f)
    }
})

test("hyprCommands points the screen shader at the tinted file when night light needs it", () => {
    const a = Object.assign({}, DEFAULT_ACCESS, { filter: "grayscale" })
    assert.deepEqual(hyprCommands(true, a, "/s", "/run/night.frag")[1], ["eval", "hl.config({ decoration = { screen_shader = \"/run/night.frag\" } })"])
    assert.deepEqual(hyprCommands(false, DEFAULT_ACCESS, "/s", "/run/night.frag")[1], ["keyword", "decoration:screen_shader", "/run/night.frag"])
})
