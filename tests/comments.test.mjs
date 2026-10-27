import { test } from "node:test"
import assert from "node:assert/strict"
import { execFileSync } from "node:child_process"
import { readdirSync, readFileSync } from "node:fs"
import { join, relative } from "node:path"

const ROOT = new URL("../", import.meta.url).pathname
const SLASH = /\.(qml|mjs|js|cpp|h|frag)$/
const REGEXY = /\.(qml|mjs|js)$/
const BLOCK = /\.css$/
const PYTHON = /\.py$/
const NIX = /\.nix$/
const SHELL = /\.(sh|steps)$|^bin\/|^dist\/aur\/PKGBUILD$|^dist\/greet\/sylvaris-greet$/
const LINE_HASH = /(^|\/)(Makefile|CMakeLists\.txt|qmldir|\.gitignore)$|\.(conf|desktop|yml|txt)$|^dist\/pam\//
const MARKUP = /\.(html|xml|svg)$/
const AFTER_VALUE = /[\w$)\]}"'`]/

function skipString(src, i, quote) {
    for (i++; i < src.length && src[i] !== quote; i++)
        if (src[i] === "\\")
            i++
    return i
}

function skipRegex(src, i) {
    let inClass = false
    for (i++; i < src.length && src[i] !== "\n"; i++) {
        if (src[i] === "\\")
            i++
        else if (src[i] === "[")
            inClass = true
        else if (src[i] === "]")
            inClass = false
        else if (src[i] === "/" && !inClass)
            return i
    }
    return i
}

function lineAt(src, i) {
    return src.slice(0, i).split("\n").length
}

export function slashComments(src, { regex = false, lineComments = true } = {}) {
    const hits = []
    let prev = ""
    let word = ""
    for (let i = 0; i < src.length; i++) {
        const c = src[i]
        const n = src[i + 1]
        if (/\s/.test(c))
            continue
        if (c === "/" && n === "/" && lineComments) {
            hits.push(lineAt(src, i))
            while (i < src.length && src[i] !== "\n")
                i++
            continue
        }
        if (c === "/" && n === "*") {
            hits.push(lineAt(src, i))
            const end = src.indexOf("*/", i + 2)
            i = end < 0 ? src.length : end + 1
            continue
        }
        if (c === "\"" || c === "'" || (regex && c === "`")) {
            i = skipString(src, i, c)
            prev = c
            word = ""
            continue
        }
        if (regex && c === "/" && (!AFTER_VALUE.test(prev) || /^(return|typeof|case|in|of|delete|void|throw|new)$/.test(word))) {
            i = skipRegex(src, i)
            prev = ")"
            word = ""
            continue
        }
        word = /[\w$]/.test(c) ? (/[\w$]/.test(prev) ? word + c : c) : ""
        prev = c
    }
    return hits
}

export function pythonComments(src) {
    const hits = []
    for (let i = 0; i < src.length; i++) {
        const c = src[i]
        if (c === "#") {
            if (!(i === 0 && src[1] === "!"))
                hits.push(lineAt(src, i))
            while (i < src.length && src[i] !== "\n")
                i++
        } else if (c === "\"" || c === "'") {
            const triple = src.slice(i, i + 3) === c.repeat(3)
            if (triple) {
                const end = src.indexOf(c.repeat(3), i + 3)
                i = end < 0 ? src.length : end + 2
            } else {
                i = skipString(src, i, c)
            }
        }
    }
    return hits
}

export function nixComments(src) {
    const hits = []
    for (let i = 0; i < src.length; i++) {
        const c = src[i]
        if (c === "#" || (c === "/" && src[i + 1] === "*")) {
            hits.push(lineAt(src, i))
            if (c === "#") {
                while (i < src.length && src[i] !== "\n")
                    i++
            } else {
                const end = src.indexOf("*/", i + 2)
                i = end < 0 ? src.length : end + 1
            }
        } else if (c === "\"") {
            i = skipString(src, i, c)
        } else if (c === "'" && src[i + 1] === "'") {
            for (i += 2; i < src.length; i++) {
                if (src[i] === "'" && src[i + 1] === "'") {
                    if (src[i + 2] === "'" || src[i + 2] === "$" || src[i + 2] === "\\") {
                        i += 2
                        continue
                    }
                    i++
                    break
                }
            }
        }
    }
    return hits
}

