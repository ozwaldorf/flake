{
  pkgs,
  config,
  flakeDirectory,
  ...
}:
{
  home.packages = [
    (pkgs.vesktop.override {
      withTTS = false;
      withSystemVencord = true;
    })
  ];

  carburetor.themes.vesktop.enable = true;

  xdg.configFile = {
    # # Install horizontal server list css
    # "vesktop/themes/horizontal.css".source = builtins.fetchurl {
    #   url = "https://betterdiscord.app/Download\?id=124";
    #   sha256 = "0c9gmi6axjlk5w1ivdjnx2mz5qr9hc10f55gjmjaxy8lnwc7p9jc";
    # };

    # Out of store symlink to the configuration, allowing settings changes
    # in the UI to reflect in the code.
    "vesktop/settings/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink flakeDirectory + "/home/graphical/vesktop/settings.json";
  };
}
