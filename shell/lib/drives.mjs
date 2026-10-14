import { sizeText, nameOf } from "./files.mjs"
import { natural } from "./viewer.mjs"

const COLUMNS = "NAME,PATH,TYPE,SIZE,FSTYPE,LABEL,MOUNTPOINTS,RM,HOTPLUG,TRAN,MODEL,PARTTYPE,PARTLABEL"

export const LSBLK = ["sh", "-c", "lsblk -J -b -o " + COLUMNS + " 2>/dev/null || lsblk -J -b -o " + COLUMNS.replace("MOUNTPOINTS,", "MOUNTPOINT,")]

export const GIO_LIST = ["gio", "mount", "-l", "-i"]

const HIDDEN_PARTS = ["c12a7328-f81f-11d2-ba4b-00a0c93ec93b", "e3c9e316-0b5c-4db8-817d-f92df00215ae", "de94bba4-06d1-4d40-a16a-bfd50179d6ac", "21686148-6449-6e6f-744e-656564454649", "0xef", "0x27"]
const NOT_MOUNTABLE = ["swap", "LVM2_member", "linux_raid_member", "zfs_member", "squashfs", "erofs"]
const LOCKED = ["crypto_LUKS", "BitLocker"]
const SYSTEM = ["/", "/home", "/tmp", "/opt", "/srv", "/root"]
const SYSTEM_TREES = ["/boot", "/efi", "/nix", "/var", "/usr", "/etc", "/snap", "/persist", "/gnu", "/sysroot"]
const FS_NAMES = { vfat: "FAT", exfat: "exFAT", ntfs: "NTFS", ntfs3: "NTFS", ext2: "ext2", ext3: "ext3", ext4: "ext4", btrfs: "Btrfs", xfs: "XFS", f2fs: "F2FS", iso9660: "ISO 9660", udf: "UDF", hfsplus: "HFS+", apfs: "APFS" }
const GENERIC_PARTLABELS = ["primary", "linux filesystem", "basic data partition", "microsoft basic data", "logical", "extended"]
const NET_FS = ["nfs", "nfs4", "cifs", "smb3", "smbfs", "davfs", "fuse.sshfs", "fuse.rclone", "fuse.s3fs", "fuse.davfs2"]
const PHONE_FUSE = ["fuse.jmtpfs", "fuse.simple-mtpfs", "fuse.go-mtpfs", "fuse.aft-mtp-mount", "fuse.ifuse", "fuse.mtpfs"]
const PHONE_SCHEMES = ["mtp", "gphoto2", "afc"]
const NET_SCHEMES = ["smb", "sftp", "ssh", "ftp", "ftps", "dav", "davs", "nfs", "afp", "google-drive", "onedrive"]
const RANK = { usb: 0, card: 0, optical: 0, phone: 0, image: 0, disk: 1, network: 2 }

function truthy(v) {
    return v === true || v === 1 || v === "1" || v === "true"
}

function driveSize(bytes) {
    return sizeText(Number(bytes) || 0).replace(/\.0 /, " ")
}

function row(extra) {
    return Object.assign({ id: "", label: "", detail: "", kind: "disk", via: "udisks", mounted: false, path: "", locked: false, ejectable: false, drive: "", crypt: "" }, extra)
}

function mountsOf(node) {
    const list = Array.isArray(node.mountpoints) ? node.mountpoints : [node.mountpoint]
    return list.filter(m => typeof m === "string" && m !== "" && m !== "[SWAP]")
}

function isSystem(mount) {
    return SYSTEM.indexOf(mount) >= 0 || SYSTEM_TREES.some(s => mount === s || mount.startsWith(s + "/"))
}

function kindOfDisk(disk) {
    if (disk.type === "rom")
        return "optical"
    if (disk.type === "loop")
        return "image"
    if (String(disk.name || "").startsWith("mmcblk") || disk.tran === "mmc" || /\b(SD|MMC|card)\b/i.test(String(disk.model || "")))
        return "card"
    if (disk.tran === "usb" || truthy(disk.rm) || truthy(disk.hotplug))
        return "usb"
    return "disk"
}

