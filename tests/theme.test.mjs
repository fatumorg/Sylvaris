import { test } from "node:test"
import assert from "node:assert/strict"
import { DEFAULT_THEME, COLOR_KEYS, parseHex, withAlpha, validateTheme, tokens, nextThemeId, parseArgb, mixArgb, mixTokens, catalogEntry, linkCommand, parseLinkOutput, shareCommand, staleLinks } from "../shell/lib/theme.mjs"
import { execFileSync } from "node:child_process"
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, readlinkSync, symlinkSync, existsSync, statSync, lstatSync, chmodSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

const warm = {
    id: "warm",
    name: "Warm",
    description: "Warm browns",
    wallpaper: "~/Pictures/warm.png",
    colors: {
        base: "#181310", surface: "#281f1a", accent: "#c9702f", accentHi: "#e0955c",
        accentDeep: "#a85c32", onAccent: "#181310", text: "#e7dac6", textDim: "#b2967b",
        textSoft: "#d3b9a1", danger: "#d9674a"
    },
    alpha: { surface: 0.9, glass: 0.62, line: 0.16, tint: 0.08 }
}

test("parseHex reads six-digit hex colors only", () => {
    assert.deepEqual(parseHex("#a85c32"), { r: 168, g: 92, b: 50 })
    assert.deepEqual(parseHex("#FFFFFF"), { r: 255, g: 255, b: 255 })
    assert.equal(parseHex("#fff"), null)
    assert.equal(parseHex("red"), null)
    assert.equal(parseHex(undefined), null)
})

test("withAlpha produces #aarrggbb and clamps alpha", () => {
    assert.equal(withAlpha("#181310", 0.9), "#e6181310")
    assert.equal(withAlpha("#a85c32", 0.16), "#29a85c32")
    assert.equal(withAlpha("#000000", 2), "#ff000000")
    assert.equal(withAlpha("#000000", -1), "#00000000")
    assert.equal(withAlpha("nope", 0.5), "#00000000")
})

test("validateTheme accepts a complete theme", () => {
    const r = validateTheme(warm)
    assert.equal(r.ok, true)
    assert.deepEqual(r.errors, [])
    assert.equal(r.theme.id, "warm")
    assert.equal(r.theme.wallpaper, "~/Pictures/warm.png")
    assert.equal(r.theme.colors.accent, "#c9702f")
})

test("validateTheme rejects themes without id or name", () => {
    const r = validateTheme({ name: "No id" })
    assert.equal(r.ok, false)
    assert.equal(r.theme.id, DEFAULT_THEME.id)
    assert.equal(validateTheme({ id: "Bad Id", name: "x" }).ok, false)
    assert.equal(validateTheme(null).ok, false)
    assert.equal(validateTheme([1]).ok, false)
})

test("validateTheme falls back per color and reports it", () => {
    const r = validateTheme({ id: "partial", name: "Partial", colors: { accent: "#123456", text: "oops" } })
    assert.equal(r.ok, true)
    assert.equal(r.theme.colors.accent, "#123456")
    assert.equal(r.theme.colors.text, DEFAULT_THEME.colors.text)
    assert.equal(r.theme.colors.base, DEFAULT_THEME.colors.base)
    assert.deepEqual(r.errors, ["invalid color text"])
    for (const key of COLOR_KEYS)
        assert.ok(parseHex(r.theme.colors[key]) !== null)
})

test("validateTheme uses text for a missing textSoft", () => {
    const r = validateTheme({ id: "t", name: "T", colors: { text: "#aabbcc" } })
    assert.equal(r.theme.colors.textSoft, "#aabbcc")
})

test("validateTheme falls back per alpha value", () => {
    const r = validateTheme({ id: "a", name: "A", alpha: { surface: 5, glass: 0.5 } })
    assert.equal(r.theme.alpha.surface, DEFAULT_THEME.alpha.surface)
    assert.equal(r.theme.alpha.glass, 0.5)
    assert.deepEqual(r.errors, ["invalid alpha surface"])
})

