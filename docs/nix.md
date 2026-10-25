# Nix and Home Manager

Sylvaris is a flake. It provides a package, a Home Manager module for the shell, and a NixOS module for the lock screen's PAM service and the SylGreet login screen.

## Home Manager

```nix
{
  inputs.sylvaris.url = "github:fatumorg/Sylvaris";

  outputs = { sylvaris, ... }: {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      modules = [
        sylvaris.homeManagerModules.sylvaris
        {
          programs.sylvaris = {
            enable = true;
            bar.position = "top";
            deck = { enabled = true; hide = "windows"; };
            keybinds = { "switcher next" = "ALT+Tab"; "clip toggle" = "SUPER+V"; };
            parts = { island = true; media = false; };
          };
        }
      ];
    };
  };
}
```

Then start `sylvaris` from your compositor (see [getting started](start.md#2-start-it-with-your-compositor)).

### Options

| Option | What it does |
|---|---|
| `programs.sylvaris.enable` | install Sylvaris and write its config |
| `programs.sylvaris.package` | the package to use; defaults to this flake's |
| `programs.sylvaris.parts` | parts to keep (`true`) or leave out (`false`); tools only the left-out parts need stay off the package's `PATH`. `island` is off unless you set it `true` |
| `programs.sylvaris.defaultViewer` | make [SylViewer](parts/viewer.md) the default app for images and videos (needs `xdg.mimeApps.enable`) |
| `programs.sylvaris.defaultFileManager` | make [SylFiles](parts/files.md) the default app for folders and for "Show in folder" (`org.freedesktop.FileManager1`) (needs `xdg.mimeApps.enable`) |
| `programs.sylvaris.defaultArchiveManager` | make [SylArchive](parts/archive.md) the default app for zip, rar, 7z, tar and other archives (needs `xdg.mimeApps.enable`) |
| `programs.sylvaris.themes.<id>` | theme bundles, written to `~/.config/sylvaris/themes/<id>.json` ([format](look.md#theme-bundles)) |
| `programs.sylvaris.settings` | any JSON for `config.json`, merged over the typed options below |
| `programs.sylvaris.<setting>` | one typed option for every key in the [settings reference](reference/settings.md), such as `bar.position`, `island.screens` or `capture.codec` |

The typed options are generated from the shell's own defaults, so every setting has one and the module checks its type. Leave an option unset and Sylvaris uses its default. Unknown parts are rejected with the list of valid ones.

Everything you set in Nix lands in `config.json` and becomes the default. Changes you make later in SylSettings are saved as overrides in `settings.json` and win until you remove them (see [configuration](configuration.md)).

### A few examples

```nix
programs.sylvaris = {
  island = { position = "top-center"; screens = "all"; shortcuts = [ "notify" "center" "dnd" ]; };
  screens."DP-2".bar.position = "left";
  plugins.enabled = { diver = true; airpods = true; };
  notifications.corner = "top-right";
  settings.location = { latitude = 52.23; longitude = 21.01; };
  settings.glass = { opacity = 0.5; flow = 0.6; };
  themes.midnight = {
    name = "Midnight";
    colors = { base = "#0f1117"; accent = "#7aa2f7"; text = "#e6e9f2"; };
  };
};
```

## NixOS module

Import it for the lock screen's PAM service and the login screen:

```nix
imports = [ sylvaris.nixosModules.sylvaris ];
```

| Option | Default | What it does |
|---|---|---|
| `programs.sylvaris.lock.enable` | `true` | adds the `sylvaris` PAM service that SylLock checks passwords with |
| `programs.sylvaris.cameraSwitch.enable` | `false` | lets members of `users` switch USB cameras off and on, which `sylvaris privacy` uses |
| `programs.sylvaris.fileChooser.enable` | `false` | makes [SylFiles](parts/files.md#open-and-save-dialogs) the open and save dialog of apps that go through the desktop portal |
| `programs.sylvaris.greeter.enable` | `false` | SylGreet as the greetd login screen, in sway on every screen |
| `programs.sylvaris.greeter.user` | `""` | user picked on the first start; afterwards the last one who logged in |
| `programs.sylvaris.greeter.session` | `""` | session file name, without `.desktop`, picked on the first start |
| `programs.sylvaris.greeter.wallpaper` | `null` | an image to always use; otherwise your last theme's wallpaper |
| `programs.sylvaris.greeter.swayConfig` | `""` | extra sway config, such as outputs to turn off or the keyboard layout |
| `programs.sylvaris.greeter.environment` | `{}` | environment for the login screen's sway, such as what an NVIDIA card needs |
| `programs.sylvaris.greeter.shareGroup` | `users` | group whose members' Sylvaris shares its theme with the login screen |
| `programs.sylvaris.greeter.settings` | `{}` | `config.json` for the login screen, for example glass settings |

See [SylGreet](parts/greet.md) for a full example.

## Just the package

`sylvaris.packages.${system}.sylvaris` is the shell with every runtime tool on its `PATH`. `nix run github:fatumorg/Sylvaris` starts it once to try it out.
