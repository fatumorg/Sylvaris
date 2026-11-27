import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { SECTIONS, HUBS, resolveSection, tabsIn } from "../shell/lib/sections.mjs"
import { MODULES } from "../shell/lib/modules.mjs"

const page = readFileSync(new URL("../shell/settings/SylSettings.qml", import.meta.url), "utf8")

test("sections have unique keys, a label and a glyph", () => {
    const keys = SECTIONS.map(s => s.key)
    assert.equal(new Set(keys).size, keys.length)
    for (const s of SECTIONS) {
        assert.ok(s.label.length > 0, s.key)
        assert.ok(typeof s.glyph === "string" && s.glyph.length > 0, s.key)
        assert.equal(s.group, undefined, s.key)
    }
})

test("hubs group pages by what people look for", () => {
    assert.deepEqual(HUBS.map(h => [h.key, h.tabs]), [
        ["look", ["look", "appearance", "wallpaper", "widgets", "motion", "sync"]],
        ["panels", ["bar", "deck", "center", "island", "notifications", "launcher", "switcher"]],
        ["apps", ["files", "archive", "viewer", "capture", "clip", "notes", "top"]],
        ["time", ["clock", "weather"]],
        ["system", ["general", "displays", "sound", "power", "access", "keyboard"]],
        ["shortcuts", ["keybinds", "commands"]],
        ["security", ["lock", "polkit"]],
        ["plugins", ["plugins", "diver", "fatest", "rgb", "temp"]],
        ["about", ["about"]]
    ])
    assert.equal(HUBS.find(h => h.key === "time").label, "Clock & weather")
    assert.equal(HUBS.find(h => h.key === "shortcuts").label, "Shortcuts")
    assert.equal(SECTIONS.find(s => s.key === "about").label, "About")
})

test("labels say what is inside", () => {
    assert.equal(SECTIONS.find(s => s.key === "appearance").label, "Theme & colours")
    assert.equal(SECTIONS.find(s => s.key === "clock").label, "Clock & sky")
})

test("every section has a page and every module points at a section", () => {
    for (const s of SECTIONS)
        assert.match(page, new RegExp("\\b" + s.key + ": " + "[a-z]+Page\\b"), s.key)
    for (const name of Object.keys(MODULES))
        assert.ok(SECTIONS.some(s => s.key === MODULES[name].section), name)
})

test("every section lives in exactly one hub", () => {
    for (const s of SECTIONS)
        assert.equal(HUBS.filter(h => h.tabs.includes(s.key)).length, 1, s.key)
})

test("resolveSection finds the hub and tab", () => {
    assert.deepEqual(resolveSection("motion"), { hub: "look", tab: "motion" })
    assert.deepEqual(resolveSection("wallpaper"), { hub: "look", tab: "wallpaper" })
    assert.equal(resolveSection("nope"), null)
})

test("tabsIn hides plugin tabs that are off", () => {
    assert.deepEqual(tabsIn("plugins", {}).map(s => s.key), ["plugins"])
    assert.deepEqual(tabsIn("plugins", { diver: true, rgb: true }).map(s => s.key), ["plugins", "diver", "rgb"])
    assert.deepEqual(tabsIn("look", {}).map(s => s.key), ["look", "appearance", "wallpaper", "widgets", "motion", "sync"])
    assert.deepEqual(tabsIn("nope", {}), [])
})
