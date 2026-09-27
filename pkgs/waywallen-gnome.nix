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
  version = "0.4.0";

  inherit src;

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
