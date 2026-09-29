{
  lib,
  bash,
  llvmPackages_22,
  enableLibcxx ? false,
}:
(llvmPackages_22.clang-tools.override { inherit enableLibcxx; }).overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    # The wrappers use Bash syntax, but some Nixpkgs revisions leave /bin/sh
    # unpatched. In a BusyBox-based sandbox this loses the C++ header paths.
    # Other revisions already patch the shebang, so the replacement is optional.
    for tool in "$out"/bin/*-unwrapped; do
      substituteInPlace "''${tool%-unwrapped}" \
        --replace-quiet '#!/bin/sh' '#!${lib.getExe bash}'
    done
  '';
})
