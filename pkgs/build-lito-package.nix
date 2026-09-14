{
  callPackage,
  llvmPackages_22,
  lito,
  fetchLitoDeps,
  cmake,
  ninja,
  pkg-config,
  glslang,
  git,
  autoPatchelfHook,
  autoAddDriverRunpath,
}:
{
  litoHash,
  nativeBuildInputs ? [ ],
  env ? { },
  litoFlags ? "",
  ...
}@args:
llvmPackages_22.stdenv.mkDerivation (
  finalAttrs:
  let
    litoDeps = fetchLitoDeps {
      inherit (finalAttrs) pname version src;
      patches = finalAttrs.patches or [ ];
      hash = litoHash;
    };
  in
  builtins.removeAttrs args [ "litoHash" ]
  // {
    nativeBuildInputs = [
      lito
      cmake
      ninja
      pkg-config
      glslang
      git
      llvmPackages_22.llvm
      llvmPackages_22.lld
      (callPackage ./clang-tools.nix { })
      autoPatchelfHook
      autoAddDriverRunpath
    ]
    ++ nativeBuildInputs;

    # glibc's fortified overloads do not work across these C++ module boundaries.
    hardeningDisable = [ "fortify" ];
    # Diagnostic paths must not retain the build-only source bundle at runtime.
    env = env // {
      NIX_CFLAGS_COMPILE = "${env.NIX_CFLAGS_COMPILE or ""} -ffile-prefix-map=${litoDeps}=lito-deps";
    };
    disallowedReferences = [ litoDeps ];

    configurePhase = ''
      runHook preConfigure
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      for repo in ${litoDeps}/v1/git/*; do
        git config --global --add safe.directory "$repo"
      done
      runHook postConfigure
    '';
    buildPhase = ''
      runHook preBuild
      lito install --frozen --source-bundle ${litoDeps} --profile release \
        -j "$NIX_BUILD_CORES" --prefix "$TMPDIR/lito-install" ${litoFlags}
      runHook postBuild
    '';
    # Lito builds install-specific artifacts; stage them once in buildPhase.
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -a "$TMPDIR/lito-install/." "$out/"
      runHook postInstall
    '';

    passthru = { inherit litoDeps; };
  }
)
