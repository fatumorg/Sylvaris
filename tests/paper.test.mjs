import { test } from "node:test"
import assert from "node:assert/strict"
import { validatePaper, resolve, isImage, fillMode, DEFAULT_PAPER } from "../shell/lib/paper.mjs"

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
