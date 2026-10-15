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
    rev = "0c755371a02ccee658fa6d63728b6078cb2f9070";
    hash = "sha256-JqwAOvqQYzh1v9FlA4Spuab7I6gOu/f3uiVFXiwZS0E=";
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
    rev = "40da005cbd7faf1328fd29a01cb0c534d6998612";
    hash = "sha256-Aussj13CS3lAIR0TmmU7NgVQg2l2QUdiNS47oa7Fcaw=";
  };
  lua = fetchzip {
    url = "https://www.lua.org/ftp/lua-5.5.1.tar.gz";
    hash = "sha256-vb3Nt5dMPL/G6L1MmJPGQnQT3F8p6iK6Gu2F/cG00ho=";
  };
in
llvmPackages_22.libcxxStdenv.mkDerivation {
  pname = "lito";
  version = "0.8.6";

  src = fetchFromGitHub {
    owner = "litocpp";
    repo = "lito";
    rev = "f9d295560796ee2503dec6948a1b08edf82cda0d";
    hash = "sha256-5KOC3DQe5N3/KrHNObzF4q3kG/4yxu674NCbEDzD28A=";
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
