{ pkgs, ... }:
{
  carburetor.themes.vesktop.enable = true;
  home.packages = [
    (pkgs.vesktop.override {
      withTTS = false;
      withSystemVencord = true;
    })
  ];
}
