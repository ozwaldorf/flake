{ ... }:
{
  carburetor.themes.vicinae.enable = true;
  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    settings = {
      favicon_service = "google";
      pop_to_root_on_close = true;
      search_files_in_root = false;
      font.normal.size = 11;
      launcher_window = {
        csd = false;
        opacity = 0.2;
        rounding = 16;
      };
    };
  };
}
