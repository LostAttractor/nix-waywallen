{
  llvmPackages_22,
  lito,
  git,
  git-lfs,
  curl,
  cacert,
  python3,
}:
{
  pname,
  version,
  src,
  hash,
  patches ? [ ],
  arch ? llvmPackages_22.stdenv.hostPlatform.parsed.cpu.name,
}:
llvmPackages_22.stdenv.mkDerivation {
  name = "${pname}-${version}-lito-deps-${arch}";
  inherit src patches;

  nativeBuildInputs = [
    lito
    git
    git-lfs
    curl
    python3
  ];
  SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  CURL_CA_BUNDLE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

  dontConfigure = true;
  dontFixup = true;
  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR/home"
    export XDG_DATA_HOME="$HOME/.local/share"
    mkdir -p "$HOME"
    # QmlMaterial embeds icon fonts stored in Git LFS, not the pointer files.
    git lfs install --skip-repo
    printf 'retry = 5\nretry-all-errors\n' > "$HOME/.curlrc"
    python3 ${./seed-lito-index.py} lito.lock "$XDG_DATA_HOME/lito"
    lito fetch --locked --output "$out" -j "$NIX_BUILD_CORES" \
      --config 'toolchain.os="linux"' \
      --config 'toolchain.arch="${arch}"'
    runHook postBuild
  '';

  # Lito verifies Git bundle entries against HEAD. Retain the genuine commit and
  # tree objects, but discard clone paths, reflogs, timestamps and unrelated refs.
  installPhase = ''
    runHook preInstall
    while IFS= read -r -d "" dotgit; do
      repo="$(dirname "$dotgit")"
      rev="$(git -C "$repo" rev-parse HEAD)"
      echo "$rev" > "$dotgit/shallow"
      git -C "$repo" rev-list --objects --no-object-names HEAD | sort \
        | git -C "$repo" pack-objects --stdout > "$TMPDIR/objects.pack"
      rm -rf "$dotgit"
      git -C "$repo" init -q --template= --initial-branch=source
      git -C "$repo" unpack-objects < "$TMPDIR/objects.pack"
      echo "$rev" > "$dotgit/HEAD"
      echo "$rev" > "$dotgit/shallow"
      rm -f "$dotgit/config" "$dotgit/description"
    done < <(find "$out" -type d -name .git -prune -print0)
    runHook postInstall
  '';

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = hash;
}
