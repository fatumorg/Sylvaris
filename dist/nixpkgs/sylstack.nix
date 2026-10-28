{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  wayland-scanner,
  qt6,
  kdePackages,
  pipewire,
  linux-pam,
  wayland,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "sylstack";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "fatumorg";
    repo = "Sylvaris";
    tag = "v1.5.0";
    hash = lib.fakeHash;
  };

  sourceRoot = "${finalAttrs.src.name}/stack";

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
    description = "Qt 6 runtime for QML desktop shells on Wayland";
    homepage = "https://sylvaris.fatum.cc";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ naxce ];
    platforms = lib.platforms.linux;
    mainProgram = "sylstack";
  };
})
