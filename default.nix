{pkgs ? import <nixpkgs> {}}: let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);

  # Fetch git input from lockfile
  fetchInput = nodeName: let
    node = lock.nodes.${nodeName}.locked;
  in
    if node.type or "" == "github"
    then
      pkgs.fetchFromGitHub {
        owner = node.owner;
        repo = node.repo;
        rev = node.rev;
        hash = node.narHash;
      }
    else
      pkgs.fetchgit {
        url = node.url;
        rev = node.rev;
        hash = node.narHash;
      };

  waywallen-src = fetchInput "waywallen-src";
  waywallen-display-src = fetchInput "waywallen-display-src";
  open-wallpaper-engine-src = fetchInput "open-wallpaper-engine-src";

  llvmPackages_latest = pkgs.llvmPackages_latest;

  fetchDep = pkgs.callPackage ./pkgs/fetch-upstream-deps.nix {
    depsJson = builtins.fromJSON (builtins.readFile "${waywallen-src}/deps.json");
    lfsHashes.qml_material = "sha256-x3c/nOZfWB8yIYBrZSgmsHJ+mcOQtsjtL3WMC+ib29Y=";
  };

  waywallen-daemon = pkgs.callPackage ./pkgs/waywallen-daemon.nix {src = waywallen-src;};
  waywallen-ui = pkgs.callPackage ./pkgs/waywallen-ui.nix {
    llvmPackages_latest = llvmPackages_latest;
    src = waywallen-src;
    rstd-src = fetchDep "rstd";
    ncrequest-src = fetchDep "ncrequest";
    wavsen-src = fetchDep "wavsen";
    qml_material-src = fetchDep "qml_material";
    QExtra-src = fetchDep "QExtra";
    Corrosion-src = fetchDep "Corrosion";
    vma-src = fetchDep "vma";
    vvk-src = fetchDep "vvk";
  };
  waywallen-plugins = pkgs.callPackage ./pkgs/waywallen-plugins.nix {
    llvmPackages_latest = llvmPackages_latest;
    src = waywallen-src;
    rstd-src = fetchDep "rstd";
    vma-src = fetchDep "vma";
    vvk-src = fetchDep "vvk";
    wavsen-src = fetchDep "wavsen";
  };
  waywallen-layer-shell = pkgs.callPackage ./pkgs/waywallen-layer-shell.nix {src = waywallen-display-src;};
  waywallen-kde = pkgs.callPackage ./pkgs/waywallen-kde.nix {src = waywallen-display-src;};
  waywallen-gnome = pkgs.callPackage ./pkgs/waywallen-gnome.nix {src = waywallen-display-src;};
in rec {
  inherit waywallen-daemon waywallen-ui waywallen-plugins waywallen-layer-shell waywallen-kde waywallen-gnome;

  waywallen-open-wallpaper-engine = pkgs.callPackage ./pkgs/waywallen-open-wallpaper-engine.nix {
    inherit waywallen-plugins;
    llvmPackages_latest = llvmPackages_latest;
    src = open-wallpaper-engine-src;
  };

  # Combined package: daemon + plugins + open wallpaper engine + ui
  waywallen = pkgs.symlinkJoin {
    name = "waywallen-${waywallen-daemon.version}";
    paths = [waywallen-daemon waywallen-plugins waywallen-open-wallpaper-engine waywallen-ui];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      # Lua import() canonicalizes modules and requires they stay under the
      # plugin root. symlinkJoin leaves .lua files as symlinks into other
      # store paths, which fails that check — materialize the plugin tree.
      if [ -d "$out/share/waywallen/plugins" ]; then
        plugins_tmp=$(mktemp -d)
        cp -aL "$out/share/waywallen/plugins/." "$plugins_tmp/"
        chmod -R u+w "$plugins_tmp"
        rm -rf "$out/share/waywallen/plugins"
        mkdir -p "$out/share/waywallen/plugins"
        cp -a "$plugins_tmp/." "$out/share/waywallen/plugins/"
        rm -rf "$plugins_tmp"
      fi
      wrapProgram $out/bin/waywallen \
        --add-flags "--ui $out/bin/waywallen-ui --plugin $out/share/waywallen"
    '';
  };
}
