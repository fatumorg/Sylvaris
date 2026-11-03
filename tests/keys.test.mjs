import { test } from "node:test"
import assert from "node:assert/strict"
import { ACTIONS, normalize, validateKeybinds, bindArgs, unbindArgs, keyName, diff, actionFor, parseLuaBinds, parseHyprBinds, parseSwayBinds, externalBinds, bindsFile, bindsPath, includeLine } from "../shell/lib/keys.mjs"

test("normalize orders modifiers and cleans the key", () => {
    assert.equal(normalize("shift+super+s"), "SUPER+SHIFT+S")
    assert.equal(normalize("SUPER + space"), "SUPER+space")
    assert.equal(normalize("ctrl+alt+Delete"), "CTRL+ALT+Delete")
    assert.equal(normalize("SUPER+"), "")
    assert.equal(normalize("SUPER+SHIFT"), "")
    assert.equal(normalize("SUPER+a;rm -rf"), "")
})

test("validateKeybinds keeps known actions with valid keys", () => {
    assert.deepEqual(validateKeybinds({ "clip toggle": "super+v", "rm -rf": "SUPER+X", "lock now": "bad key!" }), { "clip toggle": "SUPER+V" })
    assert.deepEqual(validateKeybinds(null), {})
    assert.ok(ACTIONS.every(a => a.id && a.label))
})

test("bindArgs and unbindArgs speak Hyprland Lua, classic Hyprland and sway", () => {
    assert.deepEqual(bindArgs("hyprland", true, "SUPER+SHIFT+S", "capture shot area"), ["hyprctl", "eval", "pcall(hl.unbind, \"SUPER + SHIFT + S\") hl.bind(\"SUPER + SHIFT + S\", hl.dsp.exec_cmd(\"sylvaris capture shot area\"))"])
    assert.deepEqual(unbindArgs("hyprland", true, "SUPER+SHIFT+S"), ["hyprctl", "eval", "hl.unbind(\"SUPER + SHIFT + S\")"])
    assert.deepEqual(bindArgs("hyprland", false, "SUPER+V", "clip toggle"), ["hyprctl", "keyword", "bind", "SUPER,V,exec,sylvaris clip toggle"])
    assert.deepEqual(unbindArgs("hyprland", false, "CTRL+ALT+L"), ["hyprctl", "keyword", "unbind", "CTRL ALT,L"])
    assert.deepEqual(bindArgs("sway", false, "SUPER+SHIFT+S", "capture shot area"), ["swaymsg", "bindsym", "Mod4+Shift+s", "exec", "sylvaris capture shot area"])
    assert.deepEqual(unbindArgs("sway", false, "ALT+Tab"), ["swaymsg", "unbindsym", "Mod1+Tab"])
    assert.equal(bindArgs("niri", false, "SUPER+V", "clip toggle"), null)
})

test("keyName turns key events into key names", () => {
    assert.equal(keyName(0x56, "v"), "V")
    assert.equal(keyName(0x01000000, ""), "Escape")
    assert.equal(validateKeybinds({ "top toggle": "ctrl+shift+Escape" })["top toggle"], "CTRL+SHIFT+Escape")
    assert.equal(keyName(0x20, " "), "space")
    assert.equal(keyName(0x01000004, "\r"), "Return")
    assert.equal(keyName(0x01000001, "\t"), "Tab")
    assert.equal(keyName(0x01000030, ""), "F1")
    assert.equal(keyName(0x0100003b, ""), "F12")
    assert.equal(keyName(0x01000009, ""), "Print")
    assert.equal(keyName(0x01000012, ""), "Left")
    assert.equal(keyName(0x01000021, ""), "")
})

test("diff says what to unbind and bind", () => {
    assert.deepEqual(diff({ a: "SUPER+A", b: "SUPER+B" }, { a: "SUPER+A", b: "SUPER+C", c: "SUPER+D" }), {
        unbind: ["SUPER+B"],
        bind: [["SUPER+C", "b"], ["SUPER+D", "c"]]
    })
    assert.deepEqual(diff({ a: "SUPER+A" }, {}), { unbind: ["SUPER+A"], bind: [] })
})

test("binds written in a compositor config show up as Sylvaris actions", () => {
    assert.equal(actionFor("sylvaris clip toggle"), "clip toggle")
    assert.equal(actionFor("/usr/bin/sylvaris lock"), "lock now")
    assert.equal(actionFor("sylvaris pad"), "pad toggle")
    assert.equal(actionFor("kitty"), "")
    const lua = [
        "local mainMod = \"SUPER\"",
        "local menu    = \"sylvaris pad\"",
        "-- hl.bind(mainMod .. \" + X\", hl.dsp.exec_cmd(\"sylvaris power\"))",
        "hl.bind(mainMod .. \" + Space\", hl.dsp.exec_cmd(menu))",
        "hl.bind(mainMod .. \" + SHIFT + L\", hl.dsp.exec_cmd(\"sylvaris power\"))",
        "hl.bind(\"ALT + Tab\", hl.dsp.exec_cmd(\"sylvaris switcher next\"))",
        "hl.bind(mainMod .. \" + Q\", hl.dsp.window.close())"
    ].join("\n")
    assert.deepEqual(externalBinds(parseLuaBinds(lua)), { "pad toggle": "SUPER+Space", "power toggle": "SUPER+SHIFT+L", "switcher next": "ALT+Tab" })
    assert.deepEqual(parseHyprBinds([{ modmask: 65, key: "V", dispatcher: "exec", arg: "sylvaris clip toggle" }, { modmask: 64, key: "Q", dispatcher: "killactive", arg: "" }]), [{ combo: "SUPER+SHIFT+V", command: "sylvaris clip toggle" }])
    assert.deepEqual(parseSwayBinds("set $mod Mod4\nbindsym $mod+shift+l exec sylvaris power\nbindsym --no-warn Mod1+Tab exec \"sylvaris switcher next\""), [{ combo: "SUPER+SHIFT+L", command: "sylvaris power" }, { combo: "ALT+Tab", command: "sylvaris switcher next" }])
})

test("Sylvaris writes its own binds into a file the compositor config includes", () => {
    const w = { "clip toggle": "SUPER+V", "capture shot area": "SUPER+SHIFT+S" }
    assert.equal(bindsFile("hyprland", true, w), "pcall(hl.unbind, \"SUPER + SHIFT + S\")\nhl.bind(\"SUPER + SHIFT + S\", hl.dsp.exec_cmd(\"sylvaris capture shot area\"))\npcall(hl.unbind, \"SUPER + V\")\nhl.bind(\"SUPER + V\", hl.dsp.exec_cmd(\"sylvaris clip toggle\"))\n")
    assert.ok(bindsFile("hyprland", false, w).includes("bind = SUPER, V, exec, sylvaris clip toggle"))
    assert.ok(bindsFile("sway", false, w).includes("bindsym --no-warn Mod4+v exec sylvaris clip toggle"))
    assert.equal(bindsPath("hyprland", true, "/c"), "/c/hypr/sylvaris-keybinds.lua")
    assert.equal(includeLine("hyprland", true), "pcall(require, \"sylvaris-keybinds\")")
    assert.equal(bindsPath("niri", false, "/c"), "")
})
