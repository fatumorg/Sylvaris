import { test } from "node:test"
import assert from "node:assert/strict"
import { isPicture, timeoutFor, insert, remove, pushToast, groups, ago, cleanBody, plainText, iconSource, CRITICAL, toastShift, evicted, cardFrame } from "../shell/lib/notify.mjs"

test("timeoutFor keeps critical and zero-timeout notifications up, honours the app, else the default", () => {
    assert.equal(timeoutFor(CRITICAL, 3000, 5000), 0)
    assert.equal(timeoutFor(1, 0, 5000), 0)
    assert.equal(timeoutFor(1, 3000, 5000), 3000)
    assert.equal(timeoutFor(1, -1, 5000), 5000)
})

test("insert puts the newest first, replaces the same id and caps the list", () => {
    let l = []
    l = insert(l, { id: 1 }, 3)
    l = insert(l, { id: 2 }, 3)
    l = insert(l, { id: 1, v: 2 }, 3)
    assert.deepEqual(l, [{ id: 1, v: 2 }, { id: 2 }])
    l = insert(insert(l, { id: 3 }, 3), { id: 4 }, 3)
    assert.deepEqual(l.map(e => e.id), [4, 3, 1])
    assert.deepEqual(remove(l, 3).map(e => e.id), [4, 1])
})

test("pushToast keeps the newest few", () => {
    assert.deepEqual(pushToast([1, 2, 3], 4, 3), [2, 3, 4])
    assert.deepEqual(pushToast([1, 2], 1, 3), [2, 1])
})

test("groups keeps apps in order of their newest notification", () => {
    const g = groups([{ a: "Mail" }, { a: "Chat" }, { a: "Mail" }, { a: "" }], e => e.a)
    assert.deepEqual(g.map(x => [x.app, x.items.length]), [["Mail", 2], ["Chat", 1], ["Other", 1]])
})

test("ago gives short relative times", () => {
    assert.equal(ago(0, 30000), "now")
    assert.equal(ago(0, 5 * 60000), "5m")
    assert.equal(ago(0, 3 * 3600000), "3h")
    assert.equal(ago(0, 49 * 3600000), "2d")
})

test("cleanBody keeps simple markup, drops images and other tags", () => {
    assert.equal(cleanBody("<b>hi</b> <img src=\"http://x/y.png\"/><script>x</script>\nline"), "<b>hi</b> x<br>line")
    assert.equal(cleanBody("<a href=\"https://e.com\">link</a>"), "<a href=\"https://e.com\">link</a>")
    assert.equal(cleanBody(undefined), "")
    assert.equal(cleanBody("<img src=\"http://x/y.png\"\nhi"), "&lt;img src=\"http://x/y.png\"<br>hi")
    assert.equal(cleanBody("a < b <b>c</b>"), "a &lt; b <b>c</b>")
    assert.equal(cleanBody("<b <img src=x>>t"), "&lt;b >t")
})

test("plainText strips tags and decodes entities", () => {
    assert.equal(plainText("<b>Tom &amp; Jerry</b> &lt;3"), "Tom & Jerry <3")
})

test("iconSource resolves names, paths and URLs", () => {
    const lookup = name => name === "firefox" ? "image://icon/firefox" : ""
    assert.equal(iconSource("firefox", lookup), "image://icon/firefox")
    assert.equal(iconSource("nope", lookup), "")
    assert.equal(iconSource("/tmp/a.png", lookup), "file:///tmp/a.png")
    assert.equal(iconSource("/tmp/my #1.png", lookup), "file:///tmp/my%20%231.png")
    assert.equal(iconSource("file:///tmp/a.png", lookup), "file:///tmp/a.png")
    assert.equal(iconSource("", lookup), "")
    assert.equal(isPicture("/tmp/a.png"), true)
    assert.equal(isPicture("mail-message-new"), false)
    assert.equal(isPicture("image://icon/firefox"), false)
    assert.equal(isPicture("image://qsimage/1/2"), true)
    assert.equal(iconSource("image://icon/firefox", lookup), "image://icon/firefox")
    assert.equal(iconSource("image://icon/nope", lookup), "")
    assert.equal(iconSource("https://tracker.example/p.png", lookup), "")
    assert.equal(iconSource("HTTP://tracker.example/p.png", lookup), "")
    assert.equal(iconSource("ftp://x/y.png", lookup), "")
    assert.equal(iconSource("image://qsimage/1/2", lookup), "image://qsimage/1/2")
})

test("toastShift moves toasts beside or below an open panel in the same corner only", () => {
    const panel = { corner: "top-right", width: 400, height: 600, screen: "A" }
    assert.deepEqual(toastShift("top-right", "A", panel, 12), { x: 412, y: 0 })
    assert.deepEqual(toastShift("top-left", "A", panel, 12), { x: 0, y: 0 })
    assert.deepEqual(toastShift("top-right", "B", panel, 12), { x: 0, y: 0 })
    assert.deepEqual(toastShift("top-center", "A", Object.assign({}, panel, { corner: "top-center" }), 12), { x: 0, y: 612 })
    assert.deepEqual(toastShift("center-left", "A", Object.assign({}, panel, { corner: "center-left" }), 12), { x: 412, y: 0 })
    assert.deepEqual(toastShift("top-right", "A", null, 12), { x: 0, y: 0 })
})

test("evicted lists entries pushed out past the cap but not a replaced id", () => {
    const a = { id: 1 }, b = { id: 2 }, c = { id: 3 }
    const before = [b, a]
    assert.deepEqual(evicted(before, insert(before, c, 2)), [a])
    assert.deepEqual(evicted(before, insert(before, { id: 1 }, 2)), [])
    assert.deepEqual(evicted([], insert([], c, 2)), [])
})

test("cards fan the first three and spread into a list", () => {
    assert.deepEqual(cardFrame(0, false, 0), { y: 0, scale: 1, opacity: 1 })
    assert.deepEqual(cardFrame(1, false, 90), { y: 6, scale: 0.96, opacity: 1 })
    assert.equal(cardFrame(2, false, 180).y, 12)
    assert.equal(cardFrame(3, false, 270).opacity, 0)
    assert.equal(cardFrame(5, false, 450).y, 12)
    assert.deepEqual(cardFrame(3, true, 270), { y: 270, scale: 1, opacity: 1 })
})
