{
  lib,
  rustPlatform,
  pkg-config,
  protobuf,
  sqlite,
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
    wrapProgram $out/bin/waywallen \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libpulseaudio ]}
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
