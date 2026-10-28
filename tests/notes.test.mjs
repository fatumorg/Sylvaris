import { test } from "node:test"
import assert from "node:assert/strict"
import { DEFAULT_NOTES, validateNotes, detectEol, stripEol, withEol, isBinary, readOnlyFor, lossy, pushRecent, swapName, indentOf, nextIndent, findAll, replaceAll, lineStart, lineAt, lineStarts, lineOf, highlightTheme, languageFor, titleOf } from "../shell/lib/notes.mjs"
import { DEFAULT_THEME } from "../shell/lib/theme.mjs"

test("line endings round trip byte for byte", () => {
    for (const x of ["a\r\nb\r\n", "a\nb", "", "one line", "a\r\nb"]) {
        const eol = detectEol(x)
        assert.equal(withEol(stripEol(x), eol), x)
    }
    assert.equal(detectEol("a\r\nb"), "crlf")
    assert.equal(detectEol("a\nb"), "lf")
    assert.equal(detectEol("\nb"), "lf")
})

test("binary and huge files open read-only", () => {
    assert.equal(isBinary("ab\u0000c"), true)
    assert.equal(isBinary("plain text"), false)
    assert.equal(readOnlyFor(11 * 1024 * 1024), true)
    assert.equal(readOnlyFor(1024), false)
})

test("text the editor would change on the way back opens read-only", () => {
    for (const ok of ["a\r\nb\r\n", "a\nb\n", "tab\there\u00a0nbsp", ""])
        assert.equal(lossy(ok), "", JSON.stringify(ok))
    for (const bad of ["caf\ufffd", "a\rb", "a\r\nb\nc", "a\u2028b", "a\u2029b"])
        assert.notEqual(lossy(bad), "", JSON.stringify(bad))
})

test("recent files move to the front and cap at ten", () => {
    assert.deepEqual(pushRecent(["a", "b"], "b"), ["b", "a"])
    assert.equal(pushRecent(Array.from({ length: 10 }, (_, i) => "f" + i), "new").length, 10)
})

test("swap names are stable and differ per file", () => {
    assert.equal(swapName("/a/b.txt"), swapName("/a/b.txt"))
    assert.notEqual(swapName("/a/b.txt"), swapName("untitled-1"))
    assert.match(swapName("x"), /^[0-9a-f]{8}\.swp$/)
})

test("indentation carries on and grows after an opener", () => {
    assert.equal(indentOf("\t  x"), "\t  ")
    assert.equal(nextIndent("    if x:", 4, true), "        ")
    assert.equal(nextIndent("    x = 1", 4, true), "    ")
    assert.equal(nextIndent("f() {", 4, false), "\t")
})

test("find handles plain text, regex and bad regex", () => {
    assert.equal(findAll("a.a", ".", { regex: false }).length, 1)
    assert.equal(findAll("a.a", ".", { regex: true }).length, 3)
    const bad = findAll("x", "(", { regex: true })
    assert.deepEqual(Array.from(bad), [])
    assert.notEqual(bad.error, "")
    assert.equal(findAll("Cat cat", "cat", { caseSensitive: true }).length, 1)
    assert.equal(findAll("cat concat", "cat", { wholeWord: true }).length, 1)
    assert.equal(findAll("abc", "", {}).length, 0)
})

test("replace counts what it changed", () => {
    assert.deepEqual(replaceAll("cat cat", "cat", "dog", { wholeWord: true }), { text: "dog dog", count: 2 })
    assert.deepEqual(replaceAll("a1b22", "(\\d+)", "<$1>", { regex: true }), { text: "a<1>b<22>", count: 2 })
    assert.deepEqual(replaceAll("x", "(", "y", { regex: true }), { text: "x", count: 0 })
})

test("line math", () => {
    assert.equal(lineStart("a\nb\nc", 3), 4)
    assert.equal(lineStart("a\nb\nc", 1), 0)
    assert.equal(lineStart("a", 9), 1)
    assert.equal(lineAt("a\nb\nc", 4), 3)
    assert.deepEqual(lineStarts("a\nb\nc"), [0, 2, 4])
    assert.deepEqual(lineStarts(""), [0])
    assert.deepEqual(lineStarts("a\n"), [0, 2])
    const starts = lineStarts("a\nb\nc")
    assert.deepEqual([0, 1, 2, 3, 4, 5].map(o => lineOf(starts, o)), [1, 1, 2, 2, 3, 3])
})

test("the highlight theme follows the palette", () => {
    const t = highlightTheme(DEFAULT_THEME.colors)
    assert.equal(t["text-styles"].Normal["text-color"], DEFAULT_THEME.colors.text)
    assert.equal(t["editor-colors"].BackgroundColor, DEFAULT_THEME.colors.base)
})

test("languages and titles come from the name", () => {
    assert.equal(languageFor("/x/a.py"), "Python")
    assert.equal(languageFor("/x/Makefile"), "Makefile")
    assert.equal(languageFor("/x/a.unknown"), "")
    assert.equal(titleOf("", 2), "Untitled 2")
    assert.equal(titleOf("/a/b.txt", 1), "b.txt")
})

test("notes settings validate", () => {
    assert.deepEqual(validateNotes({}), DEFAULT_NOTES)
    assert.equal(validateNotes({ tabWidth: 0 }).tabWidth, 4)
})
