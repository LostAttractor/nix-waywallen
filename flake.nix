{
  description = "waywallen - Rust daemon + Qt/QML UI + renderer plugins";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Upstream sources — pinned to latest release tags.
    # Bump the tag refs when packaging a new upstream release.
    waywallen-src = {
      url = "github:waywallen/waywallen/v0.3.8";
      flake = false;
    };
    waywallen-display-src = {
      url = "github:waywallen/waywallen-display/v0.3.3";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    waywallen-src,
    waywallen-display-src,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    nixpkgsFor = forAllSystems (system: import nixpkgs {inherit system;});
  in {
    packages = forAllSystems (
      system: let
        pkgs = nixpkgsFor.${system};
        waywallen = pkgs.callPackage ./pkgs/waywallen-bin.nix {};
        waywallen-daemon = pkgs.callPackage ./pkgs/waywallen-daemon.nix {src = waywallen-src;};
        waywallen-layer-shell = pkgs.callPackage ./pkgs/waywallen-layer-shell.nix {src = waywallen-display-src;};
        waywallen-kde = pkgs.callPackage ./pkgs/waywallen-kde.nix {src = waywallen-display-src;};
        waywallen-gnome = pkgs.callPackage ./pkgs/waywallen-gnome.nix {src = waywallen-display-src;};
      in rec {
        inherit waywallen waywallen-daemon waywallen-layer-shell waywallen-kde waywallen-gnome;

        # Compatibility aliases: the official release now ships these together.
        waywallen-ui = waywallen;
        waywallen-plugins = waywallen;
        waywallen-open-wallpaper-engine = waywallen;

        default = waywallen;
      }
    );

    overlays.default = final: prev: {
      waywallen = final.callPackage ./pkgs/waywallen-bin.nix {};
      waywallen-daemon = final.callPackage ./pkgs/waywallen-daemon.nix {src = waywallen-src;};
      waywallen-layer-shell = final.callPackage ./pkgs/waywallen-layer-shell.nix {src = waywallen-display-src;};
      waywallen-kde = final.callPackage ./pkgs/waywallen-kde.nix {src = waywallen-display-src;};
      waywallen-gnome = final.callPackage ./pkgs/waywallen-gnome.nix {src = waywallen-display-src;};
      waywallen-ui = final.waywallen;
      waywallen-plugins = final.waywallen;
      waywallen-open-wallpaper-engine = final.waywallen;
    };
  };
}
