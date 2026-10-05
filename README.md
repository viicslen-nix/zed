<div align="center">

# Zed

**The Zed editor, its extensions, and a Home Manager module, packaged as one flake.**

[![Zed](https://img.shields.io/badge/editor-Zed-084CCF?style=flat-square)](https://zed.dev)
[![flake-parts](https://img.shields.io/badge/built_with-flake--parts-7EBAE4?style=flat-square&logo=nixos&logoColor=white)](https://flake.parts)
[![Home Manager](https://img.shields.io/badge/Home_Manager-module-41439A?style=flat-square)](https://github.com/nix-community/home-manager)

</div>

> [!NOTE]
> This is a subflake of [viicslen-nix/nixos](https://github.com/viicslen-nix/nixos).
> The Home Manager module assumes that repo's conventions (see
> [Requirements](#requirements)), so it is not a drop-in module for other configs.

## Outputs

| Output | Description |
| --- | --- |
| `packages.<system>.default` | Zed built from [`zed-industries/zed`](https://github.com/zed-industries/zed) `main` |
| `packages.<system>.zed-editor` | Same as `default` |
| `packages.<system>.phpantom-zed-extension` | Zed extension for [phpantom_lsp](https://github.com/AJenbo/phpantom_lsp), built with `buildZedRustExtension` |
| `overlays.default` | `nix-zed-extensions` overlay, plus `zed` and `phpantom-zed-extension` |
| `overlays.zed-extensions` | The [`nix-zed-extensions`](https://github.com/DuskSystems/nix-zed-extensions) overlay alone |
| `homeManagerModules.default` | `modules.programs.zed`, plus the `nix-zed-extensions` HM module |
| `homeManagerModules.zed` | Alias of `default` |
| `homeManagerModules.zed-extensions` | The `nix-zed-extensions` HM module alone |
| `formatter.<system>` | treefmt: deadnix, statix, alejandra |
| `checks.<system>.{treefmt,statix}` | Formatting check, and a `statix check` gate |

Systems: `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`.

## Usage

```nix
{
  inputs.zed = {
    url = "github:viicslen-nix/zed";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.packages.follows = "packages";
  };
}
```

Import the module into Home Manager and enable it:

```nix
{
  home-manager.sharedModules = [inputs.zed.homeManagerModules.default];

  home-manager.users.<name>.modules.programs.zed = {
    enable = true;
    phpantom.enable = true; # optional
  };
}
```

## Home Manager module

| Option | Default | Effect |
| --- | --- | --- |
| `modules.programs.zed.enable` | `false` | Enables `programs.zed-editor` with the settings in [`config/settings.json`](config/settings.json) |
| `modules.programs.zed.phpantom.enable` | `false` | Adds the `phpantom-lsp` binary and Zed extension, and makes it the first PHP language server |

When enabled, the module:

- seeds `userSettings` from `config/settings.json` (vim mode, JetBrains keymap,
  inlay hints, telemetry off, ACP agent servers, …), with
  `mutableUserSettings` / `mutableUserKeymaps` on, so in-editor edits survive;
- turns on `enableMcpIntegration` and adds a Rust toolchain (`rustc`, `cargo`,
  `cargo-wasi`, `rustup`) to `extraPackages` for building dev extensions;
- installs a `zed` command that runs `zeditor` from `PATH`, so it goes through
  home-manager's wrapper and sees `extraPackages`;
- adds the `Zed` config directory to `modules.functionality.impermanence`
  when that module's `autoPersistence` is on.

The editor package itself is left at home-manager's default (`pkgs.zed-editor`).

### Requirements

None beyond home-manager. The module reads this flake's own inputs (as
`zedInputs`), so the consumer can name the input anything:

| Source | Used for |
| --- | --- |
| `packages` input | `php.phpantom-lsp` (only with `phpantom.enable`) |
| this flake's `packages` | `phpantom-zed-extension` (only with `phpantom.enable`) |
| `modules.functionality.impermanence` | Persists `~/.config/Zed` when the consumer declares that option and enables auto-persistence; skipped otherwise |

## Development

```bash
nix fmt              # deadnix → statix → alejandra, via treefmt
nix flake check      # formatting + statix check
nix build .#phpantom-zed-extension
```

<details>
<summary>Layout</summary>

```text
.
├── flake.nix                     # inputs, packages, overlays, HM module exports
├── treefmt.nix                   # formatter config
├── hmModules/default.nix         # modules.programs.zed
├── config/settings.json          # base Zed settings
└── extensions/phpantom/Cargo.lock  # lockfile for the phpantom extension build
```

</details>

<details>
<summary>Bumping phpantom</summary>

`phpantom-lsp-src` is a non-flake input. The build uses
`extensions/phpantom/Cargo.lock` both as `cargoLock.lockFile` and as the
`Cargo.lock` installed into the source's `zed-extension/`, and `version` is a
literal in `flake.nix`. After `nix flake update phpantom-lsp-src`, refresh the
lockfile against that revision's `zed-extension/` and bump `version` to match.

</details>
