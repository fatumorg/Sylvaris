import QtQuick
import qs.services
import qs.components
import "../lib/files.mjs" as F
import "../lib/icons.mjs" as Icons

Column {
    id: root

    readonly property var cfg: Settings.shown.files

    spacing: 24

    Card {
        title: "SylFiles"
        note: "A file manager in a normal window, with tabs, a sidebar, previews and undo. Open it with “sylvaris files”, bind it under Key bindings, or make it your default file manager from Nix."

        FilesPreview {}

        SettingRow {
            title: "View"
            subtitle: F.keyText((F.keymap(root.cfg.keys).byAction.grid || [""])[0] || "") + " and " + F.keyText((F.keymap(root.cfg.keys).byAction.list || [""])[0] || "") + " switch it in the window"

            Segmented {
                width: 220
                current: root.cfg.view
                options: [
                    {
                        key: "grid",
                        label: "Grid"
                    },
                    {
                        key: "list",
                        label: "List"
                    }
                ]
                onPicked: key => Settings.put("files.view", key)
            }
        }

        SettingRow {
            title: "Icon size"
            subtitle: "Ctrl and the mouse wheel zoom too"

            Stepper {
                value: root.cfg.iconSize
                from: F.ICON_MIN
                to: F.ICON_MAX
                step: 8
                suffix: " px"
                onStepped: v => Settings.put("files.iconSize", v)
            }
        }

        SettingRow {
            title: "Sort by"
            subtitle: "Click a column heading in the list view to sort by it"

            Segmented {
                width: 340
                current: root.cfg.sort
                options: [
                    {
                        key: "name",
                        label: "Name"
                    },
                    {
                        key: "modified",
                        label: "Date"
                    },
                    {
                        key: "size",
                        label: "Size"
                    },
                    {
                        key: "kind",
                        label: "Kind"
                    }
                ]
                onPicked: key => Settings.put("files.sort", key)
            }
        }

        SettingRow {
            title: "Reversed order"

            Toggle {
                checked: root.cfg.descending
                onToggled: v => Settings.put("files.descending", v)
            }
        }

        SettingRow {
            title: "Folders first"

            Toggle {
                checked: root.cfg.foldersFirst
                onToggled: v => Settings.put("files.foldersFirst", v)
            }
        }

        SettingRow {
            title: "Show hidden files"
            subtitle: "Names that start with a dot"

            Toggle {
                checked: root.cfg.hidden
                onToggled: v => Settings.put("files.hidden", v)
            }
        }

        SettingRow {
            title: "Sidebar"

            Toggle {
                checked: root.cfg.sidebar
                onToggled: v => Settings.put("files.sidebar", v)
            }
        }

        SettingRow {
            title: "Sidebar order"
            subtitle: "Click one to put it first"

            Flow {
                width: 420
                spacing: 6

                Repeater {
                    model: root.cfg.sections

                    delegate: Chip {
                        required property string modelData
                        required property int index
                        text: ({ places: "Places", bookmarks: "Bookmarks", devices: "Devices" })[modelData]
                        lit: index === 0
                        onClicked: Settings.put("files.sections", [modelData].concat(root.cfg.sections.filter(k => k !== modelData)))
                    }
                }
            }
        }

        SettingRow {
            title: "Places and devices order"
            subtitle: "Drag them in the sidebar to reorder"

            RowButton {
                icon: Icons.GLYPHS.restart
                label: "Reset"
                onClicked: {
                    Settings.put("files.placeOrder", []);
                    Settings.put("files.deviceOrder", []);
                }
            }
        }

        SettingRow {
            title: "Details pane"
            subtitle: "A big preview, size, date and permissions of what you select"
            last: true

            Toggle {
                checked: root.cfg.details
                onToggled: v => Settings.put("files.details", v)
            }
        }
    }

    Card {
        title: "Behaviour"

        SettingRow {
            title: "Open with"
            subtitle: "How many clicks open a file or folder"

            Segmented {
                width: 240
                current: root.cfg.click
                options: [
                    {
                        key: "double",
                        label: "Double click"
                    },
                    {
                        key: "single",
                        label: "Single click"
                    }
                ]
                onPicked: key => Settings.put("files.click", key)
            }
        }

        SettingRow {
            title: "Typing in a folder"
            subtitle: "Filter what is shown, or jump to the first name that starts with what you type"

            Segmented {
                width: 240
                current: root.cfg.typing
                options: [
                    {
                        key: "filter",
                        label: "Filter"
                    },
                    {
                        key: "jump",
                        label: "Jump"
                    }
                ]
                onPicked: key => Settings.put("files.typing", key)
            }
        }

        SettingRow {
            title: "Previews"
            subtitle: "Pictures show themselves; videos and documents use the thumbnails other apps already made"

            Toggle {
                checked: root.cfg.thumbnails
                onToggled: v => Settings.put("files.thumbnails", v)
            }
        }

        SettingRow {
            title: "Icons"
            subtitle: "Sylvaris glyphs, or the icon theme you use"

            Segmented {
                width: 240
                current: root.cfg.icons
                options: [
                    {
                        key: "glyphs",
                        label: "Glyphs"
                    },
                    {
                        key: "theme",
                        label: "Icon theme"
                    }
                ]
                onPicked: key => Settings.put("files.icons", key)
            }
        }

        SettingRow {
            title: "Open archives in SylArchive"
            subtitle: "Off opens them in your default archive app; Extract and Compress stay in the menu either way"

            Toggle {
                checked: root.cfg.openArchives
                onToggled: v => Settings.put("files.openArchives", v)
            }
        }

        SettingRow {
            title: "Ask before moving to the trash"
            subtitle: "Undo brings things back either way"

            Toggle {
                checked: root.cfg.confirmTrash
                onToggled: v => Settings.put("files.confirmTrash", v)
            }
        }

        SettingRow {
            title: "Start in"
            subtitle: "The folder a new window opens, like ~ or ~/Downloads"
            last: true

            TextBox {
                width: 240
                text: root.cfg.start
                placeholder: "~"
                onAccepted: Settings.put("files.start", text)
            }
        }
    }

    Card {
        title: "Bookmarks"
        note: root.cfg.bookmarks.length === 0 ? "None yet. In SylFiles, press " + F.keyText((F.keymap(root.cfg.keys).byAction.bookmark || [""])[0]) + " in a folder to bookmark it. GTK bookmarks show up in the sidebar too." : "GTK bookmarks show up in the sidebar too."

        Repeater {
            model: root.cfg.bookmarks

            delegate: SettingRow {
                required property string modelData
                required property int index
                title: modelData
                last: index === root.cfg.bookmarks.length - 1

                Glyph {
                    text: Icons.GLYPHS.close
                    size: 15
                    color: dropArea.containsMouse ? Theme.danger : Theme.textDim

                    MouseArea {
                        id: dropArea
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.put("files.bookmarks", root.cfg.bookmarks.filter(b => b !== modelData))
                    }
                }
            }
        }
    }

    FilesKeysCard {}
}
