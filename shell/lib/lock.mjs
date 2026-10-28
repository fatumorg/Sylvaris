export const PAM_SERVICES = ["sylvaris", "hyprlock", "swaylock", "login"]
export const LOCK_FACES = ["default", "digital", "flip", "analog", "word", "giant"]
export const DEFAULT_LOCK = { pam: "", logind: false, seconds: false, face: "default" }

export function pamService(setting, existing) {
    if (setting)
        return setting
    return PAM_SERVICES.find(s => existing.indexOf(s) >= 0) || "login"
}

export function sessionPath(id) {
    if (!id)
        return "/org/freedesktop/login1/session/auto"
    let out = ""
    for (let i = 0; i < id.length; i++) {
        const c = id[i]
        const plain = /[A-Za-z]/.test(c) || /[0-9]/.test(c) && i > 0
        out += plain ? c : "_" + c.charCodeAt(0).toString(16).padStart(2, "0")
    }
    return "/org/freedesktop/login1/session/" + out
}

export function isLockSignal(line, path) {
    return line.indexOf(path + ":") === 0 && /\.Session\.Lock \(\)/.test(line)
}

export function validateLock(raw) {
    const v = raw !== null && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
    return Object.assign({}, v, {
        pam: typeof v.pam === "string" && /^[a-z0-9._-]*$/.test(v.pam) && v.pam.indexOf("..") < 0 ? v.pam : DEFAULT_LOCK.pam,
        logind: v.logind === true,
        seconds: v.seconds === true,
        face: LOCK_FACES.indexOf(v.face) >= 0 ? v.face : DEFAULT_LOCK.face
    })
}
