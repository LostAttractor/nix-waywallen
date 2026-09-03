# Nix Waywallen

This repository contains a Nix Flake that packages [Waywallen](https://github.com/waywallen/waywallen) and its associated components, plugins, and display extensions.

## Packages Available

This flake exports the following packages:

- **`waywallen`**: The unified package containing the Waywallen daemon, UI, renderer plugins (image, video), and the open wallpaper engine plugin. This is the primary package you should install. It is packaged from the official architecture-specific release artifacts.
- **`waywallen-layer-shell`**: The Wayland layer-shell display backend.
- **`waywallen-kde`**: KDE Plasma plugin for the Waywallen display.
- **`waywallen-gnome`**: GNOME Shell extension for the Waywallen display.

`waywallen-daemon` remains available as a standalone source-built package. The `waywallen-ui`, `waywallen-plugins`, and `waywallen-open-wallpaper-engine` attributes are compatibility aliases for the unified official release because upstream now builds and ships these components together with Lito.

## Installation

You can add this repository to your flake inputs and use the provided overlay in your NixOS or Home Manager configuration:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  nix-waywallen.url = "github:gettbitgirl/nix-waywallen";
};

outputs = { self, nixpkgs, nix-waywallen, ... }: {
  nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ({ pkgs, ... }: {
        nixpkgs.overlays = [ nix-waywallen.overlays.default ];
        
        environment.systemPackages = with pkgs; [
          waywallen
          waywallen-kde #install the appropriate display backend for your desktop environment. waywallen-kde for kde, waywallen-gnome for gnome, waywallen-layer-shell for niri, hyperland, or sway.
        ];
      })
      ./configuration.nix
    ];
  };
};
```
