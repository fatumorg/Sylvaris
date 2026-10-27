export const BANDS = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
export const LIMIT = 12
export const CROSSFEED = { freq: 700, delay: 0.0003 }

export const PRESETS = {
    flat: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    bass: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
    treble: [0, 0, 0, 0, 0, 1, 2, 4, 5, 6],
    vocal: [-2, -2, -1, 1, 3, 4, 3, 1, 0, -1],
    rock: [4, 3, 2, 0, -1, -1, 1, 2, 3, 4],
    electronic: [5, 4, 1, 0, -2, 1, 0, 1, 4, 5],
    acoustic: [3, 3, 2, 1, 1, 1, 2, 2, 2, 1],
    podcast: [-4, -3, -1, 1, 3, 4, 3, 1, -1, -3],
    loudness: [5, 4, 1, 0, -1, -1, 0, 1, 4, 5]
}

export const PRESET_NAMES = { flat: "Flat", bass: "Bass", treble: "Treble", vocal: "Vocal", rock: "Rock", electronic: "Electronic", acoustic: "Acoustic", podcast: "Podcast", loudness: "Loudness", custom: "Custom" }

export const DEFAULT_EQ = { enabled: false, preset: "flat", bands: PRESETS.flat, spatial: false, spatialLevel: 0.45 }

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v))
}

export function validateEq(raw) {
    const e = raw !== null && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
    const bands = Array.isArray(e.bands) && e.bands.length === BANDS.length && e.bands.every(b => typeof b === "number" && Number.isFinite(b)) ? e.bands.map(b => clamp(Math.round(b * 2) / 2, -LIMIT, LIMIT)) : PRESETS.flat.slice()
    const preset = PRESETS[e.preset] !== undefined || e.preset === "custom" ? e.preset : "flat"
    return Object.assign({}, e, {
        enabled: e.enabled === true,
        preset: preset,
        bands: bands,
        spatial: e.spatial === true,
        spatialLevel: typeof e.spatialLevel === "number" && Number.isFinite(e.spatialLevel) ? clamp(e.spatialLevel, 0.1, 1) : DEFAULT_EQ.spatialLevel
    })
}

export function presetOf(bands) {
    for (const name of Object.keys(PRESETS)) {
        if (PRESETS[name].every((v, i) => v === bands[i]))
            return name
    }
    return "custom"
}

export function preamp(bands) {
    return Math.pow(10, -Math.max(0, ...bands) / 20)
}

function crossGain(eq) {
    return eq.spatial ? eq.spatialLevel * 0.6 : 0
}

export function params(eq) {
    const out = []
    BANDS.forEach((f, i) => {
        out.push("eqL_" + (i + 1) + ":Gain", eq.bands[i])
        out.push("eqR_" + (i + 1) + ":Gain", eq.bands[i])
    })
    const direct = preamp(eq.bands) * (1 - crossGain(eq) * 0.5)
    const cross = preamp(eq.bands) * crossGain(eq)
    out.push("mixL:Gain 1", direct, "mixL:Gain 2", cross, "mixR:Gain 1", direct, "mixR:Gain 2", cross)
    return out
}

export function paramsText(eq) {
    const p = params(eq)
    const parts = []
    for (let i = 0; i < p.length; i += 2)
        parts.push("\"" + p[i] + "\" " + Number(p[i + 1]).toFixed(4))
    return "{ params = [ " + parts.join(" ") + " ] }"
}

function band(side, i, gain) {
    const label = i === 0 ? "bq_lowshelf" : i === BANDS.length - 1 ? "bq_highshelf" : "bq_peaking"
    return "{ type = builtin name = eq" + side + "_" + (i + 1) + " label = " + label + " control = { \"Freq\" = " + BANDS[i].toFixed(1) + " \"Q\" = 1.0 \"Gain\" = " + gain.toFixed(1) + " } }"
}

function quote(s) {
    return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
}

export function config(eq, target) {
    const p = params(eq)
    const gains = {}
    for (let i = 0; i < p.length; i += 2)
        gains[p[i]] = p[i + 1]
    const nodes = []
    const links = []
    for (const side of ["L", "R"]) {
        BANDS.forEach((f, i) => {
            nodes.push(band(side, i, eq.bands[i]))
            if (i > 0)
                links.push("{ output = \"eq" + side + "_" + i + ":Out\" input = \"eq" + side + "_" + (i + 1) + ":In\" }")
        })
        const other = side === "L" ? "R" : "L"
        nodes.push("{ type = builtin name = split" + side + " label = copy }")
        nodes.push("{ type = builtin name = low" + side + " label = bq_lowpass control = { \"Freq\" = " + CROSSFEED.freq.toFixed(1) + " \"Q\" = 0.5 } }")
        nodes.push("{ type = builtin name = delay" + side + " label = delay config = { \"max-delay\" = 0.01 } control = { \"Delay (s)\" = " + CROSSFEED.delay + " } }")
        nodes.push("{ type = builtin name = mix" + side + " label = mixer control = { \"Gain 1\" = " + gains["mix" + side + ":Gain 1"].toFixed(4) + " \"Gain 2\" = " + gains["mix" + side + ":Gain 2"].toFixed(4) + " } }")
        links.push("{ output = \"eq" + side + "_" + BANDS.length + ":Out\" input = \"split" + side + ":In\" }")
        links.push("{ output = \"split" + side + ":Out\" input = \"mix" + side + ":In 1\" }")
        links.push("{ output = \"split" + side + ":Out\" input = \"low" + side + ":In\" }")
        links.push("{ output = \"low" + side + ":Out\" input = \"delay" + side + ":In\" }")
        links.push("{ output = \"delay" + side + ":Out\" input = \"mix" + other + ":In 2\" }")
    }
    return [
        "context.properties = { log.level = 0 }",
        "context.spa-libs = { audio.convert.* = audioconvert/libspa-audioconvert support.* = support/libspa-support }",
        "context.modules = [",
        "  { name = libpipewire-module-protocol-native }",
        "  { name = libpipewire-module-client-node }",
        "  { name = libpipewire-module-adapter }",
        "  { name = libpipewire-module-filter-chain",
        "    args = {",
        "      node.description = \"Sylvaris Equalizer\"",
        "      media.name = \"Sylvaris Equalizer\"",
        "      filter.graph = {",
        "        nodes = [",
        "          " + nodes.join("\n          "),
        "        ]",
        "        links = [",
        "          " + links.join("\n          "),
        "        ]",
        "        inputs = [ \"eqL_1:In\" \"eqR_1:In\" ]",
        "        outputs = [ \"mixL:Out\" \"mixR:Out\" ]",
        "      }",
        "      audio.channels = 2",
        "      audio.position = [ FL FR ]",
        "      capture.props = { node.name = \"sylvaris_eq\" media.class = Audio/Sink }",
        "      playback.props = { node.name = \"sylvaris_eq_out\" node.passive = true state.restore-props = false" + (target ? " target.object = " + quote(target) : "") + " }",
        "    }",
        "  }",
        "]",
        ""
    ].join("\n")
}
