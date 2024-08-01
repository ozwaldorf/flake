{ pkgs, ... }:
{
  home.packages = [
    (pkgs.vesktop.override {
      withTTS = false;
      withSystemVencord = true;
    })
  ];

  carburetor.themes.vesktop.enable = true;

  # Install horizontal server list css
  xdg.configFile."vesktop/themes/horizontal.css".source = builtins.fetchurl {
    url = "https://betterdiscord.app/Download\?id=124";
    sha256 = "0c9gmi6axjlk5w1ivdjnx2mz5qr9hc10f55gjmjaxy8lnwc7p9jc";
  };
}
