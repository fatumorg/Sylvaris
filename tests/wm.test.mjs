import { test } from "node:test"
import assert from "node:assert/strict"
import { translate, niriReduce, niriWorkspaces, bindSnippet, appOf } from "../shell/lib/wm.mjs"

test("Hyprland with a Lua config gets Lua dispatchers", () => {
    assert.deepEqual(translate("hyprland", true, "workspace", ["3"]), { via: "hyprland", command: "hl.dsp.focus({ workspace = 3 })" })
    assert.equal(translate("hyprland", true, "workspace", ["next"]).command, "hl.dsp.focus({ workspace = \"e+1\" })")
    assert.equal(translate("hyprland", true, "move-to", ["2"]).command, "hl.dsp.window.move({ workspace = 2 })")
    assert.equal(translate("hyprland", true, "focus", ["left"]).command, "hl.dsp.focus({ direction = \"left\" })")
    assert.equal(translate("hyprland", true, "float", []).command, "hl.dsp.window.float({ action = \"toggle\" })")
    assert.deepEqual(translate("hyprland", true, "reload", []), { via: "exec", command: ["hyprctl", "reload"] })
})

test("Hyprland with a classic config gets classic dispatchers", () => {
    assert.equal(translate("hyprland", false, "workspace", ["prev"]).command, "workspace e-1")
    assert.equal(translate("hyprland", false, "move", ["up"]).command, "movewindow u")
    assert.equal(translate("hyprland", false, "close", []).command, "killactive")
})

test("sway gets i3 commands", () => {
    assert.deepEqual(translate("sway", false, "workspace", ["4"]), { via: "i3", command: "workspace number 4" })
    assert.equal(translate("sway", false, "move-to", ["next"]).command, "move container to workspace next_on_output")
    assert.equal(translate("sway", false, "fullscreen", []).command, "fullscreen toggle")
})

test("niri gets niri msg actions", () => {
    assert.deepEqual(translate("niri", false, "workspace", ["2"]).command, ["niri", "msg", "action", "focus-workspace", "2"])
    assert.deepEqual(translate("niri", false, "workspace", ["next"]).command, ["niri", "msg", "action", "focus-workspace-down"])
    assert.deepEqual(translate("niri", false, "focus", ["left"]).command, ["niri", "msg", "action", "focus-column-left"])
    assert.deepEqual(translate("niri", false, "move", ["down"]).command, ["niri", "msg", "action", "move-window-down"])
    assert.deepEqual(translate("niri", false, "quit", []).command, ["niri", "msg", "action", "quit", "--skip-confirmation"])
})

test("exec runs through a shell everywhere", () => {
    assert.deepEqual(translate("niri", false, "exec", ["kitty", "--hold"]), { via: "exec", command: ["sh", "-c", "kitty --hold"] })
})

test("bad input is refused with a clear message", () => {
    assert.throws(() => translate("niri", false, "fly", []), /unknown compositor action: fly/)
    assert.throws(() => translate("niri", false, "workspace", ["x"]), /workspace number/)
    assert.throws(() => translate("niri", false, "focus", ["sideways"]), /left, right, up or down/)
    assert.throws(() => translate("unknown", false, "close", []), /no supported compositor/)
    assert.throws(() => translate("sway", false, "exec", []), /usage/)
})

