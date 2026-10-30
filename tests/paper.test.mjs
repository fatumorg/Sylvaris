import { test } from "node:test"
import assert from "node:assert/strict"
import { validatePaper, resolve, choose, preview, dropsPick, isImage, fillMode, DEFAULT_PAPER } from "../shell/lib/paper.mjs"

test("validatePaper keeps sane values and drops bad ones", () => {
    const p = validatePaper({ fit: "stretch", blur: 4, dim: 0.4, themes: { noir: "/a.png", bad: 3 }, duration: 99999, transition: "slide" })
    assert.equal(p.fit, DEFAULT_PAPER.fit)
    assert.equal(p.blur, DEFAULT_PAPER.blur)
    assert.equal(p.dim, 0.4)
    assert.deepEqual(p.themes, { noir: "/a.png" })
    assert.equal(p.duration, DEFAULT_PAPER.duration)
    assert.equal(p.transition, "slide")
    assert.equal(validatePaper({}).enabled, true)
})

test("an output override beats a theme pick, which beats the theme's own wallpaper", () => {
    const p = validatePaper({ themes: { noir: "/t.png" }, outputs: { "DP-1": "/o.png" } })
    assert.equal(resolve(p, "noir", "/w.png", "DP-1"), "/o.png")
    assert.equal(resolve(p, "noir", "/w.png", "DP-2"), "/t.png")
    assert.equal(resolve(p, "amber", "/w.png", "DP-2"), "/w.png")
    assert.equal(resolve(p, "amber", "", "DP-2"), "")
})

test("a pick for everywhere sits under theme and screen picks and clears them", () => {
    const p = validatePaper({ wallpaper: "/all.png", themes: { noir: "/t.png" }, outputs: { "DP-1": "/o.png" } })
    assert.equal(resolve(p, "amber", "/w.png", "DP-2"), "/all.png")
    assert.equal(resolve(p, "noir", "/w.png", "DP-2"), "/t.png")
    assert.deepEqual(choose(p, "all", "noir", "DP-1", "/new.png"), { wallpaper: "/new.png", themes: {}, outputs: {} })
    assert.deepEqual(choose(p, "all", "noir", "DP-1", ""), { wallpaper: "", themes: {}, outputs: {} })
    assert.deepEqual(choose(p, "theme", "amber", "DP-1", "/a.png"), { themes: { noir: "/t.png", amber: "/a.png" } })
    assert.deepEqual(choose(p, "theme", "noir", "DP-1", ""), { themes: {} })
    assert.deepEqual(choose(p, "output", "noir", "DP-1", ""), { outputs: {} })
    assert.deepEqual(choose(p, "output", "noir", "", "/x.png"), { wallpaper: "/x.png", themes: {}, outputs: {} })
    assert.equal(validatePaper({}).wallpaper, "")
})

test("image names and fill modes", () => {
    assert.equal(isImage("a.JPG"), true)
    assert.equal(isImage("notes.txt"), false)
    assert.equal(fillMode("cover"), 2)
    assert.equal(fillMode("tile"), 3)
})

test("parallax defaults to 0.4 and clamps into 0 to 1", () => {
    assert.equal(validatePaper({}).parallax, 0.4)
    assert.equal(validatePaper({ parallax: 3 }).parallax, 1)
    assert.equal(validatePaper({ parallax: -2 }).parallax, 0)
    assert.equal(validatePaper({ parallax: "x" }).parallax, 0.4)
    assert.equal(validatePaper({ parallax: 0.2 }).parallax, 0.2)
    assert.equal(validatePaper({}).menu, true)
    assert.equal(validatePaper({ menu: false }).menu, false)
})

test("a theme preview shows that theme's own wallpaper, not one picked for every theme", () => {
    const p = validatePaper({ wallpaper: "/kitten.png", themes: { noir: "/n.png" } })
    assert.equal(preview(p, "warm", "/dachshund.png"), "/dachshund.png")
    assert.equal(preview(p, "noir", "/noir-own.png"), "/n.png")
    assert.equal(preview(p, "bare", ""), "/kitten.png")
})

test("applying another theme drops the every-theme pick only when that theme brings a wallpaper", () => {
    const p = validatePaper({ wallpaper: "/kitten.png", themes: { noir: "/n.png" } })
    assert.equal(dropsPick(p, "kitten", "warm", "/dachshund.png"), true)
    assert.equal(dropsPick(p, "kitten", "kitten", "/kitten.png"), false)
    assert.equal(dropsPick(p, "kitten", "bare", ""), false)
    assert.equal(dropsPick(p, "kitten", "noir", "/noir-own.png"), false)
    assert.equal(dropsPick(validatePaper({}), "kitten", "warm", "/d.png"), false)
})
