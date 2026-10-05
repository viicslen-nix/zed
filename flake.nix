{
  description = "Zed flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
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
      imports = [inputs.treefmt-nix.flakeModule];

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
        treefmt.imports = [./treefmt.nix];

        # treefmt runs `statix fix`, which skips unfixable lints such as W20.
        checks.statix = pkgs.runCommandLocal "statix-check" {} ''
          ${pkgs.lib.getExe pkgs.statix} check ${./.} && touch $out
        '';

        packages = {
          default = inputs.zed-upstream.packages.${system}.default;
          zed-editor = inputs.zed-upstream.packages.${system}.default;
          inherit (pkgs) phpantom-zed-extension;
        };

        apps = {};
      };

      flake = {
        overlays = {
          zed-extensions = inputs.zed-extensions.overlays.default;

          default = inputs.nixpkgs.lib.composeManyExtensions [
            inputs.zed-extensions.overlays.default
            (final: _prev: {
              zed = inputs.zed-upstream.packages.${final.stdenv.hostPlatform.system}.default;

              phpantom-zed-extension = final.buildZedRustExtension {
                name = "phpantom";
                version = "0.7.0";
                src = inputs.phpantom-lsp-src;
                extensionRoot = "zed-extension";
                cargoRoot = "zed-extension";
                cargoLock = {
                  lockFile = ./extensions/phpantom/Cargo.lock;
                };
                postPatch = ''
                  install -m 0644 ${./extensions/phpantom/Cargo.lock} zed-extension/Cargo.lock
                '';
              };
            })
          ];
        };

        homeManagerModules = {
          default = {
            key = "viicslen-zed:default";
            imports = [
              ./hmModules/default.nix
              inputs.zed-extensions.homeManagerModules.default
            ];
            # `zedInputs`, not `inputs`: home-manager's extraSpecialArgs would hand the module the consumer's set.
            _module.args.zedInputs = inputs;
          };

          zed = self.homeManagerModules.default;

          zed-extensions = inputs.zed-extensions.homeManagerModules.default;
        };
      };
    };
}
