import { test } from "node:test"
import assert from "node:assert/strict"
import {
    MATERIALS, CORNERS, DENSITY, WEIGHTS, CASES, SECTIONS, CONTROL_CHOICES, LOOKS, DEFAULT_LOOK, validateLook, resolveLook, glassFor, lookDefaults, applyLook, pickFont, scaled, slugLook, validateUserLook, validateStyle, takeSection, styleSettings, originOf, styleFile, configOwned, styleRows, lookFile, cornerPath, blurRadius, shufflePick, daySeed
} from "../shell/lib/look.mjs"
import { DEFAULT_GLASS, effectiveSettings } from "../shell/lib/settings.mjs"

const pick = (o, keys) => keys.reduce((out, k) => Object.assign(out, { [k]: o[k] }), {})

test("classic resolves to the 1.1 glass", () => assert.deepEqual(pick(resolveLook({ preset: "classic" }, {}, {}).glass, Object.keys(DEFAULT_GLASS)), DEFAULT_GLASS))

test("classic keeps the 1.1 shape", () => {
    const r = resolveLook({ preset: "classic" }, {}, {})
    assert.equal(r.radius, 1)
    assert.equal(r.density, 1)
    assert.equal(r.corners, "round")
    assert.equal(r.weight, "regular")
    assert.deepEqual(r.fonts, { ui: "IBM Plex Sans", mono: "IBM Plex Mono", display: "IBM Plex Sans" })
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
        assert.ok(MATERIALS[LOOKS[id].glass.material] !== undefined, id)
        assert.ok(CORNERS.includes(LOOKS[id].shape.corners), id)
        assert.ok(DENSITY[LOOKS[id].shape.density] !== undefined, id)
        assert.ok(WEIGHTS.includes(LOOKS[id].type.weight), id)
        assert.ok(CASES.includes(LOOKS[id].type.labelCase), id)
        for (const k of Object.keys(CONTROL_CHOICES))
            assert.ok(CONTROL_CHOICES[k].includes(LOOKS[id].controls[k]), id + " " + k)
        assert.deepEqual(validateStyle(styleFile(LOOKS[id])), LOOKS[id], id)
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
    assert.deepEqual(lookDefaults({ preset: "classic" }, {}), styleSettings(LOOKS.classic))
    assert.equal(lookDefaults({ preset: "mine" }, { mine: validateStyle({ name: "Mine", settings: { motion: { preset: "calm" } } }) }).motion.preset, "calm")
    assert.deepEqual(lookDefaults(undefined, {}), styleSettings(LOOKS.lumen))
})

test("applyLook clears only keys the look owns", () => {
    const r = applyLook({ motion: { preset: "calm", scale: 1.2 }, look: { corners: "sharp" } }, "mine", { mine: validateStyle({ name: "Mine", settings: { motion: { preset: "snappy" } } }) })
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
    assert.equal(u.glass.material, "ink")
    assert.equal(u.shape.radius, 1)
    assert.equal(u.shape.corners, "round")
    assert.deepEqual(u.legacy, { motion: { preset: "calm" } })
    assert.equal(validateUserLook({ material: "ink" }), null)
    assert.equal(validateUserLook([]), null)
})

