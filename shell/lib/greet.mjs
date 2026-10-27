const NOLOGIN = /(nologin|false)$/

export function parsePasswd(text) {
    const out = []
    for (const line of String(text || "").split("\n")) {
        const f = line.split(":")
        if (f.length < 7)
            continue
        const uid = Number(f[2])
        if (!(uid >= 1000 && uid < 60000) || NOLOGIN.test(f[6]))
            continue
        out.push({ name: f[0], real: f[4].split(",")[0] || f[0], home: f[5], uid: uid })
    }
    return out
}

export function parseSessions(blob) {
    const out = []
    const seen = {}
    const files = String(blob || "").split(/^@@/m).filter(s => s.trim() !== "")
    for (const file of files) {
        const lines = file.split("\n")
        const id = lines[0].trim().split("/").pop().replace(/\.desktop$/, "")
        const entry = {}
        let inside = false
        for (const line of lines.slice(1)) {
            if (/^\[.*\]$/.test(line.trim())) {
                inside = line.trim() === "[Desktop Entry]"
                continue
            }
            const m = inside && /^([A-Za-z]+)=(.*)$/.exec(line)
            if (m && entry[m[1]] === undefined)
                entry[m[1]] = m[2].trim()
        }
        if (!entry.Name || !entry.Exec || entry.Hidden === "true" || entry.NoDisplay === "true" || seen[id])
            continue
        seen[id] = true
        out.push({ id: id, name: entry.Name, exec: entry.Exec })
    }
    return out
}

export function pick(list, remembered, fallback) {
    if (list.length === 0)
        return -1
    for (const want of [remembered, fallback]) {
        const i = want ? list.findIndex(x => x.id === want) : -1
        if (i >= 0)
            return i
    }
    return 0
}

export function splitExec(exec) {
    const out = []
    const re = /"((?:[^"\\]|\\.)*)"|(\S+)/g
    let m
    while ((m = re.exec(String(exec || ""))) !== null) {
        const w = m[1] !== undefined ? m[1].replace(/\\(.)/g, "$1") : m[2]
        if (!/^%[a-zA-Z]$/.test(w))
            out.push(w)
    }
    return out
}