test("the niri reducer follows workspace and window events", () => {
    let s = { workspaces: [], windows: [] }
    s = niriReduce(s, { WorkspacesChanged: { workspaces: [
        { id: 1, idx: 1, name: null, output: "DP-1", is_active: true, is_focused: true, is_urgent: false },
        { id: 2, idx: 2, name: "web", output: "DP-1", is_active: false, is_focused: false, is_urgent: false },
        { id: 3, idx: 1, name: null, output: "HDMI-A-1", is_active: true, is_focused: false, is_urgent: false }
    ] } })
    s = niriReduce(s, { WindowsChanged: { windows: [{ id: 10, workspace_id: 1, is_focused: true }] } })
    s = niriReduce(s, { WindowOpenedOrChanged: { window: { id: 11, workspace_id: 2, is_focused: true } } })
    assert.deepEqual(s.windows.map(w => [w.id, w.is_focused]), [[10, false], [11, true]])
    s = niriReduce(s, { WorkspaceActivated: { id: 2, focused: true } })
    const ws = niriWorkspaces(s)
    assert.deepEqual(ws.map(w => [w.output, w.name, w.active, w.focused, w.windows]), [
        ["DP-1", "1", false, false, 1],
        ["DP-1", "web", true, true, 1],
        ["HDMI-A-1", "1", true, false, 0]
    ])
    s = niriReduce(s, { WindowClosed: { id: 10 } })
    s = niriReduce(s, { WorkspaceUrgencyChanged: { id: 3, urgent: true } })
    assert.equal(niriWorkspaces(s)[0].windows, 0)
    assert.equal(niriWorkspaces(s)[2].urgent, true)
    assert.equal(niriReduce(s, { OverviewOpenedOrClosed: { is_open: true } }), s)
})

test("bindSnippet writes a keybind in each compositor's own syntax", () => {
    assert.equal(bindSnippet("hyprland", true, "A", "sylvaris center"), "hl.bind(mainMod .. \" + A\", hl.dsp.exec_cmd(\"sylvaris center\"))")
    assert.equal(bindSnippet("hyprland", false, "A", "sylvaris center"), "bind = SUPER, A, exec, sylvaris center")
    assert.equal(bindSnippet("niri", false, "A", "sylvaris media open"), "Mod+A { spawn \"sylvaris\" \"media\" \"open\"; }")
    assert.equal(bindSnippet("sway", false, "A", "sylvaris pad"), "bindsym $mod+a exec sylvaris pad")
    assert.equal(bindSnippet("hyprland", true, "XF86AudioPlay", "sylvaris media toggle"), "hl.bind(\"XF86AudioPlay\", hl.dsp.exec_cmd(\"sylvaris media toggle\"))")
    assert.equal(bindSnippet("hyprland", false, "XF86AudioPlay", "sylvaris media toggle"), "bind = , XF86AudioPlay, exec, sylvaris media toggle")
    assert.equal(bindSnippet("niri", false, "XF86AudioPlay", "sylvaris media toggle"), "XF86AudioPlay { spawn \"sylvaris\" \"media\" \"toggle\"; }")
    assert.equal(bindSnippet("sway", false, "XF86AudioPlay", "sylvaris media toggle"), "bindsym XF86AudioPlay exec sylvaris media toggle")
})

test("minimize parks the window where each compositor can bring it back", () => {
    assert.equal(translate("hyprland", true, "minimize", []).command, "hl.dsp.window.move({ workspace = \"special:minimized\", follow = false })")
    assert.equal(translate("hyprland", true, "restore", ["55aa", "3"]).command, "hl.dsp.window.move({ workspace = 3, window = \"address:0x55aa\" })")
    assert.equal(translate("hyprland", false, "restore", ["0x55aa", "2"]).command, "movetoworkspace 2,address:0x55aa")
    assert.equal(translate("hyprland", true, "focus-window", ["0x1"]).command, "hl.dsp.focus({ window = \"address:0x1\" })")
    assert.equal(translate("sway", false, "minimize", []).command, "move scratchpad")
    assert.equal(translate("niri", false, "minimize", []).command, null)
    assert.throws(() => translate("hyprland", true, "restore", ["x; rm", "1"]))
})

