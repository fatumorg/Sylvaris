export function monthGrid(year, month, firstDay) {
    const first = new Date(year, month, 1).getDay()
    const lead = (first - firstDay + 7) % 7
    const cells = []
    for (let i = 0; i < 42; i++) {
        const d = new Date(year, month, 1 - lead + i)
        cells.push({ year: d.getFullYear(), month: d.getMonth(), day: d.getDate(), inMonth: d.getMonth() === month && d.getFullYear() === year })
    }
    return cells
}

export function shiftMonth(year, month, delta) {
    const total = year * 12 + month + delta
    return { year: Math.floor(total / 12), month: ((total % 12) + 12) % 12 }
}

export function weekdayLabels(firstDay, names) {
    const out = []
    for (let i = 0; i < 7; i++)
        out.push(names[(firstDay + i) % 7])
    return out
}

export function isSameDay(cell, date) {
    return cell.year === date.getFullYear() && cell.month === date.getMonth() && cell.day === date.getDate()
}

export function isoWeek(year, month, day) {
    const t = new Date(Date.UTC(year, month, day))
    t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7))
    const start = Date.UTC(t.getUTCFullYear(), 0, 1)
    return Math.ceil(((t.getTime() - start) / 86400000 + 1) / 7)
}

export function rowWeeks(cells, firstDay) {
    const out = []
    for (let r = 0; r * 7 < cells.length; r++) {
        const c = cells[r * 7 + (firstDay === 0 ? 1 : 0)]
        out.push(isoWeek(c.year, c.month, c.day))
    }
    return out
}
