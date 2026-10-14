# SylFiles

A file manager in the Sylvaris look. Unlike the panels, it is a normal window: your compositor tiles, floats and moves it like any other app, and Alt+Tab finds it.

```sh
sylvaris files              # open it, or bring it to the front
sylvaris files open ~/Downloads
sylvaris files open ~/Pictures/cat.png   # opens the folder with the file selected
```

Bind `files open` to a key under SylSettings › Advanced › Key bindings (Super+E is the classic), or open it from SylPad: it ships a `sylvaris-files.desktop` entry. Opening a folder while the window is up adds a tab instead of a second window.

## The window

- **Sidebar**: Home and your XDG folders, your bookmarks and GTK's, every drive (see below) and the trash. Middle-click opens a place in a new tab; × on a bookmark removes it.
- **Path bar**: click any part of the path to go there, or click the empty space (or press Ctrl+L) to type a location. `~`, relative paths and `file://` links work.
- **Filter**: Ctrl+F, `/` or simply start typing. Esc clears it.
- **Grid or list**: Ctrl+1 and Ctrl+2. The list has Size, Modified and Kind columns; click a heading to sort by it, again to reverse. Ctrl and the mouse wheel, or Ctrl+plus and Ctrl+minus, change the icon size.
- **Tabs**: Ctrl+T, Ctrl+W, Ctrl+Tab. Middle-click a folder to open it in a new tab.
- **Details pane** (Alt+Enter): a big preview, the kind, size or folder contents, the date and the permissions of what you select.
- **Status bar**: how many items, how much is selected, the free space, and the progress of copies and moves with a × to stop them.

Pictures show themselves. Videos, PDFs and documents show the thumbnails other apps already made in `~/.cache/thumbnails`. Hidden files (Ctrl+H) and items you have cut look faded.

## Drives

Devices lists everything you can plug in or mount: USB sticks and disks, SD cards, CDs and DVDs, mounted disk images, partitions on your other drives (another Linux or Windows install), encrypted drives, phones and cameras, and network shares. The system's own partitions (`/`, `/boot`, `/nix`, swap, EFI and recovery partitions) stay out of the way.

- **Click** a drive to mount it and open it; a drive that is not mounted yet looks faded. Internal drives may ask for your password through the authentication prompt.
- **Encrypted** drives show a lock. Clicking one asks for its passphrase, unlocks it, mounts it and opens it. The passphrase goes straight to udisks and is never stored or logged.
- **Eject** (the button next to the drive, or right-click › Safely remove) leaves any tab inside it, unmounts it, locks it again if it was encrypted and powers the stick off, so it can be unplugged. Internal drives are only unmounted.
- **Phones and cameras** (MTP, PTP and iPhones) and shares mounted through GNOME's gvfs show up as well, and mount on click.

Mounting goes through udisks2 (`services.udisks2.enable = true` on NixOS), phones and shares through gvfs (`services.gvfs.enable = true`). `sylvaris doctor` says when one is missing.

## Working with files

| Do | How |
|---|---|
| Select | click, Ctrl+click, Shift+click, drag a rubber band over empty space, Ctrl+A, the arrow keys with Shift |
| Open | double-click or Enter (single click if you switch it in the settings); "Open with" lists your apps, the ones made for that kind of file first |
| Copy, cut, paste | Ctrl+C, Ctrl+X, Ctrl+V. Copies also land on the system clipboard as file links, and SylFiles pastes files copied in other apps |
| Drag and drop | onto a folder, a part of the path bar, a place in the sidebar or another app. Hold Ctrl to copy; dropping on Trash moves there |
| Rename | F2, right in place. Enter keeps it, Esc cancels |
| New folder, new file | Ctrl+Shift+N, Ctrl+Alt+N; it opens for renaming |
| Trash | Delete. Shift+Delete deletes for good after asking |
| Undo | Ctrl+Z, or Undo in the status bar: renames, moves, copies, new items and trashing |
| Terminal here | F4, in the terminal from `terminal` in `config.json` |
| Bookmark | Ctrl+D adds or removes the open folder |
| Compress | Ctrl+Alt+C packs the selection into a zip, 7z, tar.gz, tar.xz, tar.zst or tar in the same folder; type the name, pick the format |
| Extract | Ctrl+Alt+X unpacks the selected archives here; right-click › Extract to “name” always makes a folder |

