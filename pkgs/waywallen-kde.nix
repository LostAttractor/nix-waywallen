{ lib
, stdenv
, cmake
, pkg-config
, qt6
, vulkan-headers
, libGL
, libgbm
, vulkan-loader
, src
}:

stdenv.mkDerivation {
  pname = "waywallen-display-kde";
  version = "0.3.1";

  inherit src;

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    vulkan-headers
    libGL
    libgbm
    vulkan-loader
  ];

  cmakeFlags = [
    "-DWAYWALLEN_DISPLAY_PLUGIN_QML=ON"
    "-DWAYWALLEN_DISPLAY_BUILD_TESTS=OFF"
    "-DWAYWALLEN_DISPLAY_BUILD_EXAMPLES=OFF"
  ];

  postInstall = ''
    mkdir -p $out/share/plasma/wallpapers/org.waywallen.kde
    cp -r ../extensions/kde/package/* $out/share/plasma/wallpapers/org.waywallen.kde/

    mkdir -p $out/${qt6.qtbase.qtQmlPrefix}
    mv $out/lib/qt6/qml/* $out/${qt6.qtbase.qtQmlPrefix}/
    rm -rf $out/lib/qt6
  '';

  meta = with lib; {
    description = "waywallen-display KDE (QML) plugin";
    homepage = "https://github.com/waywallen/waywallen-display";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
