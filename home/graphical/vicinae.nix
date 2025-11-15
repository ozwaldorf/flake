{ inputs, ... }:
{
  imports = [ inputs.vicinae.homeManagerModules.default ];
  carburetor.themes.vicinae.enable = true;
  services.vicinae = {
    enable = true;
    autoStart = false;
    settings = {
      theme.name = "carburetor";
      faviconService = "google";
      font.size = 11;
      popToRootOnClose = true;
      rootSearch.searchFiles = false;
      window = {
        csd = true;
        opacity = 0.7;
        rounding = 10;
      };
    };
    extensions = [ ];
  };
}
