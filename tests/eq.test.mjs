import { test } from "node:test"
import assert from "node:assert/strict"
import { validateEq, presetOf, preamp, params, config, PRESETS, BANDS } from "../shell/lib/eq.mjs"

test("validateEq clamps gains to half-dB steps within ±12 and falls back on bad input", () => {
    const e = validateEq({ enabled: true, bands: [20, -20, 1.26, 0, 0, 0, 0, 0, 0, 0], preset: "weird", spatialLevel: 5 })
    assert.deepEqual(e.bands.slice(0, 3), [12, -12, 1.5])
    assert.equal(e.preset, "flat")
    assert.equal(e.spatialLevel, 1)
    assert.deepEqual(validateEq({ bands: [1, 2] }).bands, PRESETS.flat)
    assert.equal(validateEq({}).enabled, false)
})

test("presetOf recognises presets and calls anything else custom", () => {
    assert.equal(presetOf(PRESETS.rock), "rock")
    assert.equal(presetOf([1, 0, 0, 0, 0, 0, 0, 0, 0, 0]), "custom")
})

test("preamp leaves headroom for the largest boost", () => {
    assert.equal(preamp(PRESETS.flat), 1)
    assert.ok(Math.abs(preamp(PRESETS.bass) - Math.pow(10, -6 / 20)) < 1e-9)
})

test("spatial off sends nothing across, on sends some of each side to the other", () => {
    const off = params(validateEq({ bands: PRESETS.flat }))
    assert.equal(off[off.indexOf("mixL:Gain 2") + 1], 0)
    assert.equal(off[off.indexOf("mixL:Gain 1") + 1], 1)
    const on = params(validateEq({ bands: PRESETS.flat, spatial: true, spatialLevel: 0.5 }))
    assert.ok(on[on.indexOf("mixL:Gain 2") + 1] > 0)
    assert.ok(on[on.indexOf("mixL:Gain 1") + 1] < 1)
})

test("config builds a stereo filter graph aimed at the target sink", () => {
    const c = config(validateEq({ bands: PRESETS.bass }), "alsa_output.x \"quoted\"")
    assert.equal((c.match(/label = bq_/g) || []).length, BANDS.length * 2 + 2)
    assert.match(c, /name = eqL_1 label = bq_lowshelf control = \{ "Freq" = 31\.0 "Q" = 1\.0 "Gain" = 6\.0 \}/)
    assert.match(c, /output = "delayL:Out" input = "mixR:In 2"/)
    assert.match(c, /target\.object = "alsa_output\.x \\"quoted\\""/)
    assert.match(c, /node\.name = "sylvaris_eq" media\.class = Audio\/Sink/)
})

test("config keeps WirePlumber from restoring a saved mute on the eq output", () => {
    assert.match(config(validateEq({}), ""), /playback\.props = \{ node\.name = "sylvaris_eq_out" node\.passive = true state\.restore-props = false/)
})
