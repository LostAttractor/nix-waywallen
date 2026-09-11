{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  autoPatchelfHook,
  makeWrapper,
  unzip,
  autoAddDriverRunpath,
  qt6,
  alsa-lib,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libpulseaudio,
  libva,
  libxkbcommon,
  lz4,
  nspr,
  nss,
  pango,
  sqlite,
  systemd,
  vulkan-loader,
  wayland,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
}:
let
  pname = "waywallen";
  version = "0.3.9";
  oweVersion = "0.2.9";
  owePluginPath = "share/waywallen/plugins/org.waywallen.open-wallpaper-engine";

  releases = {
    x86_64-linux = {
      arch = "x86_64";
      appimageHash = "sha256-499tPXymKD0Owftj/Asgu08ZmHBMuFKPHdsR+ribmt8=";
      oweHash = "sha256-MM/uWgQzIOD7GUtEfMegfexd+KsjgSHy82LI97aCAng=";
    };
    aarch64-linux = {
      arch = "aarch64";
      appimageHash = "sha256-0e3f7t3Qwq6cg20c75bmdbVULLaheWAugP/M4vQWFPA=";
      oweHash = "sha256-wW81CmUsM8W3NPPiHm71XzETlPxQ7+gpzTLwHFSviCc=";
    };
  };

  release =
    releases.${stdenv.hostPlatform.system}
      or (throw "waywallen: unsupported system ${stdenv.hostPlatform.system}");

  sources = {
    appimage = fetchurl {
      url = "https://github.com/waywallen/waywallen/releases/download/v${version}/waywallen-${version}-${release.arch}.AppImage";
      hash = release.appimageHash;
    };
    owe = fetchurl {
      url = "https://github.com/waywallen/open-wallpaper-engine/releases/download/v${oweVersion}/org.waywallen.open-wallpaper-engine-${oweVersion}-linux-${release.arch}.zip";
      hash = release.oweHash;
    };
  };

  appimageContents = appimageTools.extract {
    inherit pname version;
    src = sources.appimage;
  };
in
stdenv.mkDerivation {
  inherit pname version;

  dontUnpack = true;
  dontBuild = true;
  dontWrapQtApps = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    unzip
    autoAddDriverRunpath
  ];

  # Keep the ABI-sensitive Qt, FFmpeg, ICU and OpenSSL libraries bundled.
  # These inputs provide libraries intentionally omitted from the AppImage.
  buildInputs = [
    stdenv.cc.cc.lib
    alsa-lib
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    glib
    gtk3
    libdrm
    libgbm
    libGL
    libpulseaudio
    libva
    libxkbcommon
    lz4
    nspr
    nss
    pango
    sqlite
    systemd
    vulkan-loader
    wayland
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
    # linuxdeploy omitted four private Qt libraries required by bundled QML modules.
    qt6.qtdeclarative
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -a ${appimageContents}/usr/. "$out/"
    chmod -R u+w "$out"

    owe="$out/${owePluginPath}"
    mkdir -p "$owe"
    unzip -q ${sources.owe} -d "$owe"

    # Use the host Vulkan loader and drivers. CEF's ANGLE libraries stay bundled.
    rm -f \
      "$owe/lib/weweb/libvulkan.so.1" \
      "$owe/lib/weweb/libvk_swiftshader.so" \
      "$owe/lib/weweb/vk_swiftshader_icd.json"
    ln -s ${vulkan-loader}/lib/libvulkan.so.1 "$out/lib/libvulkan.so.1"
    ln -s ${vulkan-loader}/lib/libvulkan.so.1 "$owe/lib/weweb/libvulkan.so.1"

    runHook postInstall
  '';

  postFixup = ''
    # The renderers load their audio backend at runtime, which autoPatchelf cannot detect.
    for renderer in \
      "$out/bin/waywallen-video-renderer" \
      "$out/${owePluginPath}/bin/waywallen-wescene-renderer"
    do
      wrapProgram "$renderer" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libpulseaudio ]}"
    done

    # CEF also loads PulseAudio at runtime, while ANGLE dlopens the native EGL dispatcher.
    wrapProgram "$out/${owePluginPath}/lib/weweb/waywallen-weweb-renderer" \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          libGL
          libpulseaudio
        ]
      }"

    appWrapperArgs=(
      --prefix LD_LIBRARY_PATH : "$out/lib"
      --suffix LIBVA_DRIVERS_PATH : "/run/opengl-driver/lib/dri"
      --set QT_PLUGIN_PATH "$out/plugins"
      --set QML_IMPORT_PATH "$out/qml"
      --set QML2_IMPORT_PATH "$out/qml"
    )

    wrapProgram "$out/bin/waywallen-ui" "''${appWrapperArgs[@]}"
    wrapProgram "$out/bin/waywallen" \
      "''${appWrapperArgs[@]}" \
      --add-flags "--ui $out/bin/waywallen-ui --plugin $out/share/waywallen"
  '';

  meta = {
    description = "Waywallen wallpaper manager with the open-wallpaper-engine plugin";
    homepage = "https://github.com/waywallen/waywallen";
    license = with lib.licenses; [
      mit
      gpl2Only
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = builtins.attrNames releases;
    mainProgram = "waywallen";
  };
}
