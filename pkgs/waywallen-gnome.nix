{
  lib,
  stdenv,
  cmake,
  pkg-config,
  glib,
  gobject-introspection,
  gtk4,
  libGL,
  vulkan-loader,
  gjs,
  src,
}:
stdenv.mkDerivation {
  pname = "waywallen-display-gnome";
  version = "0.3.3";

  inherit src;

  patches = [
    # GJS (the GNOME JavaScript engine) represents uint64 values as JavaScript
    # Numbers, which only have 53 bits of mantissa. DRM buffer modifiers are 64-bit
    # values and commonly use the upper bits (e.g. AFBC, DCC modifier flags), so
    # passing them through GJS causes silent precision loss. This patch replaces the
    # JS call path with a new C function ww_shadow_paintable_set_shadow_from_display()
    # that reads the modifier directly in C and never exposes it to JS.
    ./patches/gnome-gjs-bigint.patch
  ];

  nativeBuildInputs = [
    cmake
    pkg-config
    gobject-introspection
    glib
  ];

  buildInputs = [
    glib
    gtk4
    libGL
    vulkan-loader
    gjs
  ];

  cmakeFlags = [
    "-DWAYWALLEN_DISPLAY_PLUGIN_GOBJECT=ON"
    "-DWAYWALLEN_DISPLAY_PLUGIN_GNOME=ON"
  ];

  postInstall = ''
    cmake --install . \
      --component gnome_extension \
      --prefix "$out/share/gnome-shell/extensions/org.waywallen.gnome@waywallen.io"
  '';

  passthru = {
    extensionUuid = "org.waywallen.gnome@waywallen.io";
    extensionPortalSlug = "waywallen";
  };

  meta = with lib; {
    description = "waywallen-display GNOME shell extension";
    homepage = "https://github.com/waywallen/waywallen-display";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
