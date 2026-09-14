{
  pkgs ? import <nixpkgs> { },
}:
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);

  # Fetch git input from lockfile
  fetchInput =
    nodeName:
    let
      node = lock.nodes.${nodeName}.locked;
    in
    if node.type or "" == "github" then
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

  packages = import ./pkgs {
    inherit
      pkgs
      waywallen-src
      waywallen-display-src
      open-wallpaper-engine-src
      ;
  };
in
packages
// {
  # Compatibility aliases for the unified package.
  waywallen-ui = packages.waywallen;
  waywallen-plugins = packages.waywallen;
}
