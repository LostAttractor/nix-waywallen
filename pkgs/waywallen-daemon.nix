{
  lib,
  rustPlatform,
  pkg-config,
  protobuf,
  sqlite,
  ffmpeg,
  vulkan-loader,
  libpulseaudio,
  makeWrapper,
  src,
}:

rustPlatform.buildRustPackage {
  pname = "waywallen-daemon";
  version = "0.3.9";

  inherit src;

  cargoHash = "sha256-Gb86FY3xUO77MFIc2WIi5RzddHd3mRgx4HCGdWRVpow=";

  nativeBuildInputs = [
    pkg-config
    protobuf
    makeWrapper
  ];

  buildInputs = [
    sqlite
    libpulseaudio
  ];

  doCheck = false;

  postInstall = ''
    # The tray publishes an icon directory relative to the actual daemon executable.
    install -Dm644 ui/assets/waywallen-ui.svg \
      "$out/share/icons/hicolor/scalable/apps/org.waywallen.waywallen.svg"

    wrapProgram $out/bin/waywallen \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          ffmpeg
          libpulseaudio
        ]
      }
    wrapProgram $out/bin/waywallen_renderer \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ vulkan-loader ]}
  '';

  meta = with lib; {
    description = "Rust daemon component of waywallen";
    homepage = "https://github.com/waywallen/waywallen";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "waywallen";
  };
}
