import { test } from "node:test"
import assert from "node:assert/strict"
import { palette, summary, ansi, gtkCss, kittyConf, footIni, qtColors, vscodeTheme, zedTheme, nvimLua, vimColors, firefoxCss, firefoxContentCss, zenColours, plan, TARGETS, DEFAULT_SYNC, validateSync } from "../shell/lib/sync.mjs"

const colors = { base: "#181310", surface: "#281f1a", accent: "#c9702f", accentHi: "#e0955c", accentDeep: "#a85c32", onAccent: "#181310", text: "#e7dac6", textDim: "#b2967b", textSoft: "#d3b9a1", danger: "#d9674a" }

test("ansi gives 16 distinct hex colours, dark first and light last", () => {
    const a = ansi(palette(colors))
    assert.equal(a.length, 16)
    assert.ok(a.every(c => /^#[0-9a-f]{6}$/.test(c)))
    assert.equal(a[0], "#181310")
    assert.equal(a[15], "#e7dac6")
    assert.equal(new Set(a).size, 16)
})

test("generators use the palette", () => {
    const p = palette(colors)
    assert.ok(gtkCss(p).includes("@define-color accent_bg_color #c9702f;"))
    assert.ok(kittyConf(p).includes("background #181310"))
    assert.ok(footIni(p).includes("background=181310"))
    assert.ok(qtColors(p).startsWith("[ColorScheme]\nactive_colors=#ffe7dac6"))
    assert.equal(vscodeTheme(p).colors["editor.background"], "#181310")
    assert.equal(vscodeTheme(p).tokenColors[0].scope[0], "comment")
    assert.equal(JSON.parse(zedTheme(p)).themes[0].style.background, "#181310ff")
    assert.ok(nvimLua(p).includes("vim.g.colors_name = \"sylvaris\""))
    assert.ok(vimColors(p).includes("let g:colors_name = \"sylvaris\""))
    assert.ok(firefoxCss(p).includes("--toolbar-bgcolor: #281f1a !important;"))
    assert.ok(firefoxCss(p).includes("#urlbar[focused] #urlbar-background"))
    assert.ok(firefoxContentCss(p).startsWith("@-moz-document url-prefix(\"about:newtab\")"))
})

test("plan writes only the chosen targets and asks for include lines", () => {
    const ops = plan(palette(colors), { gtk: true, kitty: true, zed: false }, "/h/.config", "/h")
    const paths = ops.filter(o => o.path).map(o => o.path)
    assert.ok(paths.includes("/h/.config/gtk-3.0/sylvaris.css"))
    assert.ok(paths.includes("/h/.config/gtk-4.0/sylvaris.css"))
    assert.ok(paths.includes("/h/.config/kitty/sylvaris.conf"))
    assert.ok(!paths.some(p => p.includes("zed")))
    const include = ops.find(o => o.op === "line" && o.path === "/h/.config/gtk-3.0/gtk.css")
    assert.equal(include.line, "@import 'sylvaris.css';")
    assert.ok(ops.filter(o => o.op === "write").every(o => typeof o.content === "string" && o.needs))
    const code = plan(palette(colors), { vscode: true, firefox: true }, "/h/.config", "/h")
    assert.ok(code.find(o => o.op === "vscode").dirs.includes("/h/.config/VSCodium/User"))
    assert.equal(code.find(o => o.op === "firefox").roots[0], "/h/.config/mozilla/firefox")
    assert.ok(!code.some(o => o.roots && o.roots.some(r => r.includes("zen"))))
})

test("Zen is its own target that hands Zen its own gradient colours", () => {
    const p = palette(colors)
    assert.deepEqual(JSON.parse(zenColours(p)), { gradient: ["#c9702f", "#a85c32"] })
    const zen = plan(p, { zen: true }, "/h/.config", "/h").filter(o => o.target === "zen")
    assert.equal(zen.length, 1)
    assert.equal(zen[0].op, "firefox")
    assert.deepEqual(zen[0].roots, ["/h/.config/zen", "/h/.zen"])
    assert.equal(zen[0].json, zenColours(p))
    assert.equal(zen[0].content, undefined)
    assert.equal(plan(p, { firefox: true }, "/h/.config", "/h").some(o => o.target === "zen"), false)
    assert.equal(validateSync({ targets: { firefox: true } }).targets.zen, true)
    assert.equal(validateSync({ targets: { firefox: true, zen: false } }).targets.zen, false)
    assert.equal(validateSync({}).targets.zen, false)
})

test("validateSync is off by default and keeps known targets", () => {
    assert.deepEqual(validateSync({}), DEFAULT_SYNC)
    assert.equal(validateSync({ enabled: true }).enabled, true)
    assert.equal(validateSync({ targets: { gtk: false, bogus: true } }).targets.gtk, false)
    assert.equal("bogus" in validateSync({ targets: { bogus: true } }).targets, false)
    assert.deepEqual(Object.keys(DEFAULT_SYNC.targets), TARGETS.map(t => t.id))
})

test("summary says how each app did", () => {
    const r = [{ target: "vscode", status: "skipped, /h/.vscode does not exist" }, { target: "vscode", status: "written" }, { target: "qt", status: "skipped, x" }, { target: "kitty", status: "add this line yourself: include sylvaris.conf" }]
    assert.equal(summary(r, "vscode"), "Up to date")
    assert.equal(summary(r, "qt"), "Not installed")
    assert.equal(summary(r, "kitty"), "Add this line yourself: include sylvaris.conf")
    assert.equal(summary(r, "zed"), "")
})
