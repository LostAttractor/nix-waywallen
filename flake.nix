{
  description = "waywallen - Rust daemon + Qt/QML UI + renderer plugins";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Upstream sources — pinned to latest release tags.
    # Bump the tag refs when packaging a new upstream release.
    waywallen-src = {
      url = "github:waywallen/waywallen/v0.3.3";
      flake = false;
    };
    waywallen-display-src = {
      url = "github:waywallen/waywallen-display/v0.3.1";
      flake = false;
    };
    open-wallpaper-engine-src = {
      url = "github:waywallen/open-wallpaper-engine/v0.2.3";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    waywallen-src,
    waywallen-display-src,
    open-wallpaper-engine-src,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    nixpkgsFor = forAllSystems (system: import nixpkgs {inherit system;});

    # Sub-deps are resolved from each upstream's deps.json (see
    # pkgs/fetch-upstream-deps.nix). Only LFS outputs need a nix hash here.
    waywallenLfsHashes = {
      qml_material = "sha256-x3c/nOZfWB8yIYBrZSgmsHJ+mcOQtsjtL3WMC+ib29Y=";
    };

    fetchDepsFor = pkgs: src:
      pkgs.callPackage ./pkgs/fetch-upstream-deps.nix {
        depsJson = builtins.fromJSON (builtins.readFile "${src}/deps.json");
        lfsHashes = waywallenLfsHashes;
      };
  in {
    packages = forAllSystems (
      system: let
        pkgs = nixpkgsFor.${system};
        llvmPackages_latest = pkgs.llvmPackages_latest;
        fetchDep = fetchDepsFor pkgs waywallen-src;
        waywallen-daemon = pkgs.callPackage ./pkgs/waywallen-daemon.nix {src = waywallen-src;};
        waywallen-ui = pkgs.callPackage ./pkgs/waywallen-ui.nix {
          inherit llvmPackages_latest;
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
          inherit llvmPackages_latest;
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
          inherit llvmPackages_latest waywallen-plugins;
          src = open-wallpaper-engine-src;
        };

        # Combined package: daemon + renderer plugins + ui + owe
        # in a single store path, suitable for `nix profile install`.
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
          meta =
            waywallen-daemon.meta
            // {
              description = "waywallen - daemon, renderer plugins, open-wallpaper-engine and UI";
            };
        };

        default = self.packages.${system}.waywallen;
      }
    );

    overlays.default = final: prev: let
      fetchDep = fetchDepsFor final waywallen-src;
    in {
      waywallen-daemon = final.callPackage ./pkgs/waywallen-daemon.nix {src = waywallen-src;};
      waywallen-ui = final.callPackage ./pkgs/waywallen-ui.nix {
        llvmPackages_latest = final.llvmPackages_latest;
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
      waywallen-plugins = final.callPackage ./pkgs/waywallen-plugins.nix {
        llvmPackages_latest = final.llvmPackages_latest;
        src = waywallen-src;
        rstd-src = fetchDep "rstd";
        vma-src = fetchDep "vma";
        vvk-src = fetchDep "vvk";
        wavsen-src = fetchDep "wavsen";
      };
      waywallen-layer-shell = final.callPackage ./pkgs/waywallen-layer-shell.nix {src = waywallen-display-src;};
      waywallen-kde = final.callPackage ./pkgs/waywallen-kde.nix {src = waywallen-display-src;};
      waywallen-gnome = final.callPackage ./pkgs/waywallen-gnome.nix {src = waywallen-display-src;};
      waywallen-open-wallpaper-engine = final.callPackage ./pkgs/waywallen-open-wallpaper-engine.nix {
        llvmPackages_latest = final.llvmPackages_latest;
        waywallen-plugins = final.waywallen-plugins;
        src = open-wallpaper-engine-src;
      };
      waywallen = final.symlinkJoin {
        name = "waywallen-${final.waywallen-daemon.version}";
        paths = [final.waywallen-daemon final.waywallen-plugins final.waywallen-open-wallpaper-engine final.waywallen-ui];
        nativeBuildInputs = [final.makeWrapper];
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
        meta =
          final.waywallen-daemon.meta
          // {
            description = "waywallen - daemon, renderer plugins, open-wallpaper-engine and UI";
          };
      };
    };
  };
}
