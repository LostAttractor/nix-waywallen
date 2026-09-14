{
  lib,
  runCommandCC,
  pkg-config,
  protobuf,
  python3,
  dbus,
  ffmpeg,
  qt6,
  makeFontsConf,
  dejavu_fonts,
  waywallen,
  waywallen-src,
}:
let
  python = python3.withPackages (p: [
    p.pillow
    p.protobuf
    p.websockets
  ]);
in
runCommandCC "waywallen-runtime-check"
  {
    nativeBuildInputs = [
      pkg-config
      protobuf
      python
      dbus
      ffmpeg
    ];
    buildInputs = [ qt6.qtbase ];
    dontWrapQtApps = true;
  }
  ''
    protoc -I ${waywallen-src}/proto --python_out=. \
      ${waywallen-src}/proto/{control,filter}.proto
    $CXX ${./image-formats.cpp} -o image-formats $(pkg-config --cflags --libs Qt6Gui)
    $CXX -shared -fPIC ${./ui-resources.cpp} -o ui-resources.so $(pkg-config --cflags --libs Qt6Gui)
    export PYTHONPATH="$PWD"
    export FONTCONFIG_FILE=${makeFontsConf { fontDirectories = [ dejavu_fonts ]; }}
    dbus-run-session --config-file=${dbus}/share/dbus-1/session.conf -- \
      ${python}/bin/python ${./runtime.py} \
      ${waywallen} "$PWD/image-formats" \
      ${lib.getLib qt6.qtimageformats}/${qt6.qtbase.qtPluginPrefix} "$PWD/ui-resources.so"
    touch "$out"
  ''
