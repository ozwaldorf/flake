{ ... }:
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
        # foot negotiates its own blur via ext-background-effect-v1
        blur = "yes";
      };
      mouse.hide-when-typing = "no";
      cursor = {
        style = "beam";
        blink = "yes";
      };
    };
  };
}
