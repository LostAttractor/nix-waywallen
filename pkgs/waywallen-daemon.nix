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
  version = "0.3.8";

  inherit src;

  cargoHash = "sha256-gONE3RcXa/5fa7TIdhGNuKWoiR3ZfaOVNdEFx5tsiI8=";

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