test("the capability table matches what each compositor's code path can do", async () => {
    const { CAPABILITIES, COMPOSITORS, can, virtualOutput } = await import("../shell/lib/wm.mjs")
    const { perfArgs } = await import("../shell/lib/perf.mjs")
    const { supports } = await import("../shell/lib/access.mjs")
    const { bindArgs, bindsFile } = await import("../shell/lib/keys.mjs")
    const { rectsCommand } = await import("../shell/lib/capture.mjs")
    assert.deepEqual(COMPOSITORS, ["hyprland", "niri", "sway"])
    for (const name of COMPOSITORS) {
        assert.equal(can(name, "keybinds"), bindArgs(name, false, "SUPER+V", "clip toggle") !== null && bindsFile(name, false, { "clip toggle": "SUPER+V" }) !== "", name)
        assert.equal(can(name, "performance"), perfArgs(name, false, true) !== null, name)
        assert.equal(can(name, "zoom"), supports(name).zoom, name)
        assert.equal(can(name, "filters"), supports(name).filter, name)
        assert.equal(can(name, "minimize"), translate(name, false, "minimize", []).command !== null, name)
        assert.equal(can(name, "windowShot"), rectsCommand(name) !== null, name)
        assert.equal(can(name, "virtualDisplay"), virtualOutput(name, "create", "virtual") !== null, name)
    }
    assert.equal(can("unknown", "keybinds"), false)
    for (const caps of Object.values(CAPABILITIES))
        assert.deepEqual(Object.keys(caps).sort(), Object.keys(CAPABILITIES.hyprland).sort())
})

test("the capability table in docs/compositors.md is generated from lib/wm.mjs", async () => {
    const { capabilityTable } = await import("../shell/lib/wm.mjs")
    const { readFileSync } = await import("node:fs")
    const guide = readFileSync(new URL("../docs/compositors.md", import.meta.url), "utf8")
    const start = guide.indexOf("## What each compositor supports")
    assert.ok(start >= 0, "docs/compositors.md needs a What each compositor supports section")
    const rows = guide.slice(start).split("\n").filter(l => l.startsWith("|"))
    const table = []
    for (const l of rows) {
        if (table.length > 0 && !l.startsWith("|"))
            break
        table.push(l)
    }
    assert.equal(table.slice(0, capabilityTable().split("\n").length).join("\n"), capabilityTable(), "run: node -e 'import(\"./shell/lib/wm.mjs\").then(w => console.log(w.capabilityTable()))'")
})

test("appOf gives Sylvaris windows their own app instead of the shared sylvaris id", () => {
    assert.equal(appOf("sylvaris", "Downloads — SylFiles"), "sylvaris-files")
    assert.equal(appOf("sylvaris", "Open — SylFiles"), "sylvaris-files")
    assert.equal(appOf("Sylvaris", "photos.zip — SylArchive"), "sylvaris-archive")
    assert.equal(appOf("sylvaris", "Something else"), "sylvaris")
    assert.equal(appOf("org.quickshell", "Downloads — SylFiles"), "org.quickshell")
    assert.equal(appOf("kitty", "notes — SylFiles"), "kitty")
    assert.equal(appOf("", undefined), "")
    assert.equal(appOf(undefined, "x — SylFiles"), "")
})

test("niri workspaces name Sylvaris windows by their own app", () => {
    const ws = niriWorkspaces({
        workspaces: [{ id: 1, idx: 1, output: "DP-1", is_active: true, is_focused: true, is_urgent: false }],
        windows: [{ id: 7, workspace_id: 1, app_id: "sylvaris", title: "Home — SylFiles" }, { id: 8, workspace_id: 1, app_id: "kitty", title: "zsh" }]
    })
    assert.deepEqual(ws[0].apps, ["sylvaris-files", "kitty"])
})

test("virtualOutput builds hyprctl calls and rejects odd names", async () => {
    const { virtualOutput } = await import("../shell/lib/wm.mjs")
    assert.deepEqual(virtualOutput("hyprland", "create", "virtual"), ["hyprctl", "output", "create", "headless", "virtual"])
    assert.deepEqual(virtualOutput("hyprland", "remove", "virtual"), ["hyprctl", "output", "remove", "virtual"])
    assert.equal(virtualOutput("niri", "create", "virtual"), null)
    assert.throws(() => virtualOutput("hyprland", "create", "x y"))
    assert.throws(() => virtualOutput("hyprland", "boom", "virtual"))
})