function labelOf(node, disk, removable, suffix) {
    const own = String(node.label || "").trim()
    if (own !== "")
        return own
    const part = String(node.partlabel || "").trim()
    if (part !== "" && GENERIC_PARTLABELS.indexOf(part.toLowerCase()) < 0)
        return part
    const model = String(disk.model || "").trim()
    if (removable && model !== "")
        return model
    return driveSize(node.size) + " " + suffix
}

export function blockDrives(text) {
    let data = null
    try {
        data = JSON.parse(String(text || ""))
    } catch (e) {
        return []
    }
    const out = []
    const walk = (node, disk, crypt) => {
        const kind = kindOfDisk(disk)
        const removable = kind !== "disk"
        const mounts = mountsOf(node)
        if (node.type === "loop" && !mounts.some(m => m.startsWith("/run/media/") || m.startsWith("/media/") || m.startsWith("/mnt/")))
            return
        if (String(node.name || "").startsWith("zram") || mounts.some(isSystem))
            return
        if (HIDDEN_PARTS.indexOf(String(node.parttype || "").toLowerCase()) >= 0)
            return
        const kids = Array.isArray(node.children) ? node.children : []
        if (LOCKED.indexOf(node.fstype) >= 0) {
            const open = kids.filter(k => k.type === "crypt")
            if (open.length > 0) {
                for (const k of open)
                    walk(k, disk, node.path)
                return
            }
            out.push(row({ id: node.path, label: labelOf(node, disk, removable, "encrypted volume"), detail: "Locked · " + driveSize(node.size), kind: kind, locked: true, ejectable: removable && kind !== "optical", drive: kind === "usb" || kind === "card" ? disk.path : "" }))
            return
        }
        if (kids.length > 0) {
            for (const k of kids)
                walk(k, disk, crypt)
            return
        }
        if (!node.fstype || NOT_MOUNTABLE.indexOf(node.fstype) >= 0)
            return
        out.push(row({
            id: node.path,
            label: labelOf(node, disk, removable, "volume"),
            detail: driveSize(node.size) + " · " + (FS_NAMES[node.fstype] || node.fstype),
            kind: kind,
            mounted: mounts.length > 0,
            path: mounts.length > 0 ? mounts[0] : "",
            ejectable: removable,
            drive: kind === "usb" || kind === "card" ? disk.path : "",
            crypt: crypt
        }))
    }
    for (const d of (data && Array.isArray(data.blockdevices)) ? data.blockdevices : [])
        walk(d, d, "")
    return out
}

export function gioDrives(text) {
    const out = []
    let volume = null
    const close = () => {
        if (volume !== null && volume.root !== "") {
            const scheme = volume.root.slice(0, volume.root.indexOf(":"))
            if (PHONE_SCHEMES.indexOf(scheme) >= 0)
                out.push(row({ id: volume.root, label: volume.name, detail: "Phone", kind: "phone", via: "gio", mounted: volume.mounted, ejectable: true }))
        }
        volume = null
    }
    for (const line of String(text || "").split("\n")) {
        const indent = line.length - line.replace(/^\s+/, "").length
        const v = /^\s*Volume\(\d+\):\s*(.*)$/.exec(line)
        const m = /^\s*Mount\(\d+\):\s*(.*?) -> (\S+)\s*$/.exec(line)
        const root = /^\s*activation_root=(\S+)\s*$/.exec(line)
        if (/^\s*Drive\(\d+\):/.test(line) || v !== null) {
            close()
            if (v !== null)
                volume = { name: v[1].trim(), root: "", mounted: false, indent: indent }
        } else if (root !== null && volume !== null) {
            volume.root = root[1]
        } else if (m !== null) {
            if (volume !== null && indent > volume.indent) {
                volume.mounted = true
                continue
            }
            close()
            const uri = m[2]
            const scheme = uri.slice(0, uri.indexOf(":"))
            if (out.some(r => r.id === uri))
                out.find(r => r.id === uri).mounted = true
            else if (PHONE_SCHEMES.indexOf(scheme) >= 0)
                out.push(row({ id: uri, label: m[1].trim(), detail: "Phone", kind: "phone", via: "gio", mounted: true, ejectable: true }))
            else if (NET_SCHEMES.indexOf(scheme) >= 0)
                out.push(row({ id: uri, label: m[1].trim(), detail: "Network", kind: "network", via: "gio", mounted: true, ejectable: true }))
        }
    }
    close()
    return out
}

