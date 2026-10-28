import { test } from "node:test"
import assert from "node:assert/strict"
import {
    MATERIALS, CORNERS, DENSITY, WEIGHTS, LOOKS, DEFAULT_LOOK, validateLook, resolveLook, glassFor, lookDefaults, applyLook, pickFont, scaled, slugLook, validateUserLook, lookFile, cornerPath, blurRadius
} from "../shell/lib/look.mjs"
import { DEFAULT_GLASS } from "../shell/lib/settings.mjs"

const pick = (o, keys) => keys.reduce((out, k) => Object.assign(out, { [k]: o[k] }), {})

test("classic resolves to the 1.1 glass", () => assert.deepEqual(pick(resolveLook({ preset: "classic" }, {}, {}).glass, Object.keys(DEFAULT_GLASS)), DEFAULT_GLASS))

test("classic keeps the 1.1 shape", () => {
    const r = resolveLook({ preset: "classic" }, {}, {})
    assert.equal(r.radius, 1)
    assert.equal(r.density, 1)
    assert.equal(r.corners, "round")
    assert.equal(r.weight, "regular")
    assert.deepEqual(r.fonts, { ui: "Inter", mono: "JetBrainsMono Nerd Font", display: "Inter" })
    assert.equal(r.glass.grain + r.glass.highlight + r.glass.glow + r.glass.shadow, 0)
})

test("user glass beats material", () => assert.equal(resolveLook({ preset: "lumen" }, { sheen: 0.9 }, {}).glass.sheen, 0.9))

test("explicit override beats preset", () => assert.equal(resolveLook({ preset: "lumen", corners: "sharp" }, {}, {}).corners, "sharp"))

test("sharp corners shrink the radius", () => assert.ok(resolveLook({ preset: "classic", corners: "sharp" }, {}, {}).radius < 0.5))

test("bad look keys drop with errors", () => {
    const r = validateLook({ preset: "nope", radius: 9, corners: "blob" }, {})
    assert.equal(r.values.preset, "lumen")
    assert.equal(r.values.radius, undefined)
    assert.equal(r.errors.length, 3)
})

test("validateLook keeps good overrides and rejects junk", () => {
    const r = validateLook({ preset: "ink", density: "roomy", accent: "#a1B2c3", fonts: { ui: "Fira Sans", mono: 3 }, parts: { bar: { material: "neon", sheen: 2 }, "Bad Key": {} }, glow: 0.5 }, {})
    assert.equal(r.values.density, "roomy")
    assert.equal(r.values.accent, "#a1B2c3")
    assert.deepEqual(r.values.fonts, { ui: "Fira Sans" })
    assert.deepEqual(r.values.parts, { bar: { material: "neon" } })
    assert.equal(r.values.glow, 0.5)
    assert.equal(r.errors.length, 3)
    assert.equal(validateLook("nope", {}).values.preset, "lumen")
    assert.equal(validateLook({ accent: "red" }, {}).values.accent, undefined)
})

test("every material has every key in range", () => {
    for (const id of Object.keys(MATERIALS)) {
        for (const k of ["opacity", "layerOpacity", "tint", "sheen", "rim", "grain", "highlight", "glow", "shadow"])
            assert.ok(MATERIALS[id][k] >= 0 && MATERIALS[id][k] <= 1, id + "." + k)
        assert.ok(MATERIALS[id].flow >= 0 && MATERIALS[id].flow <= 3)
    }
    for (const id of Object.keys(LOOKS)) {
        assert.ok(MATERIALS[LOOKS[id].material] !== undefined, id)
        assert.ok(CORNERS.includes(LOOKS[id].corners), id)
        assert.ok(DENSITY[LOOKS[id].density] !== undefined, id)
        assert.ok(WEIGHTS.includes(LOOKS[id].weight), id)
    }
    assert.equal(DEFAULT_LOOK.preset, "lumen")
})

test("glassFor applies part override", () => assert.equal(glassFor(resolveLook({ preset: "lumen", parts: { bar: { material: "ink" } } }, {}, {}), "bar").sheen, MATERIALS.ink.sheen))

test("glassFor without a part override is the resolved glass", () => {
    const r = resolveLook({ preset: "frost" }, {}, {})
    assert.equal(glassFor(r, "center").opacity, r.glass.opacity)
    assert.equal(glassFor(r, "").radius, r.radius)
})

test("lookDefaults returns the look's settings partial", () => {
    assert.deepEqual(lookDefaults({ preset: "classic" }, {}), {})
    assert.deepEqual(lookDefaults({ preset: "mine" }, { mine: Object.assign({}, LOOKS.ink, { name: "Mine", settings: { motion: { preset: "calm" } } }) }), { motion: { preset: "calm" } })
    assert.deepEqual(lookDefaults(undefined, {}), LOOKS.lumen.settings)
})

