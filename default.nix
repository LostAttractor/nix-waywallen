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
}
