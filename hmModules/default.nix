{
  lib,
  pkgs,
  config,
  options,
  zedInputs,
  ...
}:
with lib; let
  name = "zed";
  namespace = "programs";

  cfg = config.modules.${namespace}.${name};
  inherit (pkgs.stdenv.hostPlatform) system;
  impermanencePath = ["modules" "functionality" "impermanence"];
in {
  options.modules.${namespace}.${name} = {
    enable = mkEnableOption (mdDoc name);

    phpantom.enable = mkEnableOption (mdDoc "the phpantom PHP language server and its Zed extension");
  };

  config = mkIf cfg.enable (mkMerge [
    {
      programs.zed-editor = {
        enable = true;
        # package = zedInputs.self.packages.${system}.zed-editor;
        enableMcpIntegration = true;
        mutableUserKeymaps = true;
        mutableUserSettings = true;
        userSettings = mkForce (
          let
            baseSettings = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile ../config/settings.json));
          in
            recursiveUpdate baseSettings (optionalAttrs cfg.phpantom.enable {
              languages.PHP.language_servers = [
                "phpantom_lsp"
                "!intelephense"
                "!phpactor"
                "!phptools"
                "..."
              ];
            })
        );
        extraPackages = with pkgs;
          [
            rustc
            cargo
            cargo-wasi
            rustup
          ]
          ++ optional cfg.phpantom.enable zedInputs.packages.packages.${system}.php.phpantom-lsp;
      };

      programs.zed-editor-extensions = {
        enable = true;
        packages = optional cfg.phpantom.enable zedInputs.self.packages.${system}.phpantom-zed-extension;
      };

      # Resolve via PATH, not the package: home-manager's wrapper that adds extraPackages isn't exposed.
      home.packages = [(pkgs.writeShellScriptBin "zed" ''exec zeditor "$@"'')];
    }
    # The consumer may not declare impermanence; mkIf false would still reference the option.
    (optionalAttrs (hasAttrByPath impermanencePath options) {
      modules.functionality.impermanence.config = let
        imp = getAttrFromPath impermanencePath config;
      in
        mkIf (imp.enable && imp.autoPersistence) ["Zed"];
    })
  ]);
}
