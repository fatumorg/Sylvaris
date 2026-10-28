# SylNotes

A small text and code editor in the Sylvaris look, for notes, config files and the odd script. It is a normal window with tabs, and it opens as its own app in the bar, the deck and the switcher.

```sh
sylvaris notes open ~/notes.txt ~/.config/foot/foot.ini
```

## Editing

- **Tabs**: Ctrl+N opens a new tab, Ctrl+W closes one, Ctrl+Tab and Ctrl+Shift+Tab move between them. Ctrl+Shift+N opens another window. Middle-click a tab to close it.
- **Open and save**: Ctrl+O and Ctrl+Shift+S use the SylFiles dialog, Ctrl+S saves. You can also drop files on the window. A tab with changes you have not saved shows a dot, and closing it asks first.
- **Find and replace**: Ctrl+F finds, Ctrl+H finds and replaces. Enter or F3 goes to the next match, Shift+Enter or Shift+F3 to the one before. Aa matches case, Word matches whole words, `.*` reads the search as a regular expression, and `$1` in the replacement puts back what a group matched.
- **Go to line**: Ctrl+G.
- **Indent**: Enter keeps the indentation of the line above and adds a level after `:`, `{`, `[` or `(`. Tab indents with spaces or a tab character, Shift+Tab takes a level away.
- **Wrap and zoom**: Alt+Z wraps long lines on and off. Ctrl+= and Ctrl+- make the text bigger and smaller in every window, Ctrl+0 puts it back.

The bar at the bottom shows the language, the line endings (LF or CRLF), the indentation, how much is selected, the zoom and where the cursor is.

## Colours by language

SylNotes colours code in more than 300 languages through KDE's syntax-highlighting, with the colours of your Sylvaris theme. The language comes from the file name; click it in the bar at the bottom to pick another, or Plain text for none. Files over 1 MB stay plain so they open fast. If you change theme after SylNotes has coloured something, it uses a plain light or dark scheme until the shell restarts.

## Your files stay as they were

Saving changes only what you edited. A file with Windows line endings keeps them, a file without a final newline stays without one, and the file is replaced in one step, so a crash halfway through never leaves half a file behind.

Files SylNotes could not save back exactly open read-only, with the reason on top: binary files, text that is not UTF-8, files that mix line endings, and anything over 10 MB.

When a file changes on disk while it is open, a tab without changes reloads it. A tab with changes asks: Reload, or Keep mine.

## Unsaved changes survive a crash

What you type is copied to `~/.local/state/sylvaris/notes` a second after you stop, in a folder only you can read. If the shell or the computer stops before you save, the next time SylNotes opens it brings those tabs back with Keep and Discard. Saving or discarding removes the copy.

## Make it the default text editor

With Home Manager:

```nix
programs.sylvaris.defaultTextEditor = true;
```

This needs `xdg.mimeApps.enable = true`. Without Home Manager, run `xdg-mime default sylvaris-notes.desktop text/plain`.

## Settings

| Key | Default | Meaning |
|---|---|---|
| `notes.wrap` | `false` | wrap long lines |
| `notes.lineNumbers` | `true` | show line numbers |
| `notes.highlight` | `true` | colour code by language |
| `notes.tabWidth` | `4` | columns per indentation level |
| `notes.spaces` | `true` | indent with spaces instead of a tab character |
| `notes.size` | `14` | text size |
| `notes.recent` | `[]` | recently opened files, newest first, shown in an empty tab |

```sh
sylvaris notes open file.txt   # in a new tab; relative paths start where you run the command
sylvaris notes new             # an empty tab
sylvaris notes window [file]   # in a new window
sylvaris notes save            # the tab you are on
sylvaris notes state
sylvaris notes close
sylvaris set parts.notes false
```
