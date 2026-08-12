{
  lib,
  stdenv,
  llvmPackages_latest,
  callPackage,
  cmake,
  pkg-config,
  ninja,
  freetype,
  lz4,
  fontconfig,
  ffmpeg,
  vulkan-loader,
  vulkan-headers,
  libpulseaudio, # wavsen audio backend
  libva, # wavsen VA-API dep
  expat,
  libgbm, # wavsen GBM dep (gbm.pc)
  libGL,
  autoPatchelfHook,
  # CEF runtime deps — autoPatchelfHook resolves libcef.so's NEEDED entries against these
  alsa-lib,
  atk,
  cairo,
  cups,
  dbus,
  glib,
  gtk3,
  libdrm,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  wayland,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
  glslang, # provides glslangValidator for wavsen GLSL→SPIR-V compilation
  waywallen-plugins, # provides waywallen::bridge headers/cmake config
  patchelf,
  src,
}: let
  # All FETCHDEPS_LOCAL_* paths come from upstream deps.json — bump the
  # open-wallpaper-engine input to refresh pins.
  fetchDep = callPackage ./fetch-upstream-deps.nix {
    depsJson = builtins.fromJSON (builtins.readFile "${src}/deps.json");
  };

  deps = {
    rstd = fetchDep "rstd";
    wavsen = fetchDep "wavsen";
    vma = fetchDep "vma";
    vvk = fetchDep "vvk";
    eigen = fetchDep "eigen";
    spirv_reflect = fetchDep "spirv_reflect";
    glslang_src = fetchDep "glslang";
    quickjs = fetchDep "quickjs";

    # CEF is a prebuilt binary distro; autoPatchelfHook rewrites interpreter /
    # NEEDED paths so libcef.so can resolve against nixpkgs libraries.
    cef = stdenv.mkDerivation {
      pname = "cef-minimal";
      version = "vendor";
      src = fetchDep "cef";
      nativeBuildInputs = [autoPatchelfHook];
      buildInputs = [
        alsa-lib
        atk
        cairo
        cups
        dbus
        expat
        fontconfig
        glib
        gtk3
        libdrm
        libxkbcommon
        mesa
        nspr
        nss
        pango
        wayland
        libx11
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxrandr
        libxcb
      ];
      # src is already the unpacked CEF tree from fetch-upstream-deps.
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out
        cp -a $src/. $out/
      '';
    };
  };
in
  llvmPackages_latest.stdenv.mkDerivation {
    pname = "waywallen-open-wallpaper-engine";
    version = "0.2.3";

    inherit src;

    # wavsen and rstd are compiled as static libs without glibc FORTIFY_SOURCE
    # pass_object_size annotations. With FORTIFY enabled, glibc replaces read/pread/open
    # with annotated variants whose signatures don't match, causing link failures.
    hardeningDisable = ["fortify"];

    # Make FETCHDEPS_LOCAL honor x-cmake.source_subdir (Flatpak already does).
    # Without this, vendored eigen/cef run their full CMakeLists and collide with
    # upstream's post-fetch setup that expects cmake-noop.
    patches = [
      ./patches/owe-fetchdeps-local-source-subdir.patch
    ];

    nativeBuildInputs = [
      cmake
      pkg-config
      ninja
      glslang # glslangValidator for wavsen shader compilation
      llvmPackages_latest.clang-tools # clang-scan-deps for C++20 module scanning
      llvmPackages_latest.lld # faster linker; required by upstream CMake config
      patchelf # used in postFixup to patch libcef.so RPATH
    ];

    buildInputs = [
      freetype
      lz4
      fontconfig
      ffmpeg
      vulkan-loader
      vulkan-headers
      libpulseaudio # wavsen audio backend
      libva # wavsen VA-API dep
      libgbm # wavsen GBM dep
      libGL # also used in postFixup RPATH for libcef.so
      expat
      waywallen-plugins
      libx11 # waywallen-weweb-renderer needs X11 to link libcef_dll_wrapper
    ];

    cmakeFlags = [
      "-DBUILD_WEWEB=ON" # CEF-based web wallpaper renderer
      "-DBUILD_WESCENE=ON" # scene (particle/shader) wallpaper renderer
      "-DBUILD_VIEWER=OFF" # standalone viewer binary; not needed for daemon use
      "-DBUILD_TESTS=OFF"
      "-DBUILD_WAYWALLEN=ON"
      # Point CMake's clang module scanner at the Nix-store clang-tools binary
      "-DCMAKE_CXX_COMPILER_CLANG_SCAN_DEPS=${llvmPackages_latest.clang-tools}/bin/clang-scan-deps"
      # Provide the waywallen IPC bridge cmake config from the plugins package
      "-Dwaywallen-bridge_DIR=${waywallen-plugins}/lib/cmake/waywallen-bridge"
      # Redirect all FetchContent calls to pre-fetched Nix store paths
      "-DFETCHDEPS_LOCAL_rstd=${deps.rstd}"
      "-DFETCHDEPS_LOCAL_wavsen=${deps.wavsen}"
      "-DFETCHDEPS_LOCAL_vma=${deps.vma}"
      "-DFETCHDEPS_LOCAL_vvk=${deps.vvk}"
      "-DFETCHDEPS_LOCAL_eigen=${deps.eigen}"
      "-DFETCHDEPS_LOCAL_spirv_reflect=${deps.spirv_reflect}"
      "-DFETCHDEPS_LOCAL_glslang=${deps.glslang_src}"
      "-DFETCHDEPS_LOCAL_quickjs=${deps.quickjs}"
      "-DFETCHDEPS_LOCAL_cef=${deps.cef}"
    ];

    postFixup = ''
      # CEF's minimal tarball ships libvulkan.so.1 and a SwiftShader software Vulkan
      # implementation (libvk_swiftshader.so + vk_swiftshader_icd.json). These are
      # unpatched upstream binaries with hardcoded non-Nix paths that will fail to
      # load. Remove them and replace libvulkan.so.1 with the system loader.
      rm -f $out/bin/weweb/libvulkan.so.1
      rm -f $out/bin/weweb/libvk_swiftshader.so
      rm -f $out/bin/weweb/vk_swiftshader_icd.json

      # libcef.so probes for Vulkan at runtime. Point it at the system vulkan-loader
      # which knows how to find ICD manifests via XDG/system paths.
      ln -s ${vulkan-loader}/lib/libvulkan.so.1 $out/bin/weweb/libvulkan.so.1

      # libcef.so is a prebuilt binary with no RPATH for Mesa, Vulkan, or Wayland.
      # Without these paths it cannot dlopen its GL/EGL/Wayland dependencies at runtime.
      # NOTE: do NOT replace the CEF-bundled libEGL.so or libGLESv2.so. Those are
      # ANGLE's own EGL/GLES implementation. Swapping them for the system libglvnd
      # causes EGL_BAD_ATTRIBUTE crashes on NVIDIA: NVIDIA's libEGL_nvidia.so does not
      # implement the ANGLE-specific context-virtualization EGL attributes that Chromium
      # passes when creating shared GPU contexts.
      patchelf --add-rpath "${lib.makeLibraryPath [mesa vulkan-loader wayland libGL]}" $out/bin/weweb/libcef.so
    '';

    meta = with lib; {
      description = "Wallpaper Engine renderer plugin for waywallen (open-wallpaper-engine)";
      homepage = "https://github.com/waywallen/open-wallpaper-engine";
      license = licenses.gpl2Only;
      platforms = platforms.linux;
    };
  }
