{ pkgs, config, ... }:
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
      providers = {
        "@sovereign/store.vicinae.awww-switcher" = {
          preferences.wallpaperPath = "~/Pictures/walls/carburetor";
        };
      };
    };
    extensions =
      let
        ext =
          pkgs.fetchFromGitHub {
            owner = "vicinaehq";
            repo = "extensions";
            rev = "760d63ba7c4dd1892e6ec40c134d3eedcd52aec7";
            sha256 = "sha256-qI5LWkYvtpTMpPiUeg4kgbe1sdh3CVcdhX0qbqD2VNA=";
          }
          + "/extensions";
      in
      [
        (config.lib.vicinae.mkExtension {
          name = "awww-switcher";
          src = ext + "/awww-switcher";
        })
      ];
  };
}
