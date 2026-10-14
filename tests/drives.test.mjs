import { test } from "node:test"
import assert from "node:assert/strict"
import { blockDrives, gioDrives, netDrives, drives, driveError, localPath, driveCommand, LSBLK } from "../shell/lib/drives.mjs"

const dev = (name, type, extra) => Object.assign({ name: name, path: "/dev/" + name, type: type, size: 0, fstype: null, label: null, uuid: null, mountpoints: [null], rm: false, hotplug: false, tran: null, model: null, parttype: null, partlabel: null }, extra || {})

const LS = JSON.stringify({
    blockdevices: [
        dev("zram0", "disk", { size: 8e9, mountpoints: ["[SWAP]"] }),
        dev("loop0", "loop", { size: 1e8, fstype: "squashfs", mountpoints: ["/snap/core/1"] }),
        dev("loop1", "loop", { size: 4e9, fstype: "iso9660", label: "Fedora", mountpoints: ["/run/media/ada/Fedora"] }),
        dev("nvme0n1", "disk", { size: 1e12, tran: "nvme", model: "Samsung SSD", children: [
            dev("nvme0n1p1", "part", { size: 5e8, fstype: "vfat", parttype: "c12a7328-f81f-11d2-ba4b-00a0c93ec93b", mountpoints: ["/boot"] }),
            dev("nvme0n1p2", "part", { size: 5e11, fstype: "btrfs", mountpoints: ["/nix/store", "/home", "/"] }),
            dev("nvme0n1p3", "part", { size: 1.6e7, parttype: "e3c9e316-0b5c-4db8-817d-f92df00215ae" }),
            dev("nvme0n1p4", "part", { size: 4.8e11, fstype: "ntfs", label: "Windows" }),
            dev("nvme0n1p5", "part", { size: 6e8, fstype: "ntfs", parttype: "de94bba4-06d1-4d40-a16a-bfd50179d6ac" }),
            dev("nvme0n1p6", "part", { size: 2e10, fstype: "ext4", partlabel: "Linux filesystem", mountpoints: ["/data"] }),
            dev("nvme0n1p7", "part", { size: 2e11, fstype: "ext4", label: "Games", mountpoints: ["/home/ada/Games"] }),
            dev("nvme0n1p8", "part", { size: 2e9, fstype: "ext4", mountpoints: ["/var/log"] })
        ] }),
        dev("sda", "disk", { size: 2e12, tran: "sata", model: "WDC", children: [
            dev("sda1", "part", { size: 2e12, fstype: "ext4", partlabel: "primary" }),
            dev("sda2", "part", { size: 8e9, fstype: "swap" })
        ] }),
        dev("sdb", "disk", { size: 3.2e10, tran: "usb", rm: true, hotplug: true, model: "DataTraveler 3.0", children: [
            dev("sdb1", "part", { size: 3.2e10, fstype: "vfat" })
        ] }),
        dev("sdc", "disk", { size: 6.4e10, tran: "usb", hotplug: true, model: "Portable SSD", children: [
            dev("sdc1", "part", { size: 6.4e10, fstype: "crypto_LUKS", label: "Vault" })
        ] }),
        dev("sdd", "disk", { size: 1.28e11, tran: "usb", rm: "1", hotplug: "1", model: "Extreme", children: [
            dev("sdd1", "part", { size: 1.28e11, fstype: "crypto_LUKS", children: [
                dev("luks-1234", "crypt", { path: "/dev/mapper/luks-1234", size: 1.28e11, fstype: "ext4", label: "Backup", mountpoints: ["/run/media/ada/Backup"] })
            ] })
        ] }),
        dev("sde", "disk", { size: 6.4e10, tran: "usb", rm: true, model: "SD/MMC Reader", children: [
            dev("sde1", "part", { size: 6.4e10, fstype: "exfat", label: "CAMERA", mountpoint: "/run/media/ada/CAMERA", mountpoints: undefined })
        ] }),
        dev("mmcblk0", "disk", { size: 1.6e10, children: [
            dev("mmcblk0p1", "part", { size: 1.6e10, fstype: "vfat", label: "PHOTOS" })
        ] }),
        dev("sr0", "rom", { size: 4e9, rm: true, fstype: "iso9660", label: "Ubuntu 24.04", model: "DVD-RW" }),
        dev("sr1", "rom", { size: 0, rm: true, model: "BD-ROM" })
    ]
})

