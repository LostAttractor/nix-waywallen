{
  pkgs,
  waywallen-src,
  waywallen-display-src,
  open-wallpaper-engine-src,
}:
let
  lito = pkgs.callPackage ./lito.nix { };
  fetchLitoDeps = pkgs.callPackage ./fetch-lito-deps.nix { inherit lito; };
  buildLitoPackage = pkgs.callPackage ./build-lito-package.nix { inherit lito fetchLitoDeps; };
  waywallen-daemon = pkgs.callPackage ./waywallen-daemon.nix { src = waywallen-src; };
  waywallen-unwrapped = pkgs.callPackage ./waywallen.nix {
    inherit buildLitoPackage waywallen-daemon;
    src = waywallen-src;
  };
  waywallen-open-wallpaper-engine = pkgs.callPackage ./open-wallpaper-engine.nix {
    inherit buildLitoPackage waywallen-unwrapped;
    src = open-wallpaper-engine-src;
  };
in
{
  inherit waywallen-daemon waywallen-open-wallpaper-engine;
  waywallen = pkgs.symlinkJoin {
    name = "waywallen-${waywallen-unwrapped.version}";
    inherit (waywallen-unwrapped) version;
    paths = [
      waywallen-unwrapped
      waywallen-open-wallpaper-engine
    ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      # Plugin imports and translations must stay inside their canonical root.
      # Preserve whole plugin directories instead of lndir's file-level symlinks.
      pluginDir="$out/share/waywallen/plugins"
      rm -rf "$pluginDir"
      mkdir -p "$pluginDir"
      for source in ${waywallen-unwrapped} ${waywallen-open-wallpaper-engine}; do
        ln -s "$source"/share/waywallen/plugins/* "$pluginDir/"
      done

      wrapProgram "$out/bin/waywallen" \
        --add-flags "--ui $out/bin/waywallen-ui --plugin $out/share/waywallen"
    '';
    passthru = {
      unwrapped = waywallen-unwrapped;
      inherit lito;
    };
    meta = waywallen-unwrapped.meta // {
      description = "Waywallen wallpaper manager with the open-wallpaper-engine plugin";
      license = with pkgs.lib.licenses; [
        mit
        gpl2Only
      ];
      inherit (waywallen-open-wallpaper-engine.meta) sourceProvenance;
    };
  };
  waywallen-layer-shell = pkgs.callPackage ./waywallen-layer-shell.nix {
    src = waywallen-display-src;
  };
  waywallen-kde = pkgs.callPackage ./waywallen-kde.nix { src = waywallen-display-src; };
  waywallen-gnome = pkgs.callPackage ./waywallen-gnome.nix { src = waywallen-display-src; };
}
