{
  description = "waywallen - Rust daemon + Qt/QML UI + renderer plugins";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Upstream sources — pinned to latest release tags.
    # Bump the tag refs when packaging a new upstream release.
    waywallen-src = {
      url = "github:waywallen/waywallen/v0.3.9";
      flake = false;
    };
    waywallen-display-src = {
      url = "github:waywallen/waywallen-display/v0.3.3";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      waywallen-src,
      waywallen-display-src,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      mkPackages =
        pkgs:
        import ./pkgs {
          inherit pkgs waywallen-src waywallen-display-src;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          packages = mkPackages (import nixpkgs { inherit system; });
        in
        packages
        // {
          # Compatibility aliases: the official release now ships these together.
          waywallen-ui = packages.waywallen;
          waywallen-plugins = packages.waywallen;
          waywallen-open-wallpaper-engine = packages.waywallen;

          default = packages.waywallen;
        }
      );

      overlays.default =
        final: _:
        mkPackages final
        // {
          waywallen-ui = final.waywallen;
          waywallen-plugins = final.waywallen;
          waywallen-open-wallpaper-engine = final.waywallen;
        };
    };
}
