export const COLUMNS = [
    { key: "name", label: "Name", text: true },
    { key: "pid", label: "PID" },
    { key: "user", label: "User", text: true },
    { key: "cpu", label: "CPU" },
    { key: "mem", label: "Memory" },
    { key: "threads", label: "Threads" },
    { key: "nice", label: "Nice" },
    { key: "state", label: "State", text: true }
]

export const STATES = { R: "Running", S: "Sleeping", D: "Waiting on disk", Z: "Zombie", T: "Stopped", t: "Traced", I: "Idle", X: "Dead" }

export const HISTORY = 60

function compare(key, desc) {
    const col = COLUMNS.find(c => c.key === key) || COLUMNS.find(c => c.key === "cpu")
    const dir = desc ? -1 : 1
    return (a, b) => {
        const x = a[col.key], y = b[col.key]
        const d = col.text ? String(x).localeCompare(String(y), undefined, { sensitivity: "base" }) : x - y
        return d !== 0 ? d * dir : a.pid - b.pid
    }
}

export function sortProcs(procs, key, desc) {
    return procs.slice().sort(compare(key, desc))
}

export function filterProcs(procs, query) {
    const words = String(query).toLowerCase().split(/\s+/).filter(w => w !== "")
    if (words.length === 0)
        return procs
    return procs.filter(p => {
        const hay = (p.name + " " + p.cmd + " " + p.user).toLowerCase()
        return words.every(w => hay.includes(w) || String(p.pid) === w)
    })
}

export function tree(procs, key, desc, folded) {
    const byPid = new Map(procs.map(p => [p.pid, p]))
    const kids = new Map()
    for (const p of procs) {
        const parent = byPid.has(p.ppid) && p.ppid !== p.pid ? p.ppid : 0
        if (!kids.has(parent))
            kids.set(parent, [])
        kids.get(parent).push(p)
    }
    const order = compare(key, desc)
    const shut = new Set(folded)
    const out = []
    const seen = new Set()
    const walk = root => {
        const stack = [[root, 0, false]]
        while (stack.length > 0) {
            const [p, d, hidden] = stack.pop()
            if (seen.has(p.pid))
                continue
            seen.add(p.pid)
            const children = (kids.get(p.pid) || []).slice().sort(order)
            if (!hidden)
                out.push(Object.assign({}, p, { depth: d, kids: children.length }))
            for (let i = children.length - 1; i >= 0; i--)
                stack.push([children[i], d + 1, hidden || shut.has(p.pid)])
        }
    }
    for (const p of (kids.get(0) || []).slice().sort(order))
        walk(p)
    for (const p of sortProcs(procs, key, desc))
        walk(p)
    return out
}

export function push(list, value, max) {
    return (Array.isArray(list) ? list : []).concat([value]).slice(-max)
}
