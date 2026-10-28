import QtQuick
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/archive.mjs" as A

Column {
    id: root

    readonly property var cfg: Settings.shown.archive
    readonly property var keys: F.keymap(root.cfg.keys, A.ARCHIVE_ACTIONS)

    spacing: 24

    Card {
        title: "SylArchive"
        note: "Opens zip, rar, 7z, tar, iso and every other archive libarchive reads, in a window that works like SylFiles: browse it, open what is inside, drag files out, drop files in. Open one with “sylvaris archive open <file>” or from SylFiles."

        ArchivePreview {}

        SettingRow {
            title: "View"
            key: "archive.view"
            subtitle: F.keyText((root.keys.byAction.grid || [""])[0] || "") + " and " + F.keyText((root.keys.byAction.list || [""])[0] || "") + " switch it in the window; sorting and icon size follow SylFiles"

            Segmented {
                width: 220
                current: root.cfg.view
                options: [
                    {
                        key: "list",
                        label: "List"
                    },
                    {
                        key: "grid",
                        label: "Grid"
                    }
                ]
                onPicked: key => Settings.put("archive.view", key)
            }
        }

        SettingRow {
            title: "Show what you extract"
            key: "archive.reveal"
            subtitle: "Open SylFiles at the result after extracting from SylArchive"
            last: true

            Toggle {
                checked: root.cfg.reveal
                onToggled: v => Settings.put("archive.reveal", v)
            }
        }
    }

    Card {
        title: "Extracting"

        SettingRow {
            title: "Extract here"
            key: "archive.extract"
            subtitle: root.cfg.extract === "smart" ? "An archive with one folder inside gives that folder; loose files get a folder named after the archive" : "Everything goes into a new folder named after the archive"
            last: true

            Segmented {
                width: 240
                current: root.cfg.extract
                options: [
                    {
                        key: "smart",
                        label: "Smart"
                    },
                    {
                        key: "folder",
                        label: "Always a folder"
                    }
                ]
                onPicked: key => Settings.put("archive.extract", key)
            }
        }
    }

    Card {
        title: "New archives"
        note: "Used by Compress in SylFiles. Nothing is ever overwritten: a name that is taken gets a number."

        SettingRow {
            title: "Format"
            key: "archive.format"
            subtitle: root.cfg.format === "zip" ? "Opens everywhere, Windows and phones too" : root.cfg.format === "7z" ? "Small files, needs 7-Zip on Windows" : root.cfg.format === "tar" ? "No compression, keeps Unix permissions" : "Small and keeps Unix permissions; best for Linux"

            Segmented {
                width: 380
                current: root.cfg.format
                options: A.FORMATS
                onPicked: key => Settings.put("archive.format", key)
            }
        }

        SettingRow {
            title: "Compression"
            key: "archive.level"
            advanced: true
            subtitle: "Fast packs quickly, best makes the smallest files"
            last: true

            Segmented {
                width: 260
                current: root.cfg.level
                options: [
                    {
                        key: "fast",
                        label: "Fast"
                    },
                    {
                        key: "normal",
                        label: "Normal"
                    },
                    {
                        key: "best",
                        label: "Best"
                    }
                ]
                onPicked: key => Settings.put("archive.level", key)
            }
        }
    }

    FilesKeysCard {
        part: "archive"
        actions: A.ARCHIVE_ACTIONS
        title: "Keys in SylArchive"
    }
}