Right-click (or the Menu key, or Shift+F10) shows everything that applies, with its key. Nothing is ever overwritten: a pasted or dropped file whose name is taken gets a number, like `notes (2).txt`. Copies show their progress and can be stopped; a half-copied file is removed.

In the trash, Restore puts items back where they came from and Empty trash deletes everything for good.

## Archives

Double-click a zip, rar, 7z, tar or any other archive and it opens in [SylArchive](archive.md), where you can look inside, open single files and drag them out. For the quick jobs the menu is enough: **Extract here** unpacks next to the archive (an archive that holds one folder gives that folder, loose files get a folder named after the archive), **Extract to “name”** always makes a folder, and **Compress…** packs the selection. Archives with a password ask for it. Compress and extract show their progress in the status bar, can be stopped, and Ctrl+Z takes back what they made. The format, compression level and what Extract here does live in SylSettings › Apps › Archive.

## Keys

Every key above can be changed in SylSettings › Files › Keys in SylFiles: click an action and press the new keys. They are stored in `files.keys` as action and keys, and an empty list turns a key off:

```json
{ "files": { "keys": { "rename": ["CTRL+E"], "terminal": [] } } }
```

The actions are `open`, `openTab`, `openWith`, `back`, `forward`, `up`, `home`, `reload`, `location`, `search`, `newFolder`, `newFile`, `rename`, `copy`, `cut`, `paste`, `copyPath`, `compress`, `extract`, `trash`, `delete`, `undo`, `selectAll`, `invert`, `hidden`, `grid`, `list`, `zoomIn`, `zoomOut`, `zoomReset`, `sidebar`, `details`, `bookmark`, `terminal`, `newTab`, `closeTab`, `nextTab`, `prevTab` and `quit`.

## Make it the default file manager

With Home Manager:

```nix
programs.sylvaris.defaultFileManager = true;
```

This needs `xdg.mimeApps.enable = true`. Without Home Manager, run `xdg-mime default sylvaris-files.desktop inode/directory`.

## Settings

| Key | Default | Meaning |
|---|---|---|
| `files.view` | `"grid"` | `grid` or `list` |
| `files.iconSize` | `64` | icon size in the grid, 40 to 160 |
| `files.sort` | `"name"` | `name`, `modified`, `size` or `kind`; names sort the way people do (2 before 10) |
| `files.descending` | `false` | reverse the order |
| `files.foldersFirst` | `true` | folders before files |
| `files.hidden` | `false` | show names that start with a dot |
| `files.thumbnails` | `true` | show pictures and cached thumbnails |
| `files.icons` | `"glyphs"` | Sylvaris glyphs, or `theme` for your icon theme |
| `files.sidebar` | `true` | show the sidebar |
| `files.details` | `false` | show the details pane |
| `files.click` | `"double"` | `double` or `single` click opens |
| `files.typing` | `"filter"` | typing filters the folder, or `jump`s to the first match |
| `files.start` | `"~"` | the folder a new window opens |
| `files.confirmTrash` | `false` | ask before moving to the trash |
| `files.openArchives` | `true` | open archives in SylArchive instead of your default archive app |
| `files.bookmarks` | `[]` | bookmarked folders, like `"~/Code"` |
| `files.keys` | `{}` | your own keys, see above |

```sh
sylvaris files go ~/Music       # in the open tab
sylvaris files tab /srv         # in a new tab
sylvaris files select a.txt b.txt
sylvaris files search draft
sylvaris files act newFolder    # any action from the list above
sylvaris files rename final.txt # the one selected item
sylvaris files compress pack.zip  # the selection, without asking
sylvaris files drives           # every drive SylFiles sees
sylvaris files mount KINGSTON   # by label or device, then open it
sylvaris files eject KINGSTON
sylvaris files state
sylvaris files close
sylvaris set parts.files false
```

Copies, moves and restores run through a small Python helper; the trash goes through `gio`, drives through `lsblk` and `udisksctl`.
