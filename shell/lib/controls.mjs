export const TICKS = 12

export function ticksLit(value, count) {
    return Math.max(0, Math.min(count, Math.round(value * count)))
}

export function tickValue(index, count) {
    return index === 0 ? 0 : Math.min(1, (index + 1) / count)
}