export function netDrives(text) {
    const out = []
    const unescape = s => s.replace(/\\([0-7]{3})/g, (m, o) => String.fromCharCode(parseInt(o, 8)))
    for (const line of String(text || "").split("\n")) {
        const f = line.split(" ")
        if (f.length < 3)
            continue
        const phone = PHONE_FUSE.indexOf(f[2]) >= 0
        if (!phone && NET_FS.indexOf(f[2]) < 0)
            continue
        const dir = unescape(f[1])
        if (out.some(r => r.id === dir))
            continue
        out.push(row({ id: dir, label: nameOf(dir), detail: unescape(f[0]), kind: phone ? "phone" : "network", via: f[2].startsWith("fuse.") ? "fuse" : "umount", mounted: true, path: dir, ejectable: true }))
    }
    return out
}

export function drives(lsblkText, gioText, mountsText) {
    const all = blockDrives(lsblkText).concat(gioDrives(gioText), netDrives(mountsText))
    return all.map((r, i) => ({ r: r, i: i })).sort((a, b) => (RANK[a.r.kind] - RANK[b.r.kind]) || natural(a.r.label.toLowerCase(), b.r.label.toLowerCase()) || a.i - b.i).map(x => x.r)
}

export function driveError(text) {
    const t = String(text || "").trim()
    if (t === "")
        return "It did not work"
    if (/udisks daemon|org\.freedesktop\.UDisks2 was not provided|ServiceUnknown.*UDisks2/i.test(t))
        return "Mounting needs udisks2, for example services.udisks2.enable = true on NixOS"
    if (/NotAuthorizedDismissed|dismissed/i.test(t))
        return "Cancelled"
    if (/NotAuthorized/.test(t))
        return "You are not allowed to mount it"
    if (/DeviceBusy|target is busy/i.test(t))
        return "Something is still using it; close the files and apps on it first"
    if (/passphrase|No key available/i.test(t))
        return "Wrong passphrase"
    if (/wrong fs type|unknown filesystem|UnknownFilesystem/i.test(t))
        return "Linux cannot read this file system"
    const last = t.split("\n").filter(l => l.trim() !== "").pop()
    return last.slice(last.lastIndexOf(": ") + 2).replace(/\.$/, "").trim().slice(0, 140) || "It did not work"
}

export function localPath(text) {
    const m = /^local path: (.+)$/m.exec(String(text || ""))
    return m ? m[1].trim() : ""
}

const EJECT = "{ [ -z \"$1\" ] || udisksctl unmount -b \"$1\"; } && { [ -z \"$2\" ] || udisksctl lock -b \"$2\"; } && { [ -z \"$3\" ] || udisksctl power-off -b \"$3\"; } && { [ -z \"$4\" ] || udisksctl loop-delete -b \"$4\"; }"

export function driveCommand(d, verb, all) {
    if (d.via === "gio")
        return verb === "mount" ? ["gio", "mount", d.id] : verb === "find" ? ["gio", "info", d.id] : ["gio", "mount", "-u", d.id]
    if (d.via === "umount")
        return verb === "eject" ? ["umount", "--", d.path] : []
    if (d.via === "fuse")
        return verb === "eject" ? ["sh", "-c", "fusermount3 -u -- \"$1\" 2>/dev/null || fusermount -u -- \"$1\"", "sh", d.path] : []
    if (verb === "mount")
        return ["udisksctl", "mount", "-b", d.id]
    if (verb === "unlock")
        return ["udisksctl", "unlock", "-b", d.id, "--key-file", "/dev/stdin"]
    const others = (all || []).some(r => r.drive !== "" && r.drive === d.drive && r.id !== d.id && r.mounted)
    return ["sh", "-c", EJECT, "sh", d.mounted ? d.id : "", d.crypt, others ? "" : d.drive, d.kind === "image" ? d.id : ""]
}