test("lookFile saves the resolved look with its name", () => {
    const f = lookFile("Night Owl", resolveLook({ preset: "ink", glow: 0.4 }, {}, {}), Object.assign(styleSettings(LOOKS.ink), { motion: { preset: "calm" }, bar: { position: "bottom" } }))
    assert.equal(f.version, 2)
    assert.equal(f.name, "Night Owl")
    assert.equal(f.glass.material, "ink")
    assert.equal(f.glass.glow, 0.4)
    assert.equal(f.motion.preset, "calm")
    assert.deepEqual(f.controls, LOOKS.ink.controls)
    assert.deepEqual(f.legacy, { bar: { position: "bottom" } })
    assert.deepEqual(validateUserLook(f).type.fonts, f.type.fonts)
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

test("shufflePick is the same for the same seed and skips what you have now", () => {
    const looks = ["lumen", "classic", "frost", "ink"]
    const themes = ["warm", "tp", "nord"]
    assert.deepEqual(shufflePick(looks, themes, 42), shufflePick(looks, themes, 42))
    assert.ok(looks.includes(shufflePick(looks, themes, 7).look))
    for (let seed = 0; seed < 50; seed++) {
        const p = shufflePick(looks, themes, seed, { look: "lumen", theme: "warm" })
        assert.notEqual(p.look, "lumen")
        assert.notEqual(p.theme, "warm")
    }
    assert.deepEqual(shufflePick(["ink"], [], 3, { look: "ink" }), { look: "ink", theme: "" })
    const seen = new Set()
    for (let seed = 0; seed < 40; seed++)
        seen.add(shufflePick(looks, themes, seed).look)
    assert.equal(seen.size, looks.length)
})

test("daySeed differs from day to day", () => {
    assert.notEqual(daySeed("2026-10-28"), daySeed("2026-10-29"))
    assert.notEqual(daySeed("2026-10-31"), daySeed("2026-11-01"))
    assert.equal(daySeed("nope"), 0)
})

test("every built-in style differs from every other in every section", () => {
    const ids = Object.keys(LOOKS)
    for (const s of SECTIONS)
        for (const a of ids)
            for (const b of ids)
                if (a < b) assert.notDeepEqual(LOOKS[a][s], LOOKS[b][s], a + " and " + b + " share " + s)
})

test("version 1 looks map onto sections and keep their settings", () => {
    const v = validateStyle({ name: "Old", material: "neon", corners: "bevel", radius: 0.8, weight: "light", shadow: 0.3, settings: { bar: { style: "slab" } } })
    assert.equal(v.glass.material, "neon"); assert.equal(v.glass.shadow, 0.3)
    assert.equal(v.shape.corners, "bevel"); assert.equal(v.type.weight, "light")
    assert.equal(styleSettings(v).bar.style, "slab")
})

test("version 2 style validation drops bad values and fills from classic", () => {
    const v = validateStyle({ version: 2, name: "Mine", controls: { toggle: "led", slider: "wobbly" }, type: { tracking: 9 } })
    assert.equal(v.controls.toggle, "led"); assert.equal(v.controls.slider, LOOKS.classic.controls.slider)
    assert.equal(v.type.tracking, LOOKS.classic.type.tracking)
    assert.equal(validateStyle({ version: 2 }), null)
    assert.equal(validateStyle("{"), null)
})

test("take from copies a whole section and nothing else", () => {
    const m = takeSection(LOOKS.ink, "layout", LOOKS.neon)
    assert.deepEqual(m.layout, LOOKS.neon.layout); assert.deepEqual(m.controls, LOOKS.ink.controls)
    m.layout.barStyle = "x"; assert.notEqual(LOOKS.neon.layout.barStyle, "x")
})

test("an edited built-in overrides it and reports its origin", () => {
    const user = { ink: validateStyle({ version: 2, name: "Ink", controls: { toggle: "led" } }) }
    assert.equal(resolveLook({ preset: "ink" }, {}, user).controls.toggle, "led")
    assert.equal(originOf("ink", user), "edited"); assert.equal(originOf("ink", {}), "built-in"); assert.equal(originOf("nope", {}), "")
})

test("a style supplies layout as settings defaults, but config and your settings win", () => {
    const fx = effectiveSettings({ bar: { style: "minimal" } }, { look: { preset: "neon" } }, {})
    assert.equal(fx.bar.style, "minimal"); assert.equal(fx.lock.face, LOOKS.neon.layout.lockFace)
    assert.equal(applyLook({ lock: { face: "word" } }, "ink", {}).lock, undefined)
})

test("missing style fonts fall back", () => {
    assert.equal(pickFont("Orbitron", ["Inter"], "Inter"), "Inter")
})

test("config-owned style keys are reported so the editor can say so", () => {
    assert.deepEqual(configOwned({ bar: { style: "slab" } }), ["bar.style"])
    assert.deepEqual(configOwned({ notifications: { server: true } }), [])
})

test("the editor has a valid row for every value a section holds", () => {
    for (const s of SECTIONS) {
        const rows = styleRows(s)
        for (const k of Object.keys(LOOKS.classic[s]).filter(k => k !== "fonts" && k !== "material" || s === "glass"))
            assert.ok(rows.some(r => r.key === k), s + "." + k)
        for (const r of rows) {
            if (r.kind === "choice")
                assert.ok(r.options.length > 1 && r.options.every(o => validateStyle({ version: 2, name: "x", [s]: { [r.key]: o } })[s][r.key] === o), s + "." + r.key)
            if (r.kind === "number")
                for (const v of [r.min, r.max])
                    assert.equal(validateStyle({ version: 2, name: "x", [s]: { [r.key]: v } })[s][r.key], v, s + "." + r.key + " " + v)
        }
    }
})
