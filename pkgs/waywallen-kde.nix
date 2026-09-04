{
  lib,
  stdenv,
  cmake,
  pkg-config,
  qt6,
  libGL,
  vulkan-loader,
  src,
}:

stdenv.mkDerivation {
  pname = "waywallen-display-kde";
  version = "0.3.3";

  inherit src;

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    libGL
    vulkan-loader
  ];

  cmakeFlags = [
    "-DWAYWALLEN_DISPLAY_PLUGIN_QML=ON"
    "-DQML_INSTALL_DIR=${builtins.placeholder "out"}/${qt6.qtbase.qtQmlPrefix}"
  ];

  postInstall = ''
    cmake --install . \
      --component kde_extension \
      --prefix "$out/share/plasma/wallpapers"
  '';

  meta = with lib; {
    description = "waywallen-display KDE (QML) plugin";
    homepage = "https://github.com/waywallen/waywallen-display";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
