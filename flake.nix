{
  description = "Zed flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    packages = {
      url = "github:viicslen-nix/packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zed-upstream.url = "github:zed-industries/zed";
    zed-extensions.url = "github:DuskSystems/nix-zed-extensions";
    phpantom-lsp-src = {
      url = "github:AJenbo/phpantom_lsp";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem = {system, ...}: let
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
      in {
        formatter = pkgs.alejandra;

        packages = {
          default = inputs.zed-upstream.packages.${system}.default;
          zed-editor = inputs.zed-upstream.packages.${system}.default;
          phpantom-zed-extension = pkgs.phpantom-zed-extension;
        };

        apps = {};
      };

      flake = {
        overlays = {
          zed-extensions = inputs.zed-extensions.overlays.default;

          default =
          inputs.nixpkgs.lib.composeManyExtensions [
            inputs.zed-extensions.overlays.default
            (final: _prev: {
              zed = inputs.zed-upstream.packages.${final.system}.default;

              phpantom-zed-extension = final.buildZedRustExtension {
                name = "phpantom";
                version = "0.7.0";
                src = inputs.phpantom-lsp-src;
                extensionRoot = "zed-extension";
                cargoRoot = "zed-extension";
                cargoLock = {
                  lockFile = ./Cargo.lock.phpantom-zed-extension;
                };
                postPatch = ''
                  cp ${./Cargo.lock.phpantom-zed-extension} zed-extension/Cargo.lock
                '';
              };
            })
          ];
        };

        homeManagerModules = {
          default = {
            imports = [
              ./hmModules/default.nix
              inputs.zed-extensions.homeManagerModules.default
            ];
            nixpkgs.overlays = [self.overlays.default];
          };

          zed = self.homeManagerModules.default;

          zed-extensions = inputs.zed-extensions.homeManagerModules.default;
        };
      };
    };
}
