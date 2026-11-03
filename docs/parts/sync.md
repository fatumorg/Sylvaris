# SylSync

Turn on SylSettings › Look › App colours and your theme's colours flow into other apps every time you switch themes:

- GTK 3 and 4, and Chromium, Brave or Vivaldi set to use the GTK theme
- Qt through qt5ct and qt6ct
- kitty (open terminals update at once) and foot
- VS Code, VSCodium and Cursor, Zed, Neovim and Vim
- optionally Firefox, LibreWolf and Mullvad Browser, through `userChrome.css`
- optionally Zen Browser, as its own switch, which tints Zen's own space gradient

Sylvaris writes its own theme files and at most one include line. VS Code and its forks get `workbench.colorCustomizations` in the `settings.json` of every profile instead, which they apply at once. Firefox gets its frame, address bar, menus, panels and sidebar through `userChrome.css`, plus the new tab, home and settings pages through `userContent.css`, and picks up new colours on its next start. Zen keeps its own look: Sylvaris writes `chrome/sylvaris.json` into each profile under `~/.config/zen` or `~/.zen`, and the browser script below turns it into the gradient of every space, the same gradient Zen's theme picker makes.

Each app is a switch, and apps that are not installed are skipped.

## Live browser colours

With the browser script, Firefox and Zen change colour the moment you switch themes, without a restart. It is a small autoconfig script shipped at `share/sylvaris/helpers/browser.js` in the Sylvaris package. It runs with the browser's own privileges, reads only `chrome/sylvaris.css` and `chrome/sylvaris.json` in the profile it runs in, and checks them every two seconds. Zen needs it for any colour at all.

Firefox from nixpkgs takes it through its wrapper:

```nix
(pkgs.firefox.override {
  extraPrefsFiles = [ "${sylvaris}/share/sylvaris/helpers/browser.js" ];
  extraAutoConfig = ''pref("general.config.sandbox_enabled", false);'';
})
```

Zen launches its unwrapped binary, so the script goes into that package under its own file names:

```nix
zen.beta-unwrapped.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    for lib in "$out"/lib/zen-bin-*; do
      chmod -R u+w "$lib/defaults"
      { echo "//"; cat ${sylvaris}/share/sylvaris/helpers/browser.js; } > "$lib/sylvaris.cfg"
      printf '%s\n' 'pref("general.config.filename", "sylvaris.cfg");' 'pref("general.config.obscure_value", 0);' 'pref("general.config.sandbox_enabled", false);' > "$lib/defaults/pref/sylvaris.js"
    done
  '';
})
```

```sh
sylvaris sync now       # write the colours again
sylvaris sync on        # also: off, state
```
