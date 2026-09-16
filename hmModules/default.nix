{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
with lib;
with inputs.self.lib; let
  name = "zed";
  namespace = "programs";

  cfg = config.modules.${namespace}.${name};
in {
  options.modules.${namespace}.${name} = {
    enable = mkEnableOption (mdDoc name);

    phpantom.enable = mkEnableOption (mdDoc "the phpantom PHP language server and its Zed extension");
  };

  config = mkIf cfg.enable (mkMerge [
    {
      programs.zed-editor = {
        enable = true;
        # package = inputs.zed.packages.${pkgs.stdenv.hostPlatform.system}.zed;
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
          ++ optional cfg.phpantom.enable inputs.packages.packages.${pkgs.stdenv.hostPlatform.system}.php.phpantom-lsp;
      };

      programs.zed-editor-extensions = {
        enable = true;
        packages = optional cfg.phpantom.enable inputs.zed.packages.${pkgs.stdenv.hostPlatform.system}.phpantom-zed-extension;
      };

      # Resolve via PATH, not the package: home-manager's wrapper that adds extraPackages isn't exposed.
      home.packages = [(pkgs.writeShellScriptBin "zed" ''exec zeditor "$@"'')];
    }
    (persistence.mkPersistence config {
      config = ["Zed"];
    })
  ]);
}
