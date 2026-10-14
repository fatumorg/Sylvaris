# SylSync

Turn on SylSettings › Look › App colours and your theme's colours flow into other apps every time you switch themes:

- GTK 3 and 4, and Chromium, Brave or Vivaldi set to use the GTK theme
- Qt through qt5ct and qt6ct
- kitty (open terminals update at once) and foot
- VS Code, VSCodium and Cursor, Zed, Neovim and Vim
- optionally Firefox, LibreWolf, Zen and Mullvad Browser, through `userChrome.css`

Sylvaris writes its own theme files and at most one include line. VS Code and its forks get `workbench.colorCustomizations` in the `settings.json` of every profile instead, which they apply at once. Firefox gets its frame, address bar, menus, panels and sidebar through `userChrome.css`, plus the new tab, home and settings pages through `userContent.css`, and picks up new colours on its next start.

Each app is a switch, and apps that are not installed are skipped.

```sh
sylvaris sync now       # write the colours again
sylvaris sync on        # also: off, state
```