export function shellComments(src) {
    const hits = []
    const lines = src.split("\n")
    let heredoc = null
    lines.forEach((line, n) => {
        if (heredoc !== null) {
            if (line.replace(/^\t+/, "") === heredoc)
                heredoc = null
            return
        }
        if (n === 0 && line.startsWith("#!"))
            return
        let quote = ""
        for (let i = 0; i < line.length; i++) {
            const c = line[i]
            if (quote === "'") {
                if (c === "'")
                    quote = ""
            } else if (quote === "\"") {
                if (c === "\\")
                    i++
                else if (c === "\"")
                    quote = ""
            } else if (c === "\\") {
                i++
            } else if (c === "'" || c === "\"") {
                quote = c
            } else if (c === "#" && (i === 0 || /[\s;|&(]/.test(line[i - 1]))) {
                hits.push(n + 1)
                break
            }
        }
        const doc = /<<-?\s*['"]?([A-Za-z_]\w*)['"]?/.exec(line.replace(/(<<-?\s*)?('[^']*'|"(?:\\.|[^"\\])*")/g, (m, op) => op ? m : ""))
        if (doc)
            heredoc = doc[1]
    })
    return hits
}

export function lineHashComments(src) {
    return src.split("\n").flatMap((line, n) => /^\s*#/.test(line) ? [n + 1] : [])
}

export function markupComments(src) {
    return src.split("\n").flatMap((line, n) => line.includes("<!--") ? [n + 1] : [])
}

export function commentsIn(path, src) {
    if (SLASH.test(path))
        return slashComments(src, { regex: REGEXY.test(path) })
    if (BLOCK.test(path))
        return slashComments(src, { lineComments: false })
    if (PYTHON.test(path))
        return pythonComments(src)
    if (NIX.test(path))
        return nixComments(src)
    if (SHELL.test(path))
        return shellComments(src)
    if (LINE_HASH.test(path))
        return lineHashComments(src)
    if (MARKUP.test(path))
        return markupComments(src)
    return []
}

test("the scanners find comments and leave strings, regexes and shell counts alone", () => {
    assert.deepEqual(slashComments("a = 1\n// note\nb = \"http://x\" /* c */", { regex: true }), [2, 3])
    assert.deepEqual(slashComments("const r = /^https?:\\/\\//i\nconst d = a / b / c", { regex: true }), [])
    assert.deepEqual(slashComments("x = `a // b ${y}`", { regex: true }), [])
    assert.deepEqual(slashComments("int a = b / c; // why", {}), [1])
    assert.deepEqual(slashComments("a { color: red; } /* x */", { lineComments: false }), [1])
    assert.deepEqual(pythonComments("#!/usr/bin/env python3\nx = '#'\n\"\"\"# doc\"\"\"\ny = 1  # note\n"), [4])
    assert.deepEqual(nixComments("{ a = \"#\"; b = ''\n  # in string\n''; } # tail\n/* block */"), [3, 4])
    assert.deepEqual(shellComments("#!/bin/sh\necho \"$#\" ${#x} 'a # b' \"c # d\"\ncat <<'EOF'\n# literal\nEOF\nls # note\n"), [6])
    assert.deepEqual(markupComments("<p>x</p>\n<!-- hidden -->"), [2])
})

const UNTRACKED = new Set([".git", "node_modules", "build", "result", "__pycache__", ".superpowers", ".claude", "tests/headless/out", "site/dist"])

function walk(dir) {
    return readdirSync(dir, { withFileTypes: true }).flatMap(e => {
        const path = join(dir, e.name)
        if (UNTRACKED.has(relative(ROOT, path)) || UNTRACKED.has(e.name))
            return []
        return e.isDirectory() ? walk(path) : e.isFile() ? [relative(ROOT, path)] : []
    })
}

function trackedFiles() {
    try {
        return execFileSync("git", ["-C", ROOT, "ls-files", "-z"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).split("\0").filter(Boolean)
    } catch (e) {
        return walk(ROOT)
    }
}

test("no tracked code file has a comment", () => {
    const files = trackedFiles()
    const hits = []
    for (const f of files) {
        let src
        try {
            src = readFileSync(join(ROOT, f), "utf8")
        } catch (e) {
            continue
        }
        if (src.includes("\0"))
            continue
        for (const n of commentsIn(f, src))
            hits.push(f + ":" + n + ": " + src.split("\n")[n - 1].trim())
    }
    assert.deepEqual(hits, [], "comments are not allowed; names, structure and tests carry the meaning")
})
