# SylGreet

> **Experimental.** Test it on your machine before you depend on it, and keep another way to log in at hand.

A login screen for greetd in the same style as [SylLock](lock.md), on every screen, with what you type mirrored on all of them. The session button in the bottom left (or F2) lists every installed session, such as Hyprland, niri or sway; the up and down arrows pick the user. Type the password and it starts that session, and remembers both for next time.

Turn it on in NixOS:

```nix
imports = [ sylvaris.nixosModules.sylvaris ];
programs.sylvaris.greeter = {
  enable = true;
  user = "you";
  session = "hyprland";
  swayConfig = ''
    output eDP-1 disable
    output DP-1 mode 2560x1440@165Hz position 0 0
    input * xkb_layout pl
  '';
};
```

It runs in a small sway session. `swayConfig` sets up its screens and keyboard, and `environment` adds variables such as `WLR_NO_HARDWARE_CURSORS = "1"` for NVIDIA. Its config lives under `/etc/sylvaris-greet`, and reboot and shutdown are one click away.

It always looks like your desktop. Whenever you switch themes, Sylvaris copies the theme, its wallpaper and your avatar to your own folder, `/var/lib/sylvaris-greet/shared/<user>` (`greeterShare` in `config.json`). The shared folder belongs to the `users` group (`greeter.shareGroup`) and is sticky, so each member can create only their own folder, and Sylvaris refuses one that is a link or belongs to someone else. The login screen shows the look of the user it has selected. `greeter.wallpaper` pins one image instead.

Without NixOS, [install.md](../install.md#sylgreet-the-login-screen) shows the greetd setup.
