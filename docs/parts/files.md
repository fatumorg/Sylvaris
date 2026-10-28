# SylFiles

A file manager in the Sylvaris look. Unlike the panels, it is a normal window: your compositor tiles, floats and moves it like any other app, and Alt+Tab finds it.

```sh
sylvaris files              # open it, or bring it to the front
sylvaris files open ~/Downloads
sylvaris files open ~/Pictures/cat.png   # opens the folder with the file selected
```

Bind `files open` to a key under SylSettings › Advanced › Key bindings (Super+E is the classic), or open it from SylPad: it ships a `sylvaris-files.desktop` entry. Opening a folder while the window is up adds a tab instead of a second window; for a second window press Ctrl+N, right-click a folder › Open in a new window, or run `sylvaris files window [folder]`. Cut in one window and paste in another moves the files. Commands go to the window you used last. The window has its own icon, so SylBar, SylDeck and SylSwitch show it as SylFiles and you can pin it to the deck.

## The window

- **Sidebar**: Home and your XDG folders, your bookmarks and GTK's, every drive (see below) and the trash. Middle-click opens a place in a new tab; × on a bookmark removes it. Drag a place, bookmark or device up or down to reorder it; the order is remembered (GTK bookmarks are saved back to `~/.config/gtk-3.0/bookmarks`).
- **Path bar**: click any part of the path to go there, or click the empty space (or press Ctrl+L) to type a location. `~`, relative paths and `file://` links work.
- **Filter**: Ctrl+F, `/` or simply start typing. Esc clears it.
- **Grid or list**: Ctrl+1 and Ctrl+2. The list has Size, Modified and Kind columns; click a heading to sort by it, again to reverse. Ctrl and the mouse wheel, or Ctrl+plus and Ctrl+minus, change the icon size.
- **Tabs and windows**: Ctrl+T, Ctrl+W, Ctrl+Tab. Middle-click a folder to open it in a new tab. Ctrl+N opens another window.
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

Right-click (or the Menu key, or Shift+F10) shows everything that applies, with its key. Copies show their progress and can be stopped; a half-copied file is removed. Pasting a copy into its own folder makes a duplicate, like `notes (2).txt`.

### When a name is taken

Pasting, dropping, extracting, packing or restoring onto a name that is already there asks first. The dialog shows both sides, their size or item count, their date, and which one is newer or larger:

| Choice | Key | What happens |
| --- | --- | --- |
| Merge | M | folder onto folder: what is new goes in, and anything with the same name inside is asked about one by one |
| Replace | R | the old one goes to the trash, the new one takes its place |
| Skip | S | leave this one out |
| Keep both | K | the new one gets a number, like `notes (2).txt` |
| Rename… | N | type a name for the new one, the part before the extension is already selected |
| Cancel | Esc | stop here; what was already done stays |

Turn on **Do the same for every other clash** (or press A) to answer once: it covers the rest of the folder clashes or the rest of the file clashes, whichever you just answered. Undo after a replace takes the new items away and brings the replaced ones back from the trash; after a merge it only takes away what the merge added. Closing SylFiles while it asks stops the job.

Files dragged out of SylArchive are unpacked in the background; dropping them before that finishes waits for them instead of failing.

In the trash, Restore puts items back where they came from and Empty trash deletes everything for good.

## Archives

Double-click a zip, rar, 7z, tar or any other archive and it opens in [SylArchive](archive.md), where you can look inside, open single files and drag them out. For the quick jobs the menu is enough: **Extract here** unpacks next to the archive (an archive that holds one folder gives that folder, loose files get a folder named after the archive), **Extract to “name”** always makes a folder, and **Compress…** packs the selection. Archives with a password ask for it. Compress and extract show their progress in the status bar, can be stopped, and Ctrl+Z takes back what they made. The format, compression level and what Extract here does live in SylSettings › Apps › Archive.

## Open and save dialogs

SylFiles can be the dialog apps show when you open or save a file: Firefox, Chromium and Electron apps, GTK apps and Flatpaks, anything that asks the desktop portal. It opens in its own window with everything above, plus a bar at the bottom: pick files and press Open (or double-click one), pick a folder and press Select, or type a name and press Save. Saving over a file asks first, and Esc or closing the window cancels.

On NixOS:

```nix
programs.sylvaris.fileChooser.enable = true;
```

This adds the termfilechooser portal, points it at `sylvaris choose`, routes the portal's file chooser to it under Hyprland, sway and niri, and sets `GTK_USE_PORTAL=1` and `GDK_DEBUG=portals` so GTK apps and Firefox use the portal too. Log out and back in afterwards. Elsewhere, install xdg-desktop-portal-termfilechooser, set `org.freedesktop.impl.portal.FileChooser=termfilechooser` in your desktop's `portals.conf`, and write this to `~/.config/xdg-desktop-portal-termfilechooser/config`:

```ini
[filechooser]
cmd=sylvaris choose
create_help_file=0
```

If the shell is not running, the dialog fails instead of hanging; if it restarts while a dialog is open, the app gets a cancel.

## Keys

Every key above can be changed in SylSettings › Files › Keys in SylFiles: click an action and press the new keys. They are stored in `files.keys` as action and keys, and an empty list turns a key off:

```json
{ "files": { "keys": { "rename": ["CTRL+E"], "terminal": [] } } }
```

The actions are `open`, `openTab`, `openWith`, `back`, `forward`, `up`, `home`, `reload`, `location`, `search`, `newFolder`, `newFile`, `rename`, `copy`, `cut`, `paste`, `copyPath`, `compress`, `extract`, `trash`, `delete`, `undo`, `selectAll`, `invert`, `hidden`, `grid`, `list`, `zoomIn`, `zoomOut`, `zoomReset`, `sidebar`, `details`, `bookmark`, `terminal`, `newTab`, `newWindow`, `closeTab`, `nextTab`, `prevTab` and `quit`.

## Make it the default file manager

With Home Manager:

```nix
programs.sylvaris.defaultFileManager = true;
```

This needs `xdg.mimeApps.enable = true`. Without Home Manager, run `xdg-mime default sylvaris-files.desktop inode/directory`.

It also makes SylFiles answer "Show in folder" from other apps such as Firefox (`org.freedesktop.FileManager1`).

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
| `files.sections` | `["places", "bookmarks", "devices"]` | order of the sidebar sections |
| `files.placeOrder` | `[]` | order of the places, as paths; set by dragging them |
| `files.deviceOrder` | `[]` | order of the devices, as drive ids, `/` and `trash`; set by dragging them |
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
sylvaris files window ~/Code    # in a new window
sylvaris files windows          # how many windows are open
sylvaris files select a.txt b.txt
sylvaris files search draft
sylvaris files act newFolder    # any action from the list above
sylvaris files rename final.txt # the one selected item
sylvaris files compress pack.zip  # the selection, without asking
sylvaris files picker          # the open or save dialog, if one is up
sylvaris files clash merge all  # answer the name clash: merge, replace, skip, keep, rename NAME or stop
sylvaris files drives           # every drive SylFiles sees
sylvaris files mount KINGSTON   # by label or device, then open it
sylvaris files eject KINGSTON
sylvaris files state
sylvaris files close
sylvaris set parts.files false
```

Copies, moves and restores run through a small Python helper; the trash goes through `gio`, drives through `lsblk` and `udisksctl`.
