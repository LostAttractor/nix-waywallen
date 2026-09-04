{
  pkgs,
  waywallen-src,
  waywallen-display-src,
}:
{
  waywallen = pkgs.callPackage ./waywallen-bin.nix { };
  waywallen-daemon = pkgs.callPackage ./waywallen-daemon.nix { src = waywallen-src; };
  waywallen-layer-shell = pkgs.callPackage ./waywallen-layer-shell.nix {
    src = waywallen-display-src;
  };
  waywallen-kde = pkgs.callPackage ./waywallen-kde.nix { src = waywallen-display-src; };
  waywallen-gnome = pkgs.callPackage ./waywallen-gnome.nix { src = waywallen-display-src; };
}
