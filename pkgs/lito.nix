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
    rev = "7b45034d8e833398da6bff834b652a1dc40a6a4f";
    hash = "sha256-KIAITRp98if9So19sGqP39bGgep9NafETMZUBAc9qNk=";
  };
  luato = fetchFromGitHub {
    owner = "litocpp";
    repo = "luato";
    rev = "9ad07ca2604022319c0178b7f5543220baf87050";
    hash = "sha256-C1DlycFz5z+e+A5FsL18ePc4KQYscn2z4cJKPBgkj8w=";
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
  version = "0.8.1";

  src = fetchFromGitHub {
    owner = "litocpp";
    repo = "lito";
    rev = "3d2c7a4d9ac6de49e1536897479d4c474e813c0c";
    hash = "sha256-OA/CQNxUpVo1AObedG+F4LHTRRiK/1xv9F7daRmGMg4=";
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
