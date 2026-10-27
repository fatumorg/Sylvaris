import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { PART_PACKAGES, PACKAGE_BINS, CORE_BINS, FONTS, allBins, missingTools, missingFonts, gpuName, problems, report, parseFacts } from "../shell/lib/doctor.mjs"
import { PARTS } from "../shell/lib/settings.mjs"

test("PART_PACKAGES matches partTools in nix/package.nix", () => {
    const nix = readFileSync(new URL("../nix/package.nix", import.meta.url), "utf8")
    const block = nix.slice(nix.indexOf("partTools = {"), nix.indexOf("};", nix.indexOf("partTools = {")))
    const parsed = {}
    for (const m of block.matchAll(/^\s{4}([a-z]+) = \[([^\]]*)\];/gm))
        parsed[m[1]] = m[2].split(/\s+/).filter(s => s !== "")
    assert.deepEqual(parsed, PART_PACKAGES)
    assert.deepEqual(Object.keys(PART_PACKAGES).sort(), Object.keys(PARTS).sort())
})

test("every package a part needs names the programs to look for", () => {
    for (const pkgs of Object.values(PART_PACKAGES))
        for (const p of pkgs)
            assert.ok(Array.isArray(PACKAGE_BINS[p]) && PACKAGE_BINS[p].length > 0, p)
    assert.ok(allBins().includes("sylstack") && allBins().includes("grim"))
    assert.equal(new Set(allBins()).size, allBins().length)
    assert.deepEqual(CORE_BINS, ["sylstack"])
})

test("missingTools lists only enabled parts with absent programs", () => {
    const present = allBins().filter(b => b !== "wf-recorder" && b !== "gdbus")
    assert.deepEqual(missingTools(["capture", "lock", "pad"], present), { capture: ["wf-recorder"], lock: ["gdbus"] })
    assert.deepEqual(missingTools(["pad"], []), { core: ["sylstack"] })
    assert.deepEqual(missingTools(["capture"], allBins()), {})
})

test("gpuName names the common vendors and falls back to the id", () => {
    assert.equal(gpuName("0x10de", "nvidia"), "NVIDIA (nvidia)")
    assert.equal(gpuName("0x1002", "amdgpu"), "AMD (amdgpu)")
    assert.equal(gpuName("0x8086", "i915"), "Intel (i915)")
    assert.equal(gpuName("0x1234", ""), "0x1234 (no driver)")
})

test("problems reports values the validator replaced or dropped", () => {
    assert.deepEqual(problems({ a: 1, b: { c: 2 } }, { a: 1, b: { c: 2 } }), [])
    assert.deepEqual(problems({ a: "x", b: { c: 9, d: 1 } }, { a: 1, b: { c: 2, d: 1 } }), ["a: \"x\" is not valid, using 1", "b.c: 9 is not valid, using 2"])
    assert.deepEqual(problems({ cc: {} }, {}), ["cc: not used"])
    assert.deepEqual(problems({ t: [{ id: "a" }] }, { t: [{ id: "a", status: "" }] }), [])
    assert.deepEqual(problems({ t: [{ id: "a" }, { id: 5 }] }, { t: [{ id: "a", status: "" }] }), ["t: 1 of 2 entries not valid"])
    assert.deepEqual(problems({ t: [1, 2] }, { t: [1, 3] }), ["t: [1,2] is not valid, using [1,3]"])
})

const facts = {
    version: "1.0.1",
    commit: "abc1234",
    sylstack: "SylStack 1.0.0 (Qt 6.11.2)",
    compositor: "hyprland 0.51.0",
    gpus: [{ vendor: "0x10de", driver: "nvidia" }],
    present: allBins().filter(b => b !== "grim"),
    config: { path: "/c/config.json", text: "{\"notifications\":{\"history\":5000}}" },
    settings: { path: "/c/settings.json", text: "{\"parts\":{\"diver\":false}}" }
}