test("applyLook clears only keys the look owns", () => {
    const r = applyLook({ motion: { preset: "calm", scale: 1.2 }, look: { corners: "sharp" } }, "mine", { mine: Object.assign({}, LOOKS.classic, { name: "Mine", settings: { motion: { preset: "snappy" } } }) })
    assert.equal(r.motion.preset, undefined)
    assert.equal(r.motion.scale, 1.2)
    assert.equal(r.look.preset, "mine")
    assert.equal(r.look.corners, undefined)
})

test("applyLook drops custom glass levels but keeps glass on or off", () => {
    const r = applyLook({ glass: { enabled: false, sheen: 0.9 }, look: { followTheme: true } }, "ink", {})
    assert.deepEqual(r.glass, { enabled: false })
    assert.equal(r.look.followTheme, true)
})

test("pickFont falls back when missing", () => {
    assert.equal(pickFont("Nope Sans", ["Inter"], "Inter"), "Inter")
    assert.equal(pickFont("Inter", ["Inter"], "X"), "Inter")
    assert.equal(pickFont("inter", ["Inter"], "X"), "Inter")
})

test("user look ids resolve", () => assert.equal(resolveLook({ preset: "mine" }, {}, { mine: Object.assign({}, LOOKS.ink, { name: "Mine" }) }).material, "ink"))

test("scaled rounds and never goes negative", () => {
    assert.equal(scaled(24, 1.15), 28)
    assert.equal(scaled(24, 1), 24)
    assert.equal(scaled(10, -1), 0)
})

test("slugLook makes safe file names", () => {
    assert.equal(slugLook("My Look!"), "my-look")
    assert.equal(slugLook("  "), "")
    assert.equal(slugLook("Lumen"), "")
    assert.equal(slugLook("x".repeat(60)).length, 40)
})

test("validateUserLook fills gaps and rejects junk", () => {
    const u = validateUserLook({ name: "Night", material: "ink", radius: 5, settings: { motion: { preset: "calm" } } })
    assert.equal(u.material, "ink")
    assert.equal(u.radius, 1)
    assert.equal(u.corners, "round")
    assert.deepEqual(u.settings, { motion: { preset: "calm" } })
    assert.equal(validateUserLook({ material: "ink" }), null)
    assert.equal(validateUserLook([]), null)
})

test("lookFile saves the resolved look with its name", () => {
    const f = lookFile("Night Owl", resolveLook({ preset: "ink", glow: 0.4 }, {}, {}), { motion: { preset: "calm" } })
    assert.equal(f.name, "Night Owl")
    assert.equal(f.material, "ink")
    assert.equal(f.glow, 0.4)
    assert.deepEqual(f.settings, { motion: { preset: "calm" } })
    assert.deepEqual(validateUserLook(f).fonts, f.fonts)
})

test("cornerPath draws closed squircle and bevel outlines inside the box", () => {
    for (const style of ["squircle", "bevel"]) {
        const d = cornerPath(200, 100, 20, style)
        assert.match(d, /^M /)
        assert.match(d, / Z$/)
        const nums = d.match(/-?\d+(\.\d+)?/g).map(Number)
        assert.ok(nums.every(n => n >= 0 && n <= 200), style)
    }
    assert.match(cornerPath(200, 100, 20, "squircle"), / C /)
    assert.doesNotMatch(cornerPath(200, 100, 20, "bevel"), / C /)
    assert.equal(cornerPath(0, 10, 5, "bevel"), "")
})

test("cornerPath never lets corners overlap on a pill", () => {
    const nums = cornerPath(100, 30, 40, "squircle").match(/-?\d+(\.\d+)?/g).map(Number)
    assert.ok(nums.every(n => n >= 0 && n <= 100))
})

test("blurRadius keeps the blur inside the shaped corner", () => {
    assert.equal(blurRadius(20, "round"), 20)
    assert.ok(blurRadius(20, "squircle") > 20)
    assert.ok(blurRadius(20, "bevel") >= 20)
})

test("a user look named like a builtin gets no file name", () => {
    assert.equal(slugLook("Classic"), "")
    assert.equal(slugLook("Ink"), "")
    assert.equal(slugLook("Ink 2"), "ink-2")
})

test("aurora follows the material unless set", () => {
    assert.equal(resolveLook({ preset: "classic" }, {}, {}).aurora, false)
    assert.equal(resolveLook({ preset: "lumen" }, {}, {}).aurora, true)
    assert.equal(resolveLook({ preset: "lumen", aurora: false }, {}, {}).aurora, false)
    assert.equal(validateLook({ aurora: "yes" }, {}).errors.length, 1)
})
