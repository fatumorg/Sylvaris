{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  sylstack,
  wlr-randr,
  brightnessctl,
  ddcutil,
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
  cava,
  git,
  qt6,
  kdePackages,
}:

let
  python = python3.withPackages (ps: [
    ps.cryptography
    ps.pygobject3
  ]);
  partTools = {
    bar = [
      pulseaudio
      pipewire
      python
      libnotify
    ];
    center = [
      wlr-randr
      brightnessctl
      ddcutil
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
    island = [
      wtype
      wl-clipboard
      libnotify
    ];
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
    widgets = [ cava ];
    notes = [ ];
    access = [ ];
    fatest = [ ];
    rgb = [ python ];
    temp = [ ];
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
      sylstack
      coreutils
      procps
    ]
    ++ lib.concatLists (lib.attrValues partTools)
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "sylvaris";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "fatumorg";
    repo = "Sylvaris";
    tag = "v${finalAttrs.version}";
    hash = lib.fakeHash;
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/sylvaris
    cp -r shell/. $out/share/sylvaris/
    echo unknown > $out/share/sylvaris/COMMIT
    install -Dm755 bin/sylvaris $out/bin/sylvaris
    install -Dm644 -t $out/share/applications share/applications/*.desktop
    install -Dm644 share/icons/hicolor/scalable/apps/sylvaris-files.svg $out/share/icons/hicolor/scalable/apps/sylvaris-files.svg
    install -Dm644 share/icons/hicolor/scalable/apps/sylvaris-archive.svg $out/share/icons/hicolor/scalable/apps/sylvaris-archive.svg
    install -Dm644 share/icons/hicolor/scalable/apps/sylvaris-notes.svg $out/share/icons/hicolor/scalable/apps/sylvaris-notes.svg
    wrapProgram $out/bin/sylvaris \
      --set-default SYLVARIS_DIR $out/share/sylvaris \
      --prefix PATH : ${lib.makeBinPath tools} \
      --prefix QML_IMPORT_PATH : ${qt6.qtmultimedia}/lib/qt-6/qml:${kdePackages.syntax-highlighting}/lib/qt-6/qml \
      --prefix QT_PLUGIN_PATH : ${qt6.qtmultimedia}/lib/qt-6/plugins:${qt6.qtimageformats}/lib/qt-6/plugins
    runHook postInstall
  '';

  meta = {
    description = "Modular desktop shell for Hyprland, niri and sway, built on SylStack";
    homepage = "https://sylvaris.fatum.cc";
    changelog = "https://github.com/fatumorg/Sylvaris/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ naxce ];
    platforms = lib.platforms.linux;
    mainProgram = "sylvaris";
  };
})