test("tokens derive the reference colors", () => {
    const t = tokens(validateTheme(warm).theme)
    assert.equal(t.surface, "#e6181310")
    assert.equal(t.glass, "#9e181310")
    assert.equal(t.node, "#f0281f1a")
    assert.equal(t.line, "#29a85c32")
    assert.equal(t.lineStrong, "#3da85c32")
    assert.equal(t.cardLine, "#24a85c32")
    assert.equal(t.tint, "#14a85c32")
    assert.equal(t.tintSoft, "#0fa85c32")
    assert.equal(t.tintMid, "#1aa85c32")
    assert.equal(t.tintStrong, "#29a85c32")
    assert.equal(t.moon, "#66a85c32")
    assert.equal(t.fill, "#59c9702f")
    assert.equal(t.glow, "#40c9702f")
    assert.equal(t.silk, "#cce0955c")
    assert.equal(t.sonar, "#b3e0955c")
    assert.equal(t.accent, "#c9702f")
    assert.equal(t.textSoft, "#d3b9a1")
})

test("parseArgb reads #aarrggbb and #rrggbb", () => {
    assert.deepEqual(parseArgb("#80a85c32"), { a: 128, r: 168, g: 92, b: 50 })
    assert.deepEqual(parseArgb("#a85c32"), { a: 255, r: 168, g: 92, b: 50 })
    assert.equal(parseArgb("nope"), null)
})

test("mixArgb interpolates every channel and clamps t", () => {
    assert.equal(mixArgb("#ff000000", "#ffffffff", 0.5), "#ff808080")
    assert.equal(mixArgb("#c9702f", "#00000000", 0), "#ffc9702f")
    assert.equal(mixArgb("#ff000000", "#ff102030", 2), "#ff102030")
    assert.equal(mixArgb("bad", "#ff102030", 0), "#ff102030")
    assert.equal(mixArgb("bad", "also bad", 0.5), "#00000000")
})

test("mixTokens mixes every key of the target", () => {
    const out = mixTokens({ a: "#ff000000" }, { a: "#ffffffff", b: "#ff102030" }, 1)
    assert.deepEqual(out, { a: "#ffffffff", b: "#ff102030" })
    assert.equal(mixTokens({ a: "#ff000000" }, { a: "#ffffffff" }, 0).a, "#ff000000")
})

test("nextThemeId cycles through sorted ids", () => {
    assert.equal(nextThemeId(["noir", "dachshund"], "dachshund"), "noir")
    assert.equal(nextThemeId(["noir", "dachshund"], "noir"), "dachshund")
    assert.equal(nextThemeId(["b", "a"], "missing"), "a")
    assert.equal(nextThemeId([], "x"), "")
})

test("tokens expose the opaque surface as pane", () => {
    const t = tokens(validateTheme(warm).theme)
    assert.equal(t.pane, warm.colors.surface)
})

test("catalogEntry uses the theme name and fields", () => {
    const e = catalogEntry("warm", warm)
    assert.equal(e.id, "warm")
    assert.equal(e.name, warm.name)
    assert.equal(e.colors.accent, warm.colors.accent)
})

test("catalogEntry falls back to the id when the name is missing or blank", () => {
    assert.equal(catalogEntry("coal", Object.assign({}, warm, { name: undefined })).name, "coal")
    assert.equal(catalogEntry("coal", Object.assign({}, warm, { name: "  " })).name, "coal")
})

test("catalogEntry survives a broken theme", () => {
    const e = catalogEntry("junk", [1, 2])
    assert.equal(e.name, "junk")
    assert.equal(e.wallpaper, "")
    assert.equal(e.colors.accent, DEFAULT_THEME.colors.accent)
})

test("catalogEntry keeps a nameless theme's own colors", () => {
    const e = catalogEntry("coal", Object.assign({}, warm, { name: undefined, id: undefined }))
    assert.equal(e.colors.accent, warm.colors.accent)
    assert.equal(e.name, "coal")
})

