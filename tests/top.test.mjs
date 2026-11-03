import { test } from "node:test"
import assert from "node:assert/strict"
import { COLUMNS, sortProcs, filterProcs, tree, push, DEFAULT_TOP, validateTop, PAGES, toggled } from "../shell/lib/top.mjs"

const procs = [
    { pid: 1, ppid: 0, name: "init", cmd: "/sbin/init", user: "root", cpu: 0, mem: 10, threads: 1, nice: 0, state: "S" },
    { pid: 20, ppid: 1, name: "Hyprland", cmd: "Hyprland", user: "me", cpu: 7, mem: 300, threads: 7, nice: 0, state: "S" },
    { pid: 30, ppid: 20, name: "firefox", cmd: "/usr/bin/firefox", user: "me", cpu: 9, mem: 900, threads: 80, nice: 0, state: "R" },
    { pid: 31, ppid: 30, name: "Web Content", cmd: "/usr/bin/firefox -contentproc", user: "me", cpu: 2, mem: 400, threads: 20, nice: 0, state: "S" },
    { pid: 40, ppid: 20, name: "alacritty", cmd: "alacritty", user: "me", cpu: 9, mem: 50, threads: 4, nice: 5, state: "S" },
    { pid: 99, ppid: 777, name: "orphan", cmd: "orphan", user: "nobody", cpu: 0, mem: 1, threads: 1, nice: 19, state: "Z" }
]

test("every column names a field the helper sends", () => {
    for (const c of COLUMNS)
        assert.ok(c.key in procs[0], c.key)
})

test("sortProcs sorts numbers and names either way and breaks ties by pid", () => {
    assert.deepEqual(sortProcs(procs, "cpu", true).map(p => p.pid), [30, 40, 20, 31, 1, 99])
    assert.deepEqual(sortProcs(procs, "name", false).map(p => p.name), ["alacritty", "firefox", "Hyprland", "init", "orphan", "Web Content"])
    assert.deepEqual(sortProcs(procs, "bogus", true).map(p => p.pid), sortProcs(procs, "cpu", true).map(p => p.pid))
    assert.equal(procs[0].pid, 1)
})

test("filterProcs needs every word to match a name, command, user or pid", () => {
    assert.deepEqual(filterProcs(procs, "fire").map(p => p.pid), [30, 31])
    assert.deepEqual(filterProcs(procs, "firefox content").map(p => p.pid), [31])
    assert.deepEqual(filterProcs(procs, "ROOT").map(p => p.pid), [1])
    assert.deepEqual(filterProcs(procs, "40").map(p => p.pid), [40])
    assert.equal(filterProcs(procs, "  ").length, procs.length)
})

test("tree nests children under parents in sort order and folds on request", () => {
    const rows = tree(procs, "cpu", true, [])
    assert.deepEqual(rows.map(r => [r.pid, r.depth, r.kids]), [[1, 0, 1], [20, 1, 2], [30, 2, 1], [31, 3, 0], [40, 2, 0], [99, 0, 0]])
    assert.deepEqual(tree(procs, "cpu", true, [20]).map(r => r.pid), [1, 20, 99])
})

test("tree survives a parent loop", () => {
    const loop = [{ pid: 5, ppid: 6, name: "a", cpu: 0 }, { pid: 6, ppid: 5, name: "b", cpu: 0 }]
    assert.deepEqual(tree(loop, "pid", false, []).map(r => r.pid).sort(), [5, 6])
})

test("push keeps the newest values up to the limit", () => {
    assert.deepEqual(push([1, 2, 3], 4, 3), [2, 3, 4])
    assert.deepEqual(push(undefined, 1, 3), [1])
})

test("validateTop keeps a sane interval and the tree switch", () => {
    assert.deepEqual(validateTop(null), DEFAULT_TOP)
    assert.deepEqual(validateTop({ interval: 1.3, tree: true }), { interval: 1.5, tree: true })
    assert.equal(validateTop({ interval: 0.2 }).interval, 2)
    assert.equal(validateTop({ interval: "3" }).interval, 2)
    assert.equal(validateTop({ tree: "yes" }).tree, false)
})

test("every page has a label and a glyph", () => {
    assert.deepEqual(PAGES.map(p => p.id), ["processes", "performance", "startup", "services", "users"])
})

test("toggled adds a missing value and removes a present one", () => {
    assert.deepEqual(toggled([], 4), [4])
    assert.deepEqual(toggled([4, 7], 4), [7])
    assert.deepEqual(toggled([4], 7), [4, 7])
})
