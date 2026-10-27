import { test } from "node:test"
import assert from "node:assert/strict"
import { checkManifest, parseScan, skeleton, validatePlugins, DEFAULT_PLUGINS, isPluginModule, KINDS, parseGitSource, readCommit, pendingSummary, INSTALL_WARNING, BUILTIN, builtinOn, withBuiltins } from "../shell/lib/plugins.mjs"
import { validateBar } from "../shell/lib/bar.mjs"

const good = { id: "uptime", name: "Uptime", version: "1.0.0", kind: "bar", entry: "Plugin.qml", description: "Shows uptime", author: "ada" }

test("checkManifest accepts a clean manifest and explains what is wrong otherwise", () => {
    assert.deepEqual(checkManifest(good, "uptime"), { ok: true, error: "", manifest: good })
    assert.equal(checkManifest(Object.assign({}, good, { id: "Up Time" }), "uptime").error, "id must be lowercase letters, digits and dashes")
    assert.equal(checkManifest(good, "other").error, "id uptime does not match its folder other")
    assert.equal(checkManifest(Object.assign({}, good, { kind: "rootkit" }), "uptime").error, "kind must be one of " + KINDS.join(", "))
    assert.equal(checkManifest(Object.assign({}, good, { entry: "../../x.qml" }), "uptime").error, "entry must be a .qml file inside the plugin folder")
    assert.equal(checkManifest(Object.assign({}, good, { entry: "/etc/x.qml" }), "uptime").error, "entry must be a .qml file inside the plugin folder")
    assert.equal(checkManifest(Object.assign({}, good, { name: "" }), "uptime").error, "name is required")
    assert.equal(checkManifest("nope", "uptime").error, "plugin.json must be an object")
})

test("parseScan reads the plugin folder listing", () => {
    const blob = "@@/p/uptime\n" + JSON.stringify(good) + "\n@@/p/broken\n{not json\n@@/p/empty\n"
    const list = parseScan(blob)
    assert.equal(list.length, 3)
    assert.equal(list[0].ok, true)
    assert.equal(list[0].dir, "/p/uptime")
    assert.equal(list[1].error, "plugin.json is not valid JSON")
    assert.equal(list[2].error, "plugin.json is missing")
})

test("skeleton makes a working starter plugin", () => {
    const files = skeleton("my-widget", "bar")
    assert.match(files["Plugin.qml"], /textFormat: Text\.PlainText/)
    assert.equal(JSON.parse(files["plugin.json"]).id, "my-widget")
    assert.ok(files["Plugin.qml"].indexOf("property var api") >= 0)
    assert.equal(checkManifest(JSON.parse(files["plugin.json"]), "my-widget").ok, true)
})

test("plugins settings and bar modules", () => {
    assert.deepEqual(validatePlugins({}), DEFAULT_PLUGINS)
    assert.deepEqual(validatePlugins({ enabled: { uptime: true, "Bad!": true, x: "yes" } }).enabled, { uptime: true })
    assert.equal(isPluginModule("plugin:uptime"), true)
    assert.equal(isPluginModule("plugin:../x"), false)
    assert.deepEqual(validateBar({ left: ["pad", "plugin:uptime", "plugin:Bad!"] }).left, ["pad", "plugin:uptime"])
})

test("parseGitSource takes https git addresses whose last part is the plugin id", () => {
    assert.deepEqual(parseGitSource("https://github.com/ada/uptime"), { id: "uptime", url: "https://github.com/ada/uptime" })
    assert.deepEqual(parseGitSource("https://git.example.org/a/b/uptime.git/"), { id: "uptime", url: "https://git.example.org/a/b/uptime.git/" })
    assert.equal(parseGitSource("http://github.com/ada/uptime"), null)
    assert.equal(parseGitSource("https://github.com/ada/Up Time"), null)
    assert.equal(parseGitSource("https://github.com/ada/uptime; rm -rf ~"), null)
    assert.equal(parseGitSource("--upload-pack=x"), null)
    assert.equal(parseGitSource(undefined), null)
})

test("readCommit only accepts a full commit hash", () => {
    assert.equal(readCommit("0123456789abcdef0123456789abcdef01234567\n"), "0123456789abcdef0123456789abcdef01234567")
    assert.equal(readCommit("fatal: not a git repository"), "")
    assert.equal(readCommit("0123456"), "")
    assert.equal(readCommit(""), "")
})

test("pendingSummary names the commit and warns about permissions", () => {
    const text = pendingSummary({ id: "uptime", url: "https://github.com/ada/uptime", commit: "0123456789abcdef0123456789abcdef01234567" })
    assert.match(text, /uptime/)
    assert.match(text, /0123456789abcdef0123456789abcdef01234567/)
    assert.ok(text.indexOf(INSTALL_WARNING) >= 0)
    assert.match(INSTALL_WARNING, /full user permissions/)
    assert.match(text, /sylvaris plugins confirm/)
    assert.equal(pendingSummary(null), "")
})

test("Diver, AirPods, FaTest, Keep Awake and SylRGB ship as built-in plugins that are off until turned on", () => {
    assert.deepEqual(BUILTIN.map(p => p.id), ["diver", "airpods", "fatest", "awake", "rgb"])
    for (const p of BUILTIN) {
        assert.equal(p.kind, "builtin")
        assert.ok(p.name !== "" && p.description !== "")
        assert.equal(builtinOn(DEFAULT_PLUGINS, p.id), false)
        assert.equal(builtinOn(validatePlugins({}), p.id), false)
        assert.equal(builtinOn(validatePlugins({ enabled: { [p.id]: true } }), p.id), true)
    }
    assert.equal(builtinOn(undefined, "diver"), false)
    assert.equal(builtinOn({ enabled: { diver: "yes" } }, "diver"), false)
    const scanned = parseScan("@@/p/diver/\n" + JSON.stringify(Object.assign({}, good, { id: "diver" })))
    assert.equal(withBuiltins(scanned).filter(p => p.id === "diver").length, 1)
    assert.equal(withBuiltins(scanned).find(p => p.id === "diver").builtin, true)
    assert.equal(withBuiltins([]).every(p => p.ok && p.builtin), true)
})
