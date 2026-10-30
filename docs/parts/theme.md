# SylTheme

`sylvaris theme` opens the theme picker on the focused screen with the current theme in front. The arrow keys, the mouse wheel, dragging or clicking a side card move the carousel. Once it rests for half a second, the whole desktop previews that theme's colours and wallpaper. Its `links` are made only when you apply it.

Start typing to search themes by name or description. Enter or **Apply theme** keeps it; Esc or a click on the backdrop brings back the theme you started with.

```sh
sylvaris theme set noir      # apply without the picker
sylvaris theme cycle         # the next one
sylvaris theme list
sylvaris theme search forest
sylvaris theme new Night Owl                      # a copy of the theme you use now
sylvaris theme edit night-owl colors.accent #ff8800
sylvaris theme edit night-owl alpha.glass 0.4
sylvaris theme duplicate noir
sylvaris theme remove night-owl
```

SylSettings › Look › Appearance lists every theme. **Use** switches to it, **Duplicate** copies it and **New theme** starts from the one you use now. Your own themes also have **Edit** and **Delete**. Edit applies the theme and opens the editor: name, description, wallpaper, the ten colours (type a hex value or click a swatch to mix one from hue, saturation and lightness) and the glass levels. Every change shows at once and is written to the theme's file. A theme that is a link or a file you cannot write, such as one Home Manager made, says "From your config" and only offers Duplicate, so your Nix config stays the source of truth.

Themes are JSON bundles in `~/.config/sylvaris/themes/`. How to write one, and how a theme can switch the rest of your desktop along with it, is in [look and motion](../look.md#theme-bundles).