test("validateTheme keeps safe links and reports bad ones", () => {
    const r = validateTheme(Object.assign({}, warm, {
        links: { "kitty/theme.conf": "~/cfg/kitty-warm.conf", "/etc/passwd": "~/x", "../out": "~/x", "a/../../b": "~/x", "rofi/theme.rasi": 3, "": "~/x" }
    }))
    assert.equal(r.ok, true)
    assert.deepEqual(r.theme.links, { "kitty/theme.conf": "~/cfg/kitty-warm.conf" })
    assert.equal(r.errors.filter(e => e.startsWith("invalid link")).length, 5)
    assert.deepEqual(validateTheme(warm).theme.links, {})
    assert.deepEqual(validateTheme(Object.assign({}, warm, { links: [1] })).errors, ["links must be an object"])
})

test("linkCommand relinks only changed targets and reports missing sources", () => {
    const home = mkdtempSync(join(tmpdir(), "syl-links-"))
    const conf = join(home, ".config")
    mkdirSync(join(home, "cfg"))
    writeFileSync(join(home, "cfg", "a"), "a")
    writeFileSync(join(home, "cfg", "b"), "b")
    mkdirSync(join(conf, "app2"), { recursive: true })
    symlinkSync(join(home, "cfg", "b"), join(conf, "app2", "b"))
    const links = { "app/a": "~/cfg/a", "app2/b": "~/cfg/b", "app3/c": "~/cfg/none" }
    const run = () => {
        const argv = linkCommand(links, home, conf)
        return parseLinkOutput(execFileSync(argv[0], argv.slice(1), { encoding: "utf8" }))
    }
    assert.deepEqual(run(), { changed: 1, removed: 0, missing: [join(home, "cfg", "none")], kept: [] })
    assert.equal(readlinkSync(join(conf, "app", "a")), join(home, "cfg", "a"))
    assert.deepEqual(run(), { changed: 0, removed: 0, missing: [join(home, "cfg", "none")], kept: [] })
    assert.deepEqual(linkCommand({}, home, conf), null)
})

test("linkCommand moves a real file aside instead of replacing it, and keeps it when a backup is already there", () => {
    const home = mkdtempSync(join(tmpdir(), "syl-links-"))
    const conf = join(home, ".config")
    mkdirSync(join(home, "cfg"))
    writeFileSync(join(home, "cfg", "a"), "theme")
    mkdirSync(join(conf, "app"), { recursive: true })
    writeFileSync(join(conf, "app", "a"), "mine")
    mkdirSync(join(conf, "dir", "sub"), { recursive: true })
    mkdirSync(join(conf, "other"), { recursive: true })
    writeFileSync(join(conf, "other", "a"), "mine too")
    writeFileSync(join(conf, "other", "a.before-sylvaris"), "older")
    const links = { "app/a": "~/cfg/a", "dir/sub": "~/cfg/a", "other/a": "~/cfg/a" }
    const argv = linkCommand(links, home, conf)
    const r = parseLinkOutput(execFileSync(argv[0], argv.slice(1), { encoding: "utf8" }))
    assert.deepEqual(r, { changed: 2, removed: 0, missing: [], kept: [join(conf, "other", "a")] })
    assert.equal(readlinkSync(join(conf, "app", "a")), join(home, "cfg", "a"))
    assert.equal(readFileSync(join(conf, "app", "a.before-sylvaris"), "utf8"), "mine")
    assert.equal(readlinkSync(join(conf, "dir", "sub")), join(home, "cfg", "a"))
    assert.ok(existsSync(join(conf, "dir", "sub.before-sylvaris")))
    assert.equal(readFileSync(join(conf, "other", "a"), "utf8"), "mine too")
    assert.equal(readFileSync(join(conf, "other", "a.before-sylvaris"), "utf8"), "older")
})

test("parseLinkOutput tolerates junk", () => {
    assert.deepEqual(parseLinkOutput(""), { changed: 0, removed: 0, missing: [], kept: [] })
    assert.deepEqual(parseLinkOutput("noise\nchanged 2\nmissing /x y\nkept /k\n"), { changed: 2, removed: 0, missing: ["/x y"], kept: ["/k"] })
})