const GIO = `Drive(0): Samsung SSD
  Type: GProxyDrive (GProxyVolumeMonitorUDisks2)
  ids:
   unix-device: '/dev/nvme0n1'
  Volume(0): Windows
    Type: GProxyVolume (GProxyVolumeMonitorUDisks2)
    activation_root=file:///whatever/
Volume(0): Pixel 7
  Type: GProxyVolume (GProxyVolumeMonitorMTP)
  ids:
   unix-device: '/dev/bus/usb/003/009'
  activation_root=mtp://Google_Pixel_7_2820/
  can_mount=1
Volume(1): iPhone
  Type: GProxyVolume (GProxyVolumeMonitorAfc)
  activation_root=afc://00008030/
  can_mount=1
  Mount(0): iPhone -> afc://00008030/
    Type: GProxyMount (GProxyVolumeMonitorAfc)
    can_unmount=1
Mount(0): media on nas -> smb://nas/media/
  Type: GDaemonMount
Mount(1): Filesystem root -> file:///
  Type: GUnixMount
`

const MOUNTS = `/dev/nvme0n1p2 / btrfs rw 0 0
//nas/share /mnt/share cifs rw 0 0
nas:/export /srv/nfs nfs4 rw 0 0
ada@host: /home/ada/remote fuse.sshfs rw 0 0
gvfsd-fuse /run/user/1000/gvfs fuse.gvfsd-fuse rw 0 0
jmtpfs /home/ada/phone fuse.jmtpfs rw 0 0
tmpfs /tmp tmpfs rw 0 0
`

test("LSBLK asks for a tree with sizes in bytes and every column the parser reads", () => {
    assert.equal(LSBLK[0], "sh")
    assert.match(LSBLK.join(" "), /lsblk -J -b -o NAME,PATH,TYPE,SIZE,FSTYPE,LABEL,MOUNTPOINTS,RM,HOTPLUG,TRAN,MODEL,PARTTYPE,PARTLABEL/)
    assert.match(LSBLK.join(" "), /MOUNTPOINT,/)
})

test("blockDrives lists sticks, cards, discs, images, other disks and locked volumes but never the system", () => {
    const rows = blockDrives(LS)
    const ids = rows.map(r => r.id)
    assert.deepEqual(ids.slice().sort(), ["/dev/loop1", "/dev/mapper/luks-1234", "/dev/mmcblk0p1", "/dev/nvme0n1p4", "/dev/nvme0n1p6", "/dev/nvme0n1p7", "/dev/sda1", "/dev/sdb1", "/dev/sdc1", "/dev/sde1", "/dev/sr0"])
    const by = id => rows.find(r => r.id === id)
    assert.deepEqual(by("/dev/sdb1"), { id: "/dev/sdb1", label: "DataTraveler 3.0", detail: "32 GB · FAT", kind: "usb", via: "udisks", mounted: false, path: "", locked: false, ejectable: true, drive: "/dev/sdb", crypt: "" })
    assert.equal(by("/dev/sdc1").locked, true)
    assert.equal(by("/dev/sdc1").label, "Vault")
    assert.equal(by("/dev/sdc1").detail, "Locked · 64 GB")
    assert.deepEqual([by("/dev/mapper/luks-1234").label, by("/dev/mapper/luks-1234").path, by("/dev/mapper/luks-1234").crypt, by("/dev/mapper/luks-1234").drive, by("/dev/mapper/luks-1234").kind], ["Backup", "/run/media/ada/Backup", "/dev/sdd1", "/dev/sdd", "usb"])
    assert.deepEqual([by("/dev/sde1").kind, by("/dev/sde1").mounted, by("/dev/sde1").path], ["card", true, "/run/media/ada/CAMERA"])
    assert.deepEqual([by("/dev/mmcblk0p1").kind, by("/dev/mmcblk0p1").ejectable], ["card", true])
    assert.deepEqual([by("/dev/sr0").kind, by("/dev/sr0").label, by("/dev/sr0").drive], ["optical", "Ubuntu 24.04", ""])
    assert.deepEqual([by("/dev/loop1").kind, by("/dev/loop1").ejectable], ["image", true])
    assert.deepEqual([by("/dev/nvme0n1p4").kind, by("/dev/nvme0n1p4").ejectable, by("/dev/nvme0n1p4").detail], ["disk", false, "480 GB · NTFS"])
    assert.deepEqual([by("/dev/nvme0n1p6").label, by("/dev/nvme0n1p6").path], ["20 GB volume", "/data"])
    assert.equal(by("/dev/sda1").label, "2 TB volume")
})

