export function pushUndo(stack, entry, max) {
    const cap = max === undefined ? 20 : max
    return stack.concat([entry]).slice(-cap)
}

export function popUndo(stack) {
    if (stack.length === 0)
        return { entry: null, stack: [] }
    return { entry: stack[stack.length - 1], stack: stack.slice(0, -1) }
}
