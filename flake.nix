{
  description = "Sylvaris, a modular desktop shell for Hyprland, niri and sway";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAll (pkgs: rec {
        sylstack = pkgs.callPackage ./nix/sylstack.nix { };
        sylvaris = pkgs.callPackage ./nix/package.nix {
          inherit sylstack;
          commit = self.shortRev or self.dirtyShortRev or "unknown";
        };
        default = sylvaris;
      });

      homeManagerModules = {
        sylvaris = import ./nix/hm-module.nix self;
        default = self.homeManagerModules.sylvaris;
      };

      nixosModules = {
        sylvaris = import ./nix/nixos-module.nix self;
        default = self.nixosModules.sylvaris;
      };

      checks = forAll (pkgs: {
        tests =
          pkgs.runCommand "sylvaris-tests"
            {
              nativeBuildInputs = [
                pkgs.nodejs
                pkgs.qt6.qtdeclarative
                pkgs.findutils
                pkgs.libarchive
                pkgs.openssl
                (pkgs.python3.withPackages (ps: [ ps.cryptography ]))
              ];
            }
            ''
              cd ${./.}
              node --test tests/*.test.mjs
              python3 -m unittest discover -s tests -p '*_test.py'
              mkdir -p $TMPDIR/imports
              ln -s $PWD/shell $TMPDIR/imports/qs
              find shell -name '*.qml' -print0 | xargs -0 qmllint -I ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml -I ${self.packages.${pkgs.stdenv.hostPlatform.system}.sylstack}/lib/qt-6/qml -I ${pkgs.qt6.qtmultimedia}/lib/qt-6/qml -I $TMPDIR/imports
              touch $out
            '';

        greeter =
          let
            host = nixpkgs.lib.nixosSystem {
              system = pkgs.stdenv.hostPlatform.system;
              modules = [
                self.nixosModules.sylvaris
                {
                  programs.sylvaris.fileChooser.enable = true;
                  programs.sylvaris.greeter = {
                    enable = true;
                    user = "ada";
                    swayConfig = "output eDP-1 disable";
                    environment.WLR_NO_HARDWARE_CURSORS = "1";
                  };
                  boot.loader.grub.enable = false;
                  fileSystems."/" = {
                    device = "none";
                    fsType = "tmpfs";
                  };
                  system.stateVersion = "25.11";
                }
              ];
            };
            cfg = host.config;
          in
          pkgs.runCommand "sylvaris-greeter" { } ''
            conf=$(grep -o '/nix/store/[^ ]*sylvaris-greet-sway.conf' ${cfg.services.greetd.settings.default_session.command})
            grep -q "sylvaris greet; " $conf
            grep -q "output eDP-1 disable" $conf
            grep -q "SYLVARIS_GREET_USER=ada" ${cfg.services.greetd.settings.default_session.command}
            test "${cfg.services.greetd.settings.default_session.user}" = greeter
            grep -q "SYLVARIS_GREET_SESSIONS=/nix/store/.*/share/wayland-sessions" ${cfg.services.greetd.settings.default_session.command}
            grep -q "export WLR_NO_HARDWARE_CURSORS=1" ${cfg.services.greetd.settings.default_session.command}
            grep -q "sway --unsupported-gpu --config" ${cfg.services.greetd.settings.default_session.command}
            grep -q "SYLVARIS_GREET_SHARED=/var/lib/sylvaris-greet/shared" ${cfg.services.greetd.settings.default_session.command}
            echo '${builtins.toJSON cfg.systemd.tmpfiles.rules}' | grep -q "/var/lib/sylvaris-greet/shared 1775 greeter users"
            grep -q '"greeterShare": ""' ${cfg.environment.etc."sylvaris-greet/sylvaris/config.json".source}
            test -n "${builtins.toString cfg.security.pam.services.sylvaris.unixAuth}"
            grep -q "^cmd=/nix/store/.*/bin/sylvaris choose$" ${cfg.environment.etc."xdg/xdg-desktop-portal-termfilechooser/config".source}
            grep -q "^create_help_file=0$" ${cfg.environment.etc."xdg/xdg-desktop-portal-termfilechooser/config".source}
            grep -q "FileChooser=termfilechooser" ${cfg.environment.etc."xdg/xdg-desktop-portal/hyprland-portals.conf".source}
            grep -q "FileChooser=termfilechooser" ${cfg.environment.etc."xdg/xdg-desktop-portal/niri-portals.conf".source}
            test "${cfg.environment.sessionVariables.GTK_USE_PORTAL}" = 1
            touch $out
          '';

        hm =
          let
            lib = nixpkgs.lib;
            eval = lib.evalModules {
              modules = [
                self.homeManagerModules.sylvaris
                {
                  options = {
                    home.packages = lib.mkOption {
                      type = lib.types.listOf lib.types.package;
                      default = [ ];
                    };
                    xdg.configFile = lib.mkOption {
                      type = lib.types.attrsOf lib.types.anything;
                      default = { };
                    };
                    xdg.dataFile = lib.mkOption {
                      type = lib.types.attrsOf lib.types.anything;
                      default = { };
                    };
                    xdg.mimeApps.defaultApplications = lib.mkOption {
                      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
                      default = { };
                    };
                    assertions = lib.mkOption {
                      type = lib.types.listOf lib.types.anything;
                      default = [ ];
                    };
                  };
                  config = {
                    _module.args.pkgs = pkgs;
                    programs.sylvaris = {
                      enable = true;
                      bar.position = "left";
                      motion.scale = 1.5;
                      deck.hide = "windows";
                      settings.clock.corner = "top-left";
                      defaultViewer = true;
                      defaultFileManager = true;
                      defaultArchiveManager = true;
                    };
                  };
                }
              ];
            };
          in
          pkgs.runCommand "sylvaris-hm" { nativeBuildInputs = [ pkgs.jq ]; } ''
            f=${eval.config.xdg.configFile."sylvaris/config.json".source}
            test "$(jq -r .bar.position $f)" = left
            test "$(jq -r .motion.scale $f)" = 1.5
            test "$(jq -r .deck.hide $f)" = windows
            test "$(jq -r .clock.corner $f)" = top-left
            test "$(jq -r '.pad // "unset"' $f)" = unset
            test ${lib.head eval.config.xdg.mimeApps.defaultApplications."image/png"} = sylvaris-viewer.desktop
            test ${lib.head eval.config.xdg.mimeApps.defaultApplications."video/x-matroska"} = sylvaris-viewer.desktop
            test ${lib.head eval.config.xdg.mimeApps.defaultApplications."inode/directory"} = sylvaris-files.desktop
            test ${lib.head eval.config.xdg.mimeApps.defaultApplications."application/zip"} = sylvaris-archive.desktop
            test ${lib.head eval.config.xdg.mimeApps.defaultApplications."application/vnd.rar"} = sylvaris-archive.desktop
            echo ${lib.escapeShellArg eval.config.xdg.dataFile."dbus-1/services/org.freedesktop.FileManager1.service".text} | grep -q '^Exec=/nix/store/.*/bin/sylvaris filemanager1$'
            touch $out
          '';

        parts =
          let
            full = pkgs.callPackage ./nix/package.nix { };
            lean = full.override {
              sylvarisParts = {
                center = false;
                media = false;
                clip = false;
                capture = false;
                viewer = false;
                files = false;
                archive = false;
              };
            };
          in
          pkgs.runCommand "sylvaris-parts" { } ''
            grep -q wlr-randr ${full}/bin/sylvaris
            grep -q networkmanager ${full}/bin/sylvaris
            grep -q wl-clipboard ${full}/bin/sylvaris
            grep -q libarchive ${full}/bin/sylvaris
            grep -q wlsunset ${lean}/bin/sylvaris
            for tool in wlr-randr networkmanager wl-clipboard libarchive; do
              if grep -q "$tool" ${lean}/bin/sylvaris; then
                echo "$tool is still wrapped with center, media, clip, capture, viewer, files and archive excluded"
                exit 1
              fi
            done
            touch $out
          '';
      });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.nodejs
            pkgs.qt6.qtdeclarative
            self.packages.${pkgs.stdenv.hostPlatform.system}.sylstack
            pkgs.sway-unwrapped
            pkgs.grim
            pkgs.wlr-randr
            pkgs.wlsunset
            pkgs.jq
            pkgs.libnotify
            pkgs.wtype
            pkgs.wlrctl
            pkgs.wayvnc
            pkgs.libarchive
            pkgs.pipewire
            pkgs.wireplumber
            pkgs.wf-recorder
            pkgs.wl-clipboard
            pkgs.foot
            (pkgs.python3.withPackages (ps: [
              ps.cryptography
              ps.vncdotool
            ]))
            pkgs.dbus
          ];
          QML_IMPORT_PATH = "${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
          QT_PLUGIN_PATH = "${pkgs.qt6.qtmultimedia}/lib/qt-6/plugins:${pkgs.qt6.qtimageformats}/lib/qt-6/plugins";
        };
      });
    };
}