test("a theme can name a workspace icon", async () => {
    const { validateTheme } = await import("../shell/lib/theme.mjs")
    assert.equal(validateTheme({ id: "dog", name: "Dog", workspaceIcon: "paw" }).theme.workspaceIcon, "paw")
    assert.equal(validateTheme({ id: "dog", name: "Dog", workspaceIcon: "../x" }).theme.workspaceIcon, "")
    assert.equal(validateTheme({ id: "dog", name: "Dog" }).theme.workspaceIcon, "")
})

test("a theme can carry its own colour for RGB lighting", () => {
    const base = { id: "noir", name: "Noir", colors: { accent: "#e8e8e8" } }
    assert.equal(validateTheme(Object.assign({}, base, { colors: { accent: "#e8e8e8", rgb: "#FFFFFF" } })).theme.colors.rgb, "#ffffff")
    assert.equal(validateTheme(base).theme.colors.rgb, undefined)
    assert.deepEqual(validateTheme(Object.assign({}, base, { colors: { rgb: "white" } })).errors, ["invalid color rgb"])
})

test("shareCommand writes the user's own folder with 755 folders and 644 files", () => {
    const root = mkdtempSync(join(tmpdir(), "syl-share-"))
    chmodSync(root, 0o1755)
    const src = mkdtempSync(join(tmpdir(), "syl-src-"))
    writeFileSync(join(src, "wall.png"), "w")
    writeFileSync(join(src, "face"), "a")
    const argv = shareCommand(root, "ada", "warm", join(src, "wall.png"), join(src, "face"), "{}")
    execFileSync(argv[0], argv.slice(1))
    const d = join(root, "ada")
    assert.equal(readFileSync(join(d, "theme"), "utf8"), "warm")
    assert.equal(readFileSync(join(d, "themes", "warm.json"), "utf8"), "{}")
    assert.equal(readFileSync(join(d, "wallpaper"), "utf8"), "w")
    for (const f of ["", "themes"])
        assert.equal(statSync(join(d, f)).mode & 0o7777, 0o755)
    for (const f of ["theme", "wallpaper", "avatar", "themes/warm.json"])
        assert.equal(statSync(join(d, f)).mode & 0o7777, 0o644)
})

test("shareCommand refuses a symlinked user folder and leaves its target alone", () => {
    const root = mkdtempSync(join(tmpdir(), "syl-share-"))
    chmodSync(root, 0o1755)
    const victim = mkdtempSync(join(tmpdir(), "syl-victim-"))
    writeFileSync(join(victim, "theme"), "mine")
    const mode = statSync(join(victim, "theme")).mode
    symlinkSync(victim, join(root, "ada"))
    const argv = shareCommand(root, "ada", "warm", "/nonexistent", "/nonexistent", "{}")
    assert.throws(() => execFileSync(argv[0], argv.slice(1)))
    assert.equal(readFileSync(join(victim, "theme"), "utf8"), "mine")
    assert.equal(statSync(join(victim, "theme")).mode, mode)
    assert.ok(lstatSync(join(root, "ada")).isSymbolicLink())
})

test("shareCommand writes nothing into a share folder without the sticky bit", () => {
    const root = mkdtempSync(join(tmpdir(), "syl-share-"))
    chmodSync(root, 0o775)
    const argv = shareCommand(root, "ada", "warm", "/nonexistent", "/nonexistent", "{}")
    execFileSync(argv[0], argv.slice(1))
    assert.ok(!existsSync(join(root, "ada")))
})

test("shareCommand skips unsafe names and an empty root", () => {
    assert.equal(shareCommand("", "ada", "warm", "", "", "{}"), null)
    assert.equal(shareCommand("/r", "../x", "warm", "", "", "{}"), null)
    assert.equal(shareCommand("/r", "", "warm", "", "", "{}"), null)
    assert.equal(shareCommand("/r", "ada", "a/b", "", "", "{}"), null)
})

