# Keep Awake

With this plugin on, Sylvaris can keep the screen from dimming, locking or going to sleep while you watch a film, give a talk or wait for a long download, with no window that has to stay in front.

Turn it on in SylSettings › Plugins or with `sylvaris plugins enable awake`, then switch it with a command or the SylCenter tile (`center.extra`):

```sh
sylvaris awake            # toggle
sylvaris awake on         # also: off
sylvaris awake state
```

It uses the idle-inhibit protocol, which Hyprland, Sway, niri and other wlroots compositors support, so idle daemons such as hypridle and swayidle wait as well. It stays on until you switch it off or restart the shell, and `holding` in `sylvaris awake state` says whether the compositor took the request.