test("blockDrives survives broken or empty input", () => {
    assert.deepEqual(blockDrives(""), [])
    assert.deepEqual(blockDrives("{"), [])
    assert.deepEqual(blockDrives('{"blockdevices":null}'), [])
})

test("gioDrives finds phones and network shares that gvfs knows about", () => {
    const rows = gioDrives(GIO)
    assert.deepEqual(rows, [
        { id: "mtp://Google_Pixel_7_2820/", label: "Pixel 7", detail: "Phone", kind: "phone", via: "gio", mounted: false, path: "", locked: false, ejectable: true, drive: "", crypt: "" },
        { id: "afc://00008030/", label: "iPhone", detail: "Phone", kind: "phone", via: "gio", mounted: true, path: "", locked: false, ejectable: true, drive: "", crypt: "" },
        { id: "smb://nas/media/", label: "media on nas", detail: "Network", kind: "network", via: "gio", mounted: true, path: "", locked: false, ejectable: true, drive: "", crypt: "" }
    ])
    assert.deepEqual(gioDrives(""), [])
})

test("netDrives lists network and fuse mounts from the mount table", () => {
    const rows = netDrives(MOUNTS)
    assert.deepEqual(rows.map(r => [r.id, r.label, r.kind, r.via, r.detail]), [
        ["/mnt/share", "share", "network", "umount", "//nas/share"],
        ["/srv/nfs", "nfs", "network", "umount", "nas:/export"],
        ["/home/ada/remote", "remote", "network", "fuse", "ada@host:"],
        ["/home/ada/phone", "phone", "phone", "fuse", "jmtpfs"]
    ])
    assert.ok(rows.every(r => r.mounted && r.path === r.id && r.ejectable))
})

test("drives puts removable things first, then disks, then the network", () => {
    const rows = drives(LS, GIO, MOUNTS)
    const kinds = rows.map(r => r.kind)
    const last = k => kinds.lastIndexOf(k)
    const first = k => kinds.indexOf(k)
    assert.ok(last("usb") < first("disk") && last("phone") < first("disk") && last("disk") < first("network"))
    assert.equal(rows.filter(r => r.id === "/dev/sdb1").length, 1)
    assert.deepEqual(drives("", "", ""), [])
})

