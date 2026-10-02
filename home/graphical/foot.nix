{ lib, inputs, ... }:
let
  palette = (lib.importJSON "${inputs.carburetor}/whiskers.json").mocha;
in
{
  carburetor.themes.foot.enable = true;
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "Berkeley Mono:size=9";
        dpi-aware = "yes";
        pad = "14x14 center";
        term = "xterm-256color";
      };
      colors-dark = {
        alpha = "0.8";
      };
      # niri has foot draw its own title bar, a subsurface that foot's own
      # blur request does not cover, so blur is left to the niri window rule.
      # Darker than the window background, still translucent. AARRGGBB.
      csd = {
        color = "cc${palette.crust}";
        button-color = "ff${palette.text}";
      };
      mouse.hide-when-typing = "no";
      cursor = {
        style = "beam";
        blink = "yes";
      };
    };
  };
}
