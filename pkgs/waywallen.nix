{
  lib,
  llvmPackages_22,
  lito,
  fetchLitoDeps,
  cmake,
  ninja,
  pkg-config,
  glslang,
  git,
  autoPatchelfHook,
  autoAddDriverRunpath,
  qt6,
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
let
  pname = "waywallen";
  version = "0.3.9";
  patches = [ ./patches/waywallen-external-daemon.patch ];
  litoDeps = fetchLitoDeps {
    inherit
      pname
      version
      src
      patches
      ;
    hash = "sha256-+y/3Sk4bEVdT6dgPVTDiq0XnZz6oveWsG8B5wQnVs18=";
  };
in
llvmPackages_22.stdenv.mkDerivation {
  inherit
    pname
    version
    src
    patches
    ;

  nativeBuildInputs = [
    lito
    cmake
    ninja
    pkg-config
    glslang
    git
    autoPatchelfHook
    autoAddDriverRunpath
    llvmPackages_22.llvm
    llvmPackages_22.lld
    llvmPackages_22.clang-tools
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

  dontUseCmakeConfigure = true;
  dontUseNinjaBuild = true;
  dontUseNinjaInstall = true;
  dontWrapQtApps = true;
  hardeningDisable = [ "fortify" ];

  # Diagnostic source locations must not retain the build-only dependency bundle.
  env.NIX_CFLAGS_COMPILE = "-ffile-prefix-map=${litoDeps}=lito-deps";
  disallowedReferences = [ litoDeps ];

  configurePhase = ''
    runHook preConfigure
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    for repo in ${litoDeps}/v1/git/*; do
      git config --global --add safe.directory "$repo"
    done
    # Qt's split Nix outputs keep this find-module outside qtbase's module path.
    mkdir -p "$TMPDIR/cmake/WrapProtoc"
    echo 'include("${qt6.qtgrpc}/lib/cmake/Qt6/FindWrapProtoc.cmake")' \
      > "$TMPDIR/cmake/WrapProtoc/WrapProtocConfig.cmake"
    export CMAKE_PREFIX_PATH="$TMPDIR/cmake''${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
    litoFlags=(--frozen --source-bundle ${litoDeps} --profile release -j "$NIX_BUILD_CORES")
    runHook postConfigure
  '';
  buildPhase = ''
    runHook preBuild
    lito build "''${litoFlags[@]}"
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    lito install "''${litoFlags[@]}" --prefix "$out"
    ln -s ${waywallen-daemon}/bin/waywallen "$out/bin/waywallen"
    runHook postInstall
  '';
  postFixup = ''
    wrapQtApp "$out/bin/waywallen-ui"
    wrapProgram "$out/bin/waywallen-video-renderer" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libpulseaudio ]}
  '';

  passthru = { inherit litoDeps; };
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