test("driveError turns udisks and gio errors into plain words", () => {
    assert.equal(driveError("Error connecting to the udisks daemon: Could not connect: No such file or directory"), "Mounting needs udisks2, for example services.udisks2.enable = true on NixOS")
    assert.equal(driveError("Error mounting /dev/sdb1: GDBus.Error:org.freedesktop.UDisks2.Error.NotAuthorizedDismissed: Not authorized"), "Cancelled")
    assert.equal(driveError("Error mounting /dev/sda1: GDBus.Error:org.freedesktop.UDisks2.Error.NotAuthorized: Not authorized"), "You are not allowed to mount it")
    assert.equal(driveError("Error unmounting /dev/sdb1: GDBus.Error:org.freedesktop.UDisks2.Error.DeviceBusy: Error unmounting /dev/sdb1: target is busy"), "Something is still using it; close the files and apps on it first")
    assert.equal(driveError("Error unlocking /dev/sdc1: GDBus.Error:org.freedesktop.UDisks2.Error.Failed: Error unlocking /dev/sdc1: Failed to activate device: Incorrect passphrase."), "Wrong passphrase")
    assert.equal(driveError("Error mounting /dev/sda1: GDBus.Error:org.freedesktop.UDisks2.Error.Failed: Error mounting /dev/sda1 at /run/media/ada/x: wrong fs type, bad option, bad superblock"), "Linux cannot read this file system")
    assert.equal(driveError("gio: mtp://x/: Unable to open MTP device “x”"), "Unable to open MTP device “x”")
    assert.equal(driveError("umount: /mnt/share: must be superuser to unmount."), "must be superuser to unmount")
    assert.equal(driveError(""), "It did not work")
})

test("localPath reads the folder gvfs gives a phone or share", () => {
    assert.equal(localPath("display name: Pixel 7\nlocal path: /run/user/1000/gvfs/mtp:host=Google_Pixel_7_2820\nuri: mtp://x/\n"), "/run/user/1000/gvfs/mtp:host=Google_Pixel_7_2820")
    assert.equal(localPath("uri: smb://nas/\n"), "")
})

test("driveCommand builds the commands for each kind of device", () => {
    const stick = blockDrives(LS).find(r => r.id === "/dev/sdb1")
    assert.deepEqual(driveCommand(stick, "mount", []), ["udisksctl", "mount", "-b", "/dev/sdb1"])
    const vault = blockDrives(LS).find(r => r.id === "/dev/sdc1")
    assert.deepEqual(driveCommand(vault, "unlock", []), ["udisksctl", "unlock", "-b", "/dev/sdc1", "--key-file", "/dev/stdin"])
    const backup = blockDrives(LS).find(r => r.id === "/dev/mapper/luks-1234")
    const eject = driveCommand(backup, "eject", [])
    assert.equal(eject[0], "sh")
    assert.deepEqual(eject.slice(3), ["sh", "/dev/mapper/luks-1234", "/dev/sdd1", "/dev/sdd", ""])
    assert.deepEqual(driveCommand(backup, "eject", [backup, Object.assign({}, stick, { drive: "/dev/sdd", mounted: true, id: "/dev/sdd2" })]).slice(3), ["sh", "/dev/mapper/luks-1234", "/dev/sdd1", "", ""])
    const image = blockDrives(LS).find(r => r.id === "/dev/loop1")
    assert.deepEqual(driveCommand(image, "eject", []).slice(3), ["sh", "/dev/loop1", "", "", "/dev/loop1"])
    const disk = blockDrives(LS).find(r => r.id === "/dev/nvme0n1p6")
    assert.deepEqual(driveCommand(disk, "eject", []).slice(3), ["sh", "/dev/nvme0n1p6", "", "", ""])
    const phone = gioDrives(GIO)[0]
    assert.deepEqual(driveCommand(phone, "mount", []), ["gio", "mount", "mtp://Google_Pixel_7_2820/"])
    assert.deepEqual(driveCommand(phone, "eject", []), ["gio", "mount", "-u", "mtp://Google_Pixel_7_2820/"])
    assert.deepEqual(driveCommand(phone, "find", []), ["gio", "info", "mtp://Google_Pixel_7_2820/"])
    const [share, , sshfs] = netDrives(MOUNTS)
    assert.deepEqual(driveCommand(share, "eject", []), ["umount", "--", "/mnt/share"])
    assert.equal(driveCommand(sshfs, "eject", [])[0], "sh")
    assert.equal(driveCommand(sshfs, "eject", []).slice(-1)[0], "/home/ada/remote")
    assert.deepEqual(driveCommand(share, "mount", []), [])
})
