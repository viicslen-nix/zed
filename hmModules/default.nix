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
  };

  config = mkIf cfg.enable (mkMerge [
    {
      programs.zed-editor = {
        enable = true;
        # package = inputs.zed.packages.${pkgs.system}.zed;
        enableMcpIntegration = true;
        mutableUserKeymaps = true;
        mutableUserSettings = true;
        userSettings = mkForce (
          let
            baseSettings = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile ../settings.json));
          in
            recursiveUpdate baseSettings {
              languages.PHP.language_servers = [
                "phpantom_lsp"
                "!intelephense"
                "!phpactor"
                "!phptools"
                "..."
              ];
            }
        );
        extraPackages = with pkgs; [
          inputs.packages.packages.${pkgs.system}.php.phpantom-lsp
          rustc
          cargo
          cargo-wasi
          rustup
        ];
      };

      programs.zed-editor-extensions = {
        enable = true;
        packages = [
          inputs.zed.packages.${pkgs.system}.phpantom-zed-extension
        ];
      };
    }
    (persistence.mkPersistence config {
      config = ["Zed"];
    })
  ]);
}
