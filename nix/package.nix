{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
  wlr-randr,
  wayvnc,
  openssl,
  iproute2,
  wlsunset,
  networkmanager,
  pulseaudio,
  wl-clipboard,
  udisks,
  libarchive,
  coreutils,
  procps,
  socat,
  pipewire,
  python3,
  curl,
  libnotify,
  glib,
  grim,
  slurp,
  wf-recorder,
  ffmpeg,
  wtype,
  git,
  qt6,
  sylvarisParts ? { },
  commit ? "unknown",
}:

let
  python = python3.withPackages (ps: [ ps.cryptography ]);
  partTools = {
    bar = [
      pulseaudio
      pipewire
      python
      libnotify
    ];
    center = [
      wlr-randr
      wayvnc
      openssl
      iproute2
      networkmanager
      wlsunset
      pulseaudio
      pipewire
      python
      libnotify
      wl-clipboard
    ];
    clock = [
      pipewire
      python
      libnotify
      curl
    ];
    deck = [ ];
    diver = [
      pipewire
      python
      libnotify
    ];
    media = [
      pulseaudio
      pipewire
      python
    ];
    notify = [ ];
    pad = [ ];
    paper = [ ];
    power = [ ];
    lock = [ glib ];
    polkit = [ ];
    clip = [ wl-clipboard ];
    island = [ wtype ];
    viewer = [
      wl-clipboard
      glib
    ];
    files = [
      wl-clipboard
      glib
      python
      udisks
    ];
    archive = [
      libarchive
      python
    ];
    access = [ ];
    fatest = [ ];
    rgb = [ python ];
    plugins = [ git ];
    sync = [
      python
      procps
    ];
    capture = [
      grim
      slurp
      wf-recorder
      ffmpeg
      wl-clipboard
      libnotify
      pulseaudio
    ];
    switcher = [ ];
    settings = [
      wlsunset
      pipewire
      python
      libnotify
      curl
    ];
    theme = [ ];
  };
  tools = lib.unique (
    [
      quickshell
      coreutils
      procps
      socat
    ]
    ++ lib.concatLists (lib.mapAttrsToList (name: lib.optionals (sylvarisParts.${name} or true)) partTools)
  );
in
stdenvNoCC.mkDerivation {
  pname = "sylvaris";
  version = "0.4.2";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../shell
      ../bin
      ../share
    ];
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/sylvaris
    cp -r shell/. $out/share/sylvaris/
    printf '%s\n' ${lib.escapeShellArg commit} > $out/share/sylvaris/COMMIT
    install -Dm755 bin/sylvaris $out/bin/sylvaris
    install -Dm644 share/applications/sylvaris-viewer.desktop $out/share/applications/sylvaris-viewer.desktop
    install -Dm644 share/applications/sylvaris-files.desktop $out/share/applications/sylvaris-files.desktop
    install -Dm644 share/applications/sylvaris-archive.desktop $out/share/applications/sylvaris-archive.desktop
    install -Dm644 share/icons/hicolor/scalable/apps/sylvaris-files.svg $out/share/icons/hicolor/scalable/apps/sylvaris-files.svg
    install -Dm644 share/icons/hicolor/scalable/apps/sylvaris-archive.svg $out/share/icons/hicolor/scalable/apps/sylvaris-archive.svg
    wrapProgram $out/bin/sylvaris \
      --set-default SYLVARIS_DIR $out/share/sylvaris \
      --prefix PATH : ${lib.makeBinPath tools} \
      --prefix QML_IMPORT_PATH : ${qt6.qtmultimedia}/lib/qt-6/qml \
      --prefix QT_PLUGIN_PATH : ${qt6.qtmultimedia}/lib/qt-6/plugins:${qt6.qtimageformats}/lib/qt-6/plugins
    runHook postInstall
  '';

  passthru.parts = builtins.attrNames partTools;

  meta = {
    description = "Modular Quickshell desktop shell for Hyprland, niri and sway";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "sylvaris";
  };
}
