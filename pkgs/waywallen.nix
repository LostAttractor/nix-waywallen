{
  lib,
  buildLitoPackage,
  qt6,
  qadwaitadecorations-qt6,
  protobuf,
  ffmpeg,
  libgbm,
  libGL,
  vulkan-headers,
  vulkan-loader,
  libpulseaudio,
  libva,
  linuxHeaders,
  waywallen-daemon,
  src,
}:
buildLitoPackage {
  pname = "waywallen";
  version = "0.3.9";
  inherit src;
  patches = [ ./patches/waywallen-external-daemon.patch ];
  litoHash = "sha256-b98ld+64aY5G+xWpftwx5I7BUemF67xs+E/wTVA4Nfc=";

  nativeBuildInputs = [
    protobuf
    qt6.qttools
    qt6.wrapQtAppsHook
  ];
  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtgrpc
    qt6.qtimageformats
    qt6.qtwebsockets
    qadwaitadecorations-qt6
    ffmpeg
    libgbm
    libGL
    vulkan-headers
    vulkan-loader
    libpulseaudio
    libva
    # Qt moc depfiles resolve glibc's symlinks to the kernel header output.
    linuxHeaders
  ];

  dontWrapQtApps = true;

  postConfigure = ''
    # Qt's split Nix outputs keep this find-module outside qtbase's module path.
    mkdir -p "$TMPDIR/cmake/WrapProtoc"
    echo 'include("${qt6.qtgrpc}/lib/cmake/Qt6/FindWrapProtoc.cmake")' \
      > "$TMPDIR/cmake/WrapProtoc/WrapProtocConfig.cmake"
    export CMAKE_PREFIX_PATH="$TMPDIR/cmake''${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
  '';
  postInstall = ''
    ln -s ${waywallen-daemon}/bin/waywallen "$out/bin/waywallen"
  '';
  postFixup = ''
    wrapQtApp "$out/bin/waywallen-ui"
    wrapProgram "$out/bin/waywallen-video-renderer" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libpulseaudio ]}
  '';

  meta = {
    description = "Waywallen daemon, Qt/QML UI and renderer plugins";
    homepage = "https://github.com/waywallen/waywallen";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "waywallen";
  };
}
