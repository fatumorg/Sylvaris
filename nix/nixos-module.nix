self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.sylvaris;
  greet = cfg.greeter;
  json = pkgs.formats.json { };
  package = self.packages.${pkgs.stdenv.hostPlatform.system}.sylvaris;
  configDir = "/etc/sylvaris-greet";
  shared = "/var/lib/sylvaris-greet/shared";
  swayConfig = pkgs.writeText "sylvaris-greet-sway.conf" ''
    default_border none
    ${greet.swayConfig}
    exec "${lib.getExe' package "sylvaris"} greet; ${lib.getExe' pkgs.sway "swaymsg"} exit"
  '';
  launch = pkgs.writeShellScript "sylvaris-greet" ''
    ${lib.concatStrings (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}\n") greet.environment)}
    export XDG_CONFIG_HOME=${configDir}
    export SYLVARIS_GREET_STATE=/var/lib/sylvaris-greet
    export SYLVARIS_GREET_SESSIONS=${config.services.displayManager.sessionData.desktops}/share/wayland-sessions
    ${lib.optionalString (greet.user != "") "export SYLVARIS_GREET_USER=${lib.escapeShellArg greet.user}"}
    ${lib.optionalString (greet.session != "") "export SYLVARIS_GREET_SESSION=${lib.escapeShellArg greet.session}"}
    ${lib.optionalString (greet.wallpaper != null) "export SYLVARIS_GREET_WALLPAPER=${greet.wallpaper}"}
    exec ${lib.getExe' pkgs.sway "sway"} --unsupported-gpu --config ${swayConfig}
  '';
in
{
  options.programs.sylvaris = {
    lock.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add the sylvaris PAM service that SylLock checks passwords with.";
    };

    cameraSwitch.enable = lib.mkEnableOption "switching USB cameras off and on for members of the users group, used by sylvaris privacy";

    fileChooser.enable = lib.mkEnableOption "SylFiles as the open and save dialog of every app that asks the desktop portal, through xdg-desktop-portal-termfilechooser";

    greeter = {
      enable = lib.mkEnableOption "SylGreet as the greetd login screen, running in sway on every screen";

      user = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "User picked on the first start; afterwards the last user who logged in is picked.";
      };

      session = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "hyprland";
        description = "Wayland session file name (without .desktop) picked on the first start.";
      };

      wallpaper = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Image behind the login screen; defaults to the wallpaper of the theme you last used.";
      };

      swayConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        example = "output eDP-1 disable\ninput * xkb_layout pl";
        description = "Extra sway config for the login screen, such as outputs to turn off or the keyboard layout.";
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          WLR_NO_HARDWARE_CURSORS = "1";
        };
        description = "Environment for the login screen's sway, for example what an NVIDIA card needs.";
      };

      shareGroup = lib.mkOption {
        type = lib.types.str;
        default = "users";
        description = "Group whose members' Sylvaris copies their current theme, wallpaper and avatar to the login screen.";
      };

      settings = lib.mkOption {
        type = json.type;
        default = { };
        description = "config.json for the login screen, for example glass settings.";
      };

    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.lock.enable {
      security.pam.services.sylvaris = { };
    })
    (lib.mkIf cfg.cameraSwitch.enable {
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTR{bInterfaceClass}=="0e", RUN+="${lib.getExe' pkgs.coreutils "chgrp"} users /sys%p/../authorized", RUN+="${lib.getExe' pkgs.coreutils "chmod"} g+w /sys%p/../authorized"
      '';
    })
    (lib.mkIf cfg.fileChooser.enable {
      xdg.portal = {
        enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-termfilechooser ];
        config = lib.genAttrs [ "common" "hyprland" "sway" "niri" ] (_: {
          "org.freedesktop.impl.portal.FileChooser" = lib.mkForce [ "termfilechooser" ];
        });
      };
      environment.etc."xdg/xdg-desktop-portal-termfilechooser/config".text = ''
        [filechooser]
        cmd=${lib.getExe' package "sylvaris"} choose
        default_dir=$HOME
        create_help_file=0
        open_mode=suggested
        save_mode=suggested
      '';
      environment.sessionVariables = {
        GTK_USE_PORTAL = "1";
        GDK_DEBUG = "portals";
      };
    })
    (lib.mkIf greet.enable {
      services.displayManager.enable = true;
      services.greetd = {
        enable = true;
        settings.default_session = {
          command = "${launch}";
          user = "greeter";
        };
      };
      systemd.tmpfiles.rules = [
        "d /var/lib/sylvaris-greet 0755 greeter greeter -"
        "d ${shared} 2775 greeter ${greet.shareGroup} -"
      ];
      environment.etc."sylvaris-greet/sylvaris/config.json".source = json.generate "sylvaris-greet-config.json" (
        {
          version = 1;
          themesDir = "${shared}/themes";
          themeStateFile = "${shared}/theme";
          avatar = "${shared}/avatar";
          greeterShare = "";
        }
        // greet.settings
      );
    })
  ];
}
