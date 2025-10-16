{
  pkgs,
  config,
  flakeDirectory,
  ...
}:
{
  programs.zed-editor = {
    enable = true;
    extensions = [
      "nix"
      "toml"
      "make"
    ];

    ## everything inside of these brackets are Zed options.
    userSettings = {
      node = {
        path = pkgs.lib.getExe pkgs.nodejs;
        npm_path = pkgs.lib.getExe' pkgs.nodejs "npm";
      };
      hour_format = "hour24";
      auto_update = false;
      lsp = {
        rust-analyzer = {
          binary = {
            path_lookup = true;
          };
        };
        nix = {
          binary = {
            path_lookup = true;
          };
        };

      };
      vim_mode = true;
      load_direnv = "shell_hook"; # flakes
      theme = {
        mode = "dark";
        dark = "carburetor regular (rosewater) - No Italics";

      };
      ui_font_family = "Berkeley Mono";
      ui_font_size = 16;
      buffer_font_family = "Berkeley Mono";
      buffer_font_size = 16;
      inlay_hints = {
        enabled = true;
        show_type_hints = true;
        show_parameter_hints = true;
        show_other_hints = true;
        edit_debounce_ms = 700;
        scroll_debounce_ms = 50;
      };
      git = {
        git_gutter = "tracked_files";
        inline_blame = {
          enabled = true;
        };
      };
    };
  };

  carburetor.themes.zed.enable = true;
}
