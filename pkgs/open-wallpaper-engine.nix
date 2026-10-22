{
  lib,
  stdenv,
  buildLitoPackage,
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
buildLitoPackage {
  pname = "waywallen-open-wallpaper-engine";
  version = "0.3.1";
  inherit src;
  litoHash =
    {
      x86_64-linux = "sha256-DIXzmk48FXzQTVEpK6td70TybDBAChIGS3xsFgWl/j4=";
      aarch64-linux = "sha256-5F49+QME/e2GzT6hATEfKCYkqnzU9z8D+xwSRfDVnh8=";
    }
    .${stdenv.hostPlatform.system};

  nativeBuildInputs = [ makeWrapper ];
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

  # CEF uses -Werror, while Nix's Clang wrapper supplies the standard library itself.
  env.NIX_CFLAGS_COMPILE = "-Wno-unused-command-line-argument";
  litoFlags = "-p owe-waywallen-plugin";

  postInstall = ''
    # Use the host Vulkan loader and drivers, retaining CEF's ANGLE libraries.
    rm -f "$out/lib/weweb/"{libvulkan.so.1,libvk_swiftshader.so,vk_swiftshader_icd.json}
    ln -s ${vulkan-loader}/lib/libvulkan.so.1 "$out/lib/weweb/libvulkan.so.1"
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
