# SylTheme

`sylvaris theme` opens the theme picker on the focused screen with the current theme in front. The arrow keys, the mouse wheel, dragging or clicking a side card move the carousel. Once it rests for half a second, the whole desktop previews that theme's colours and wallpaper. Its `links` are made only when you apply it.

Start typing to search themes by name or description. Enter or **Apply theme** keeps it; Esc or a click on the backdrop brings back the theme you started with.

```sh
sylvaris theme set noir      # apply without the picker
sylvaris theme cycle         # the next one
sylvaris theme list
sylvaris theme search forest
```

Themes are JSON bundles in `~/.config/sylvaris/themes/`. How to write one, and how a theme can switch the rest of your desktop along with it, is in [look and motion](../look.md#theme-bundles).
