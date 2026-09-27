{
  lib,
  callPackage,
  llvmPackages_22,
  fetchFromGitHub,
  fetchzip,
  cmake,
  ninja,
  pkg-config,
  zstd,
}:
let
  clang-tools = callPackage ./clang-tools.nix { enableLibcxx = true; };
  rstd = fetchFromGitHub {
    owner = "litocpp";
    repo = "rstd";
    rev = "4a4bf6910cd06043b80b179eff35f229a82580b8";
    hash = "sha256-hwET+YV0qxGPK9ONnk+f6T197SG11igGAdBN37+j1LE=";
  };
  luato = fetchFromGitHub {
    owner = "litocpp";
    repo = "luato";
    rev = "df0c6f2d1cce2051b4711d36067619eda7933683";
    hash = "sha256-XL1evcZbZJ2LfTi5T9UQ+4YBEw5YnDsGeY3IBS+Fs5U=";
  };
  licrypto = fetchFromGitHub {
    owner = "litocpp";
    repo = "licrypto";
    rev = "18345239cc68869646a6522e6e258a4eba3dec20";
    hash = "sha256-UVk3BeTA8+cBvB9XFXKNo1ua4rBflpKif7NF+9a9l/Q=";
  };
  lua = fetchzip {
    url = "https://www.lua.org/ftp/lua-5.5.1.tar.gz";
    hash = "sha256-vb3Nt5dMPL/G6L1MmJPGQnQT3F8p6iK6Gu2F/cG00ho=";
  };
in
llvmPackages_22.libcxxStdenv.mkDerivation {
  pname = "lito";
  version = "0.8.4";

  src = fetchFromGitHub {
    owner = "litocpp";
    repo = "lito";
    rev = "58f7b09a11ba6b6b549083f633e18c8990804339";
    hash = "sha256-SKjS3ViWk3ZWAunrYByF/QYgHru9b/iF5j1obriG1TQ=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    llvmPackages_22.lld
    llvmPackages_22.llvm
    clang-tools
  ];
  buildInputs = [ zstd ];

  # glibc's fortified overloads are not linkable across these C++ module boundaries.
  hardeningDisable = [ "fortify" ];

  cmakeFlags = [
    "-DLITO_USE_SYSTEM_ZSTD=ON"
    "-DCMAKE_BUILD_RPATH=${lib.makeLibraryPath [ zstd ]}"
    "-DCMAKE_INSTALL_RPATH=${lib.makeLibraryPath [ zstd ]}"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DFETCHCONTENT_SOURCE_DIR_RSTD=${rstd}"
    "-DFETCHCONTENT_SOURCE_DIR_LUATO=${luato}"
    "-DFETCHCONTENT_SOURCE_DIR_LICRYPTO=${licrypto}"
    "-DFETCHCONTENT_SOURCE_DIR_LUA=${lua}"
  ];

  meta = {
    description = "Module-first C++ build tool";
    homepage = "https://github.com/litocpp/lito";
    license = with lib.licenses; [
      mit
      asl20
    ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "lito";
  };
}
