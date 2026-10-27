import { test } from "node:test"
import assert from "node:assert/strict"
import { parsePasswd, parseSessions, pick, splitExec } from "../shell/lib/greet.mjs"

test("parsePasswd keeps people who can log in", () => {
    const text = [
        "root:x:0:0:System administrator:/root:/run/current-system/sw/bin/bash",
        "naxce:x:1000:100:Naxce Hell:/home/naxce:/run/current-system/sw/bin/zsh",
        "guest:x:1001:100::/home/guest:/run/current-system/sw/bin/bash",
        "nobody:x:65534:65534:Unprivileged account:/var/empty:/run/current-system/sw/bin/nologin",
        "svc:x:1002:100::/var/empty:/bin/false",
        "broken line"
    ].join("\n")
    assert.deepEqual(parsePasswd(text), [
        { name: "naxce", real: "Naxce Hell", home: "/home/naxce", uid: 1000 },
        { name: "guest", real: "guest", home: "/home/guest", uid: 1001 }
    ])
})

test("parseSessions reads name and command from desktop files and skips hidden ones", () => {
    const blob = [
        "@@/share/wayland-sessions/hyprland.desktop",
        "[Desktop Entry]",
        "Name=Hyprland",
        "Exec=Hyprland",
        "Type=Application",
        "@@/share/wayland-sessions/niri.desktop",
        "[Desktop Entry]",
        "Name=Niri",
        "Name[pl]=Niri PL",
        "Exec=niri-session",
        "@@/share/wayland-sessions/old.desktop",
        "[Desktop Entry]",
        "Name=Old",
        "Exec=old",
        "Hidden=true",
        "@@/share/wayland-sessions/hyprland.desktop",
        "[Desktop Entry]",
        "Name=Hyprland",
        "Exec=Hyprland"
    ].join("\n")
    assert.deepEqual(parseSessions(blob), [
        { id: "hyprland", name: "Hyprland", exec: "Hyprland" },
        { id: "niri", name: "Niri", exec: "niri-session" }
    ])
})

test("pick prefers the remembered value, then the default, then the first", () => {
    const list = [{ id: "a" }, { id: "b" }, { id: "c" }]
    assert.equal(pick(list, "c", "b"), 2)
    assert.equal(pick(list, "x", "b"), 1)
    assert.equal(pick(list, "", ""), 0)
    assert.equal(pick([], "a", "b"), -1)
})

test("splitExec drops field codes and keeps quoted words", () => {
    assert.deepEqual(splitExec("Hyprland"), ["Hyprland"])
    assert.deepEqual(splitExec("sway --unsupported-gpu %U"), ["sway", "--unsupported-gpu"])
    assert.deepEqual(splitExec("env \"A B\" run"), ["env", "A B", "run"])
})