test("report covers versions, parts, tools and both files", () => {
    const r = report(facts)
    assert.match(r, /^Sylvaris 1\.0\.1 \(commit abc1234\)$/m)
    assert.match(r, /^SylStack: SylStack 1\.0\.0 \(Qt 6\.11\.2\)$/m)
    assert.match(r, /^Compositor: hyprland 0\.51\.0$/m)
    assert.match(r, /^GPU: NVIDIA \(nvidia\)$/m)
    assert.match(r, /^Parts off: diver, island$/m)
    assert.match(r, /^Parts on: .*capture/m)
    assert.match(r, /^ {2}capture: grim$/m)
    assert.match(r, /^config\.json \(\/c\/config\.json\): 1 problem$/m)
    assert.match(r, /notifications\.history: 5000 is not valid, using 100/)
    assert.match(r, /^settings\.json \(\/c\/settings\.json\): ok$/m)
})

test("report handles missing and broken files", () => {
    const r = report(Object.assign({}, facts, { present: allBins(), config: { path: "/c/config.json", text: null }, settings: { path: "/c/settings.json", text: "{nope" } }))
    assert.match(r, /^config\.json \(\/c\/config\.json\): not found, defaults in use$/m)
    assert.match(r, /^settings\.json \(\/c\/settings\.json\): not valid JSON/m)
    assert.match(r, /^Missing tools: none$/m)
})

test("report shows a file from a newer Sylvaris as refused", () => {
    const r = report(Object.assign({}, facts, { settings: { path: "/c/settings.json", text: "{\"version\":42}" } }))
    assert.match(r, /^settings\.json \(\/c\/settings\.json\): settings\.json is version 42 but this Sylvaris understands up to version 1/m)
})

test("parseFacts reads the gathering script's key=value lines", () => {
    const f = parseFacts("sylstack=SylStack 1.0.0 (Qt 6.11.2)\ncompositor=hyprland v0.51.0\ngpu=0x10de nvidia\ngpu=0x8086 \nbin=sylstack\nbin=grim\ncommit=abc1234\npam=hyprlock\npam=login\nnoise\n")
    assert.deepEqual(f, {
        sylstack: "SylStack 1.0.0 (Qt 6.11.2)",
        compositor: "hyprland v0.51.0",
        commit: "abc1234",
        gpus: [{ vendor: "0x10de", driver: "nvidia" }, { vendor: "0x8086", driver: "" }],
        present: ["sylstack", "grim"],
        pams: ["hyprlock", "login"]
    })
    assert.deepEqual(parseFacts(""), { sylstack: "", compositor: "", commit: "", gpus: [], present: [], pams: [] })
})

test("the version in lib/version.mjs matches nix/package.nix", async () => {
    const { VERSION } = await import("../shell/lib/version.mjs")
    const nix = readFileSync(new URL("../nix/package.nix", import.meta.url), "utf8")
    assert.equal(/version = "([^"]+)";/.exec(nix)[1], VERSION)
})

test("missingFonts names the fonts Qt cannot find", () => {
    assert.deepEqual(FONTS, ["Inter", "JetBrainsMono Nerd Font"])
    assert.deepEqual(missingFonts(["DejaVu Sans", "Inter"]), ["JetBrainsMono Nerd Font"])
    assert.deepEqual(missingFonts(["inter", "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font"]), [])
})

test("report lists missing fonts only when the families are known", () => {
    assert.match(report(Object.assign({}, facts, { fonts: ["Inter"] })), /^Missing fonts: JetBrainsMono Nerd Font \(icons show as empty boxes\)$/m)
    assert.match(report(Object.assign({}, facts, { fonts: ["Inter", "JetBrainsMono Nerd Font"] })), /^Missing fonts: none$/m)
    assert.doesNotMatch(report(facts), /Missing fonts/)
})

test("report names the lock's PAM service and how to install sylvaris when it falls back to login", () => {
    assert.match(report(Object.assign({}, facts, { pams: ["sylvaris", "login"] })), /^Lock PAM service: sylvaris$/m)
    assert.doesNotMatch(report(Object.assign({}, facts, { pams: ["hyprlock", "login"] })), /install-pam/)
    const r = report(Object.assign({}, facts, { pams: ["login"] }))
    assert.match(r, /^Lock PAM service: login$/m)
    assert.match(r, /programs\.sylvaris\.lock\.enable/)
    assert.match(r, /sudo make install-pam/)
    assert.match(report(Object.assign({}, facts, { pams: [], settings: { path: "/c/settings.json", text: "{\"lock\":{\"pam\":\"swaylock\"}}" } })), /^Lock PAM service: swaylock$/m)
})
