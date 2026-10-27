{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  qt6,
  kdePackages,
  pipewire,
  linux-pam,
  wayland,
  wayland-scanner,
}:

stdenv.mkDerivation {
  pname = "sylstack";
  version = "1.0.1";

  src = lib.fileset.toSource {
    root = ../stack;
    fileset = ../stack;
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    wayland-scanner
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtsvg
    qt6.qtwayland
    kdePackages.layer-shell-qt
    kdePackages.polkit-qt-1
    pipewire
    linux-pam
    wayland
  ];

  cmakeFlags = [ (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release") ];

  meta = {
    description = "Small Qt Quick runtime for Wayland desktop shells, made for Sylvaris";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "sylstack";
  };
}
