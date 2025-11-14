{ inputs, pkgs, ... }:
{
  # carburetor.themes.vicinae.enable = true;
  services.vicinae = {
    enable = true;
    autoStart = true;
    settings = {
      faviconService = "google"; # twenty | google | none
      font.size = 11;
      popToRootOnClose = true;
      rootSearch.searchFiles = false;
      theme.name = "carburetor";
      window = {
        csd = true;
        opacity = 0.7;
        rounding = 10;
      };
    };
    extensions = [ ];
  };
}
