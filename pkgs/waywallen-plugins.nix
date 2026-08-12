{
  lib,
  llvmPackages_latest,
  cmake,
  pkg-config,
  ffmpeg,
  libGL, # EGL headers (via libGL/mesa)
  libgbm, # gbm.pc (mesa-libgbm)
  vulkan-loader,
  vulkan-headers,
  libva,
  libpulseaudio,
  glslang, # provides glslangValidator, required by wavsen::video
  ninja,
  src,
  rstd-src,
  vma-src,
  vvk-src,
  wavsen-src,
}:
llvmPackages_latest.stdenv.mkDerivation rec {
  pname = "waywallen-plugins";
  version = "0.3.3";

  inherit src;

  hardeningDisable = ["fortify"];

  postPatch = ''
    # Patch top-level CMakeLists.txt:
    #   - Remove the CPackConfig include (unneeded, may pull in cpack)
    substituteInPlace CMakeLists.txt \
      --replace "include(CPackConfig)" "# include(CPackConfig)"

    # Filter out AMD DCC modifiers (vendor ID 0x02, DCC bit 13) from Vulkan format caps:
    substituteInPlace bridge/src/pool_vulkan.c \
      --replace-fail '            if ((ff & want_features) != want_features) continue;' '            if ((ff & want_features) != want_features) continue;
            if (((probed[i].drmFormatModifier >> 56) == 2) && ((probed[i].drmFormatModifier >> 13) & 1)) continue;'
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
    ninja
    glslang # glslangValidator for wavsen shader compilation
    llvmPackages_latest.clang-tools
    llvmPackages_latest.lld
  ];

  buildInputs = [
    ffmpeg
    libGL # EGL headers
    libgbm # GBM (gbm.pc + libgbm)
    vulkan-loader
    vulkan-headers
    libva # wavsen dependency
    libpulseaudio # wavsen dependency
  ];
  cmakeFlags = [
    # Only build the plugins component
    "-DWAYWALLEN_BUILD_DAEMON=OFF"
    "-DWAYWALLEN_BUILD_UI=OFF"
    "-DWAYWALLEN_BUILD_PLUGINS=ON"
    # MPV plugin requires libmpv — skip for now
    "-DWAYWALLEN_BUILD_MPV_PLUGIN=OFF"
    # Point FetchDeps at the pre-fetched Nix store paths
    "-DFETCHDEPS_LOCAL_rstd=${rstd-src}"
    "-DFETCHDEPS_LOCAL_vma=${vma-src}"
    "-DFETCHDEPS_LOCAL_vvk=${vvk-src}"
    "-DFETCHDEPS_LOCAL_wavsen=${wavsen-src}"
    # C++20 module scanning
    "-DCMAKE_CXX_COMPILER_CLANG_SCAN_DEPS=${llvmPackages_latest.clang-tools}/bin/clang-scan-deps"
  ];

  meta = with lib; {
    description = "Renderer plugin binaries (image + video) for waywallen";
    homepage = "https://github.com/waywallen/waywallen";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
