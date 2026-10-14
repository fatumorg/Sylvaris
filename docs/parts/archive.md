# SylArchive

An archive manager that works like [SylFiles](files.md): the same list and grid, keys, path bar, filter and menus, in a window of its own. It opens zip, rar, 7z, tar (with gzip, bzip2, xz, zstd, lzip or lz4), iso, cab, deb, rpm, cpio and every other format libarchive reads, and single compressed files like `notes.txt.gz`.

```sh
sylvaris archive open ~/Downloads/photos.zip
```

SylFiles opens archives here when you double-click them, and its menu has Extract and Compress for the times you do not need to look inside. To open archives here from other apps too, see [the default app](#make-it-the-default-archive-manager). Like SylFiles, the window has its own icon in the bar, the deck and the switcher.

## The window

- **Browse** folders inside the archive like ordinary folders: double-click, Enter, Backspace, Alt+Up, the path bar, the filter and type-ahead all work as in SylFiles. Sorting and icon size follow SylFiles.
- **Open** a file and it is unpacked to `~/.cache/sylvaris/archive` and opened in its usual app. Copies older than a day are cleared.
- **Extract**: Ctrl+E unpacks what you selected next to the archive, Ctrl+Shift+E everything, Ctrl+Alt+E asks where. Extract here is smart: an archive that holds one folder gives that folder, loose files get a folder named after the archive. Nothing is ever overwritten; a taken name gets a number.
- **Drag** files out onto SylFiles or any app to unpack just those.
- **Change** zip, 7z and tar archives: drop files on the list to add them to the folder you are in, Delete takes the selection out after asking. Other formats can only be read.
- **Passwords**: an archive with a password asks for it when it needs it. The password goes to the unpacker on its input, never on a command line, and is forgotten when the window closes.

The panel on the left shows the format, the archive's size, what is inside, how big it is unpacked and how much the archive saves.

## Keys

| Action | Keys |
|---|---|
| `open` | Enter |
| `extract`, `extractAll`, `extractTo` | Ctrl+E, Ctrl+Shift+E, Ctrl+Alt+E |
| `remove` | Delete |
| `back`, `forward`, `up` | Alt+Left or Backspace, Alt+Right, Alt+Up |
| `location`, `search` | Ctrl+L, Ctrl+F or `/` |
| `selectAll`, `invert` | Ctrl+A, Ctrl+Shift+I |
| `grid`, `list` | Ctrl+1, Ctrl+2 |
| `reload` | F5, Ctrl+R |
| `reveal` | Ctrl+Alt+O shows the archive in SylFiles |
| `quit` | Ctrl+W, Ctrl+Q |

Change them in SylSettings › Apps › Archive, or in `archive.keys` the same way as [SylFiles keys](files.md#keys).

## Make it the default archive manager

With Home Manager:

```nix
programs.sylvaris.defaultArchiveManager = true;
```

This needs `xdg.mimeApps.enable = true`. Without Home Manager, run `xdg-mime default sylvaris-archive.desktop application/zip` for each type you want.

## Settings

| Key | Default | Meaning |
|---|---|---|
| `archive.view` | `"list"` | `list` or `grid` |
| `archive.extract` | `"smart"` | `smart` keeps a single folder as it is, `folder` always makes a new folder |
| `archive.reveal` | `true` | open SylFiles at what you extracted |
| `archive.format` | `"zip"` | what Compress in SylFiles makes: `zip`, `7z`, `tar.gz`, `tar.xz`, `tar.zst` or `tar` |
| `archive.level` | `"normal"` | `fast`, `normal` or `best` compression |
| `archive.keys` | `{}` | your own keys |

```sh
sylvaris archive open photos.zip
sylvaris archive go photos/2024    # a folder inside
sylvaris archive select a.jpg b.jpg
sylvaris archive extract           # the selection, or everything, next to the archive
sylvaris archive extract ~/Pictures
sylvaris archive add ~/notes.txt   # into the folder you are in
sylvaris archive act remove        # any action from the list above
sylvaris archive search beach
sylvaris archive state
sylvaris archive close
sylvaris set parts.archive false
```

Everything goes through libarchive's `bsdtar` and a small Python helper. RAR archives can be opened and extracted but not changed or made, since only the RAR program itself can write them.
