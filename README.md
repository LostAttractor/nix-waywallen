# Nix Waywallen

This repository contains a Nix Flake that packages [Waywallen](https://github.com/waywallen/waywallen) and its associated components, plugins, and display extensions.

## Packages Available

This flake exports the following packages:

- **`waywallen`**: The unified, source-built package containing the Waywallen daemon, Qt/QML UI, built-in plugins (image, video, Wallhaven), and the open-wallpaper-engine plugin. This is the primary package you should install.
- **`waywallen-open-wallpaper-engine`**: The source-built Wallpaper Engine scene and web renderer plugin, also included in `waywallen`.
- **`waywallen-layer-shell`**: The Wayland layer-shell display backend.
- **`waywallen-kde`**: KDE Plasma plugin for the Waywallen display.
- **`waywallen-gnome`**: GNOME Shell extension for the Waywallen display.

`waywallen-daemon` is also available as a standalone source-built package. The `waywallen-ui` and `waywallen-plugins` attributes are compatibility aliases for the unified package.

## Building

```sh
nix build .#waywallen
nix build .#waywallen-open-wallpaper-engine
```

Both `x86_64-linux` and `aarch64-linux` are supported. Upstream release tags are pinned in `flake.lock`. Lito is bootstrapped from pinned sources with Clang 22, and its dependencies are fetched into fixed-output source bundles using upstream `lito.lock` files. Compilation then runs offline with `--frozen` inside the Nix sandbox. The Rust daemon uses the existing Cargo-based Nix package.

The two Lito-based packages share `pkgs/build-lito-package.nix`: `buildPhase` runs `lito install` once to build and stage the installable artifacts, and `installPhase` only copies the staged tree to `$out`. This avoids compiling twice and handles Lito's install-specific link variants without an extra build.

The open-wallpaper-engine renderers are compiled from source. Their web rendering dependency, **CEF**, uses the architecture-specific binary SDK and checksum pinned by upstream; Chromium itself is not compiled by this flake. Qt, FFmpeg and other system libraries come from Nixpkgs.

When updating an upstream tag, also update the package version and the corresponding Lito dependency bundle hashes (for both architectures), alongside `cargoHash` if the daemon's Cargo dependencies changed.

Run `nix flake check` to build and test the current system. The runtime check starts the packaged daemon in an isolated D-Bus session, verifies plugin translations and Lua sources, scans generated image/video fixtures and checks their dimensions, and checks Qt image decoding, embedded Material icon fonts, Adwaita window decorations and tray resources. Source-built outputs also reject references to the build-only Lito dependency bundles.

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
