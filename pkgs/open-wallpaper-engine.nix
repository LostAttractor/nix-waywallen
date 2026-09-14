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
  makeWrapper,
  waywallen-unwrapped,
  ffmpeg,
  lz4,
  fontconfig,
  freetype,
  libgbm,
  libGL,
  vulkan-headers,
  vulkan-loader,
  wayland,
  libpulseaudio,
  libva,
  alsa-lib,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libdrm,
  libxkbcommon,
  nspr,
  nss,
  pango,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
  src,
}:
let
  pname = "waywallen-open-wallpaper-engine";
  version = "0.2.10";
  litoDeps = fetchLitoDeps {
    inherit pname version src;
    hash =
      {
        x86_64-linux = "sha256-36gaOh5V+i3V8d3hHeHEBkDLh0pZwPNiCtnM+JapmPs=";
        aarch64-linux = "sha256-3LFm0aBeVbBmujGpoxrv9aoSkOjbWMwepOU0YtpJgVE=";
      }
      .${llvmPackages_22.stdenv.hostPlatform.system};
  };
in
llvmPackages_22.stdenv.mkDerivation {
  inherit pname version src;

  postPatch = ''
    # Match QuickJS's install directory to the config-directory in lito.toml.
    substituteInPlace lito.toml \
      --replace-fail 'cache = { BUILD_SHARED_LIBS = false,' \
        'cache = { CMAKE_INSTALL_LIBDIR = "lib", BUILD_SHARED_LIBS = false,'
  '';

  nativeBuildInputs = [
    lito
    cmake
    ninja
    pkg-config
    glslang
    git
    llvmPackages_22.llvm
    llvmPackages_22.lld
    llvmPackages_22.clang-tools
    autoPatchelfHook
    autoAddDriverRunpath
    makeWrapper
  ];
  buildInputs = [
    waywallen-unwrapped
    ffmpeg
    lz4
    fontconfig
    freetype
    libgbm
    libGL
    vulkan-headers
    vulkan-loader
    wayland
    libpulseaudio
    libva
    # Runtime libraries for the upstream CEF SDK used by the web renderer.
    alsa-lib
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libxkbcommon
    nspr
    nss
    pango
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
  ];

  dontUseCmakeConfigure = true;
  dontUseNinjaBuild = true;
  dontUseNinjaInstall = true;
  hardeningDisable = [ "fortify" ];
  # CEF uses -Werror, while Nix's Clang wrapper supplies the standard library itself.
  env.NIX_CFLAGS_COMPILE = toString [
    "-Wno-unused-command-line-argument"
    "-ffile-prefix-map=${litoDeps}=lito-deps"
  ];
  disallowedReferences = [ litoDeps ];

  configurePhase = ''
    runHook preConfigure
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    for repo in ${litoDeps}/v1/git/*; do
      git config --global --add safe.directory "$repo"
    done
    litoFlags=(--frozen --source-bundle ${litoDeps} --profile release -j "$NIX_BUILD_CORES")
    runHook postConfigure
  '';
  buildPhase = ''
    runHook preBuild
    lito build "''${litoFlags[@]}" \
      -p owe-waywallen-scene-renderer -p owe-waywallen-web-renderer
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    lito install "''${litoFlags[@]}" -p owe-waywallen-plugin --prefix "$out"

    # Use the host Vulkan loader and drivers, retaining CEF's ANGLE libraries.
    rm -f "$out/lib/weweb/"{libvulkan.so.1,libvk_swiftshader.so,vk_swiftshader_icd.json}
    ln -s ${vulkan-loader}/lib/libvulkan.so.1 "$out/lib/weweb/libvulkan.so.1"
    runHook postInstall
  '';
  postFixup = ''
    wrapProgram "$out/bin/waywallen-wescene-renderer" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libpulseaudio ]}
    wrapProgram "$out/lib/weweb/waywallen-weweb-renderer" \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libGL
          libpulseaudio
        ]
      }
  '';

  passthru = { inherit litoDeps; };
  meta = {
    description = "Wallpaper Engine scene and web renderers for Waywallen";
    homepage = "https://github.com/waywallen/open-wallpaper-engine";
    license = lib.licenses.gpl2Only;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