test("catalogEntry keeps the theme's validated links", () => {
    assert.deepEqual(catalogEntry("warm", Object.assign({}, warm, { links: { "kitty/theme.conf": "~/k.conf", "../x": "~/y" } })).links, { "kitty/theme.conf": "~/k.conf" })
    assert.deepEqual(catalogEntry("junk", [1]).links, {})
})

test("staleLinks lists catalog links the new theme lacks", () => {
    const catalog = {
        warm: { links: { "kitty/theme.conf": "~/cfg/warm.conf", "gtk/x": "~/cfg/gx" } },
        cold: { links: { "kitty/theme.conf": "~/cfg/cold.conf" } },
        bare: { links: {} },
        old: {}
    }
    assert.deepEqual(staleLinks(catalog, { "kitty/theme.conf": "~/cfg/cold.conf" }, "/h", "/h/.config"), [["/h/cfg/gx", "/h/.config/gtk/x"]])
    assert.deepEqual(staleLinks(catalog, {}, "/h", "/c"), [["/h/cfg/warm.conf", "/c/kitty/theme.conf"], ["/h/cfg/gx", "/c/gtk/x"], ["/h/cfg/cold.conf", "/c/kitty/theme.conf"]])
})

test("linkCommand removes stale links, restores their backups and leaves foreign links and real files alone", () => {
    const home = mkdtempSync(join(tmpdir(), "syl-links-"))
    const conf = join(home, ".config")
    mkdirSync(join(home, "cfg"))
    writeFileSync(join(home, "cfg", "warm"), "warm")
    mkdirSync(join(conf, "app"), { recursive: true })
    symlinkSync(join(home, "cfg", "warm"), join(conf, "app", "a"))
    writeFileSync(join(conf, "app", "a.before-sylvaris"), "mine")
    symlinkSync(join(home, "elsewhere"), join(conf, "app", "b"))
    writeFileSync(join(conf, "app", "c"), "real")
    const stale = [[join(home, "cfg", "warm"), join(conf, "app", "a")], [join(home, "cfg", "warm"), join(conf, "app", "b")], [join(home, "cfg", "warm"), join(conf, "app", "c")]]
    const argv = linkCommand({}, home, conf, stale)
    const r = parseLinkOutput(execFileSync(argv[0], argv.slice(1), { encoding: "utf8" }))
    assert.equal(r.removed, 1)
    assert.equal(r.changed, 0)
    assert.equal(readFileSync(join(conf, "app", "a"), "utf8"), "mine")
    assert.ok(!existsSync(join(conf, "app", "a.before-sylvaris")))
    assert.equal(readlinkSync(join(conf, "app", "b")), join(home, "elsewhere"))
    assert.equal(readFileSync(join(conf, "app", "c"), "utf8"), "real")
})

test("linkCommand removes a stale link that has no backup", () => {
    const home = mkdtempSync(join(tmpdir(), "syl-links-"))
    const conf = join(home, ".config")
    mkdirSync(join(conf, "app"), { recursive: true })
    symlinkSync(join(home, "gone"), join(conf, "app", "a"))
    const argv = linkCommand({}, home, conf, [[join(home, "gone"), join(conf, "app", "a")]])
    assert.equal(parseLinkOutput(execFileSync(argv[0], argv.slice(1), { encoding: "utf8" })).removed, 1)
    assert.throws(() => lstatSync(join(conf, "app", "a")))
})

test("a theme can name the look it goes with", () => {
    assert.equal(validateTheme(Object.assign({}, warm, { look: "ink" })).theme.look, "ink")
    assert.equal(validateTheme(Object.assign({}, warm, { look: 3 })).theme.look, "")
    assert.equal(validateTheme(Object.assign({}, warm, { look: "../x" })).theme.look, "")
    assert.equal(catalogEntry("warm", Object.assign({}, warm, { look: "neon" })).look, "neon")
})
