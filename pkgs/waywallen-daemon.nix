{
  lib,
  rustPlatform,
  pkg-config,
  protobuf,
  sqlite,
  openssl,
  ffmpeg,
  vulkan-loader,
  libpulseaudio,
  makeWrapper,
  src,
}:

rustPlatform.buildRustPackage {
  pname = "waywallen-daemon";
  version = "0.6.0";

  inherit src;

  cargoHash = "sha256-F16RfCJAt8g2N8DsiP1ei93OgQ6Xn0LAjQ8iNFLHZP4=";

  nativeBuildInputs = [
    pkg-config
    protobuf
    makeWrapper
  ];

  buildInputs = [
    sqlite
    openssl
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
