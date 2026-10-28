import { test } from "node:test"
import assert from "node:assert/strict"
import { quantize, contrast, themeFromPalette, wallId, wallTheme, withAccent, accentFrom } from "../shell/lib/palette.mjs"
import { validateTheme, COLOR_KEYS, DEFAULT_THEME } from "../shell/lib/theme.mjs"

function image(colors) {
    const out = []
    for (const [rgb, n] of colors) {
        for (let i = 0; i < n; i++)
            out.push(rgb[0], rgb[1], rgb[2], 255)
    }
    return out
}

const PALETTES = [
    [{ r: 20, g: 40, b: 90, n: 50 }, { r: 230, g: 120, b: 40, n: 10 }],
    [{ r: 240, g: 240, b: 235, n: 80 }, { r: 200, g: 30, b: 60, n: 5 }],
    [{ r: 128, g: 128, b: 128, n: 100 }],
    [{ r: 10, g: 200, b: 90, n: 30 }, { r: 250, g: 250, b: 0, n: 30 }, { r: 0, g: 0, b: 0, n: 30 }],
    [{ r: 90, g: 60, b: 200, n: 3 }, { r: 30, g: 30, b: 35, n: 97 }]
]

test("a two colour image quantizes to those two", () => {
    const q = quantize(image([[[200, 30, 40], 900], [[10, 20, 250], 100]]), 4)
    assert.equal(q.length, 2)
    assert.deepEqual(q[0], { r: 200, g: 30, b: 40, n: 900 })
    assert.deepEqual(q[1], { r: 10, g: 20, b: 250, n: 100 })
})

test("quantize skips see-through pixels and never returns more than asked", () => {
    assert.deepEqual(quantize([255, 0, 0, 0], 4), [])
    const q = quantize(image([[[1, 2, 3], 5], [[50, 60, 70], 5], [[200, 100, 0], 5], [[0, 255, 255], 5]]), 2)
    assert.equal(q.length, 2)
    assert.equal(q[0].n + q[1].n, 20)
})

test("contrast follows wcag", () => {
    assert.equal(Math.round(contrast("#000000", "#ffffff")), 21)
    assert.equal(contrast("#777777", "#777777"), 1)
})

test("a grey image still makes a valid theme", () => {
    const t = themeFromPalette(quantize(image([[[128, 128, 128], 64]]), 8), true)
    const v = validateTheme(Object.assign({ name: "Grey" }, t))
    assert.equal(v.ok, true)
    assert.deepEqual(v.errors, [])
})

test("every palette clears the contrast floors in dark and light", () => {
    for (const p of PALETTES) {
        for (const dark of [true, false]) {
            const c = themeFromPalette(p, dark).colors
            for (const key of COLOR_KEYS)
                assert.match(c[key], /^#[0-9a-f]{6}$/, key)
            assert.ok(contrast(c.text, c.base) >= 7, "text " + JSON.stringify(p))
            assert.ok(contrast(c.textDim, c.base) >= 4.5, "textDim " + JSON.stringify(p))
            assert.ok(contrast(c.onAccent, c.accent) >= 4.5, "onAccent " + JSON.stringify(p))
        }
    }
})

test("dark and light pick opposite bases", () => {
    assert.ok(contrast(themeFromPalette(PALETTES[0], true).colors.base, "#000000") < 2)
    assert.ok(contrast(themeFromPalette(PALETTES[0], false).colors.base, "#ffffff") < 2)
})

test("the most colourful colour becomes the accent", () => {
    const c = themeFromPalette(PALETTES[4], true).colors.accent
    const r = parseInt(c.slice(1, 3), 16), b = parseInt(c.slice(5, 7), 16)
    assert.ok(b > r)
})

test("wallId is stable and short", () => {
    assert.equal(wallId("/a/b.png"), wallId("/a/b.png"))
    assert.notEqual(wallId("/a/b.png"), wallId("/a/c.png"))
    assert.match(wallId("/a/b.png"), /^wall-[0-9a-f]{8}$/)
})

test("wallTheme builds a full theme file for the path", () => {
    const t = wallTheme("/home/u/Pictures/sea side.jpg", image([[[20, 40, 90], 60], [[230, 120, 40], 10]]), "")
    assert.equal(t.id, wallId("/home/u/Pictures/sea side.jpg"))
    assert.equal(t.wallpaper, "/home/u/Pictures/sea side.jpg")
    assert.equal(t.name, "sea side")
    assert.deepEqual(validateTheme(t).errors, [])
    assert.equal(wallTheme("/x.png", image([[[250, 250, 250], 10]]), "").colors.base > "#cccccc", true)
    assert.equal(wallTheme("/x.png", image([[[250, 250, 250], 10]]), "dark").colors.base < "#333333", true)
})

test("withAccent swaps the accent family and keeps it readable", () => {
    const t = withAccent(DEFAULT_THEME, "#ff00aa")
    assert.equal(t.colors.base, DEFAULT_THEME.colors.base)
    assert.notEqual(t.colors.accent, DEFAULT_THEME.colors.accent)
    assert.ok(contrast(t.colors.onAccent, t.colors.accent) >= 4.5)
    assert.equal(withAccent(DEFAULT_THEME, ""), DEFAULT_THEME)
    assert.equal(withAccent(DEFAULT_THEME, "red"), DEFAULT_THEME)
})

test("accentFrom picks a colour from pixels or nothing", () => {
    assert.match(accentFrom(image([[[30, 30, 30], 50], [[40, 160, 220], 10]])), /^#[0-9a-f]{6}$/)
    assert.equal(accentFrom([]), "")
})
