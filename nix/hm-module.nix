self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.sylvaris;
  json = pkgs.formats.json { };
  parts = (cfg.settings.parts or { }) // cfg.parts;
  schemaFile = lib.importJSON ./schema.json;
  schema = builtins.removeAttrs schemaFile [ "version" ];
  typeOf =
    v:
    if builtins.isBool v then
      lib.types.bool
    else if builtins.isInt v || builtins.isFloat v then
      lib.types.number
    else if builtins.isString v then
      lib.types.str
    else if builtins.isList v then
      lib.types.listOf lib.types.anything
    else
      lib.types.attrsOf lib.types.anything;
  optionsFor =
    path: v:
    if builtins.isAttrs v && v != { } then
      lib.mapAttrs (k: optionsFor (path ++ [ k ])) v
    else
      lib.mkOption {
        type = lib.types.nullOr (typeOf v);
        default = null;
        description = "Sets ${lib.concatStringsSep "." path} in config.json. Sylvaris uses ${builtins.toJSON v} when this is left unset.";
      };
  prune =
    v:
    if builtins.isAttrs v then
      lib.filterAttrs (_: x: x != null && x != { }) (lib.mapAttrs (_: prune) v)
    else
      v;
  typed = prune (lib.getAttrs (builtins.attrNames schema) cfg);
  mimesOf =
    file:
    lib.filter (m: m != "") (
      lib.splitString ";" (
        lib.removePrefix "MimeType=" (
          lib.findFirst (lib.hasPrefix "MimeType=") "" (lib.splitString "\n" (builtins.readFile file))
        )
      )
    );
  viewerMimes = mimesOf ../share/applications/sylvaris-viewer.desktop;
  archiveMimes = mimesOf ../share/applications/sylvaris-archive.desktop;
in
{
  options.programs.sylvaris = lib.mapAttrs (k: optionsFor [ k ]) schema // {
    enable = lib.mkEnableOption "Sylvaris, a modular Quickshell desktop shell";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.sylvaris;
      defaultText = lib.literalExpression "sylvaris.packages.\${system}.sylvaris";
      description = "The Sylvaris package to install.";
    };

    settings = lib.mkOption {
      type = json.type;
      default = { };
      description = "Written to ~/.config/sylvaris/config.json. See the README for every key.";
    };

    parts = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      example = {
        pad = false;
        media = false;
      };
      description = "Parts to exclude (false) or keep (true), written to the parts key of config.json. Tools only excluded parts need are left off the package's PATH.";
    };

    defaultViewer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Make SylViewer the default app for the images and videos it opens, through xdg.mimeApps.";
    };

    defaultFileManager = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Make SylFiles the default app for folders, through xdg.mimeApps.";
    };

    defaultArchiveManager = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Make SylArchive the default app for zip, rar, 7z, tar and the other archives it opens, through xdg.mimeApps.";
    };

    themes = lib.mkOption {
      type = lib.types.attrsOf json.type;
      default = { };
      description = "Theme bundles written to ~/.config/sylvaris/themes/<name>.json. The attribute name becomes the theme id. `links` maps paths under ~/.config to the files they point to while the theme is active.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (name: lib.elem name cfg.package.parts) (lib.attrNames parts);
        message = "programs.sylvaris.parts: unknown part; valid parts are ${lib.concatStringsSep ", " cfg.package.parts}";
      }
    ];

    home.packages = [ (cfg.package.override { sylvarisParts = parts; }) ];

    xdg.mimeApps.defaultApplications = lib.mkMerge [
      (lib.mkIf (cfg.defaultViewer && (parts.viewer or true)) (
        lib.genAttrs viewerMimes (_: [ "sylvaris-viewer.desktop" ])
      ))
      (lib.mkIf (cfg.defaultFileManager && (parts.files or true)) {
        "inode/directory" = [ "sylvaris-files.desktop" ];
      })
      (lib.mkIf (cfg.defaultArchiveManager && (parts.archive or true)) (
        lib.genAttrs archiveMimes (_: [ "sylvaris-archive.desktop" ])
      ))
    ];

    xdg.configFile = lib.mkMerge [
      {
        "sylvaris/config.json".source = json.generate "sylvaris-config.json" (
          { inherit (schemaFile) version; } // lib.recursiveUpdate typed cfg.settings // lib.optionalAttrs (parts != { }) { inherit parts; }
        );
      }
      (lib.mapAttrs' (
        name: theme:
        lib.nameValuePair "sylvaris/themes/${name}.json" {
          source = json.generate "sylvaris-theme-${name}.json" (
            {
              version = 1;
              id = name;
            }
            // theme
          );
        }
      ) cfg.themes)
    ];
  };
}
